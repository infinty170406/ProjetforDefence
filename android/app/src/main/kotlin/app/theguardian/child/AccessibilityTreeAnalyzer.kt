package app.theguardian.child

import android.view.accessibility.AccessibilityNodeInfo

/**
 * Analyse l'arbre des nœuds d'accessibilité de manière récursive.
 * Extrait les champs d'édition (EditText), les vues de recherche (SearchView),
 * les textes (TextView), les WebViews, les boutons et les en-têtes/titres
 * à l'aide d'heuristiques sémantiques.
 * Ne dépend jamais uniquement des IDs de vue.
 */
class AccessibilityTreeAnalyzer {
    
    companion object {
        private const val MAX_NODE_LIMIT = 500

        class ScanResult(
            val url: String? = null,
            val searchQuery: String? = null,
            val pageTitle: String? = null,
            val headers: List<String> = emptyList(),
            val importantContent: List<String> = emptyList(),
            val buttons: List<String> = emptyList(),
            val editTexts: List<String> = emptyList(),
            val searchViews: List<String> = emptyList(),
            val textViews: List<String> = emptyList(),
            val webViews: List<String> = emptyList(),
            val titles: List<String> = emptyList(),
            val isBlockedEarly: Boolean = false,
            val blockedItem: String? = null
        )

        /**
         * Parcourt l'arbre à partir de la racine pour extraire le contenu et catégoriser les nœuds.
         */
        fun analyze(
            root: AccessibilityNodeInfo?,
            blockedWebsites: Set<String> = emptySet(),
            customKeywords: Set<String> = emptySet(),
            blockedCategories: Set<String> = emptySet()
        ): ScanResult {
            if (root == null) return ScanResult()
            
            var detectedUrl: String? = null
            var detectedSearchQuery: String? = null
            var detectedPageTitle: String? = null
            
            val headers = mutableListOf<String>()
            val contents = mutableListOf<String>()
            val buttons = mutableListOf<String>()
            val editTexts = mutableListOf<String>()
            val searchViews = mutableListOf<String>()
            val textViews = mutableListOf<String>()
            val webViews = mutableListOf<String>()
            val titles = mutableListOf<String>()
            
            var nodeCount = 0
            var isBlockedEarly = false
            var blockedItem: String? = null
 
            fun traverse(node: AccessibilityNodeInfo?, depth: Int) {
                if (node == null || isBlockedEarly || nodeCount > MAX_NODE_LIMIT || depth > 30) return
                nodeCount++
 
                try {
                    val className = node.className?.toString() ?: ""
                    val text = node.text?.toString()?.trim() ?: ""
                    val contentDesc = node.contentDescription?.toString()?.trim() ?: ""
                    val viewId = node.viewIdResourceName?.toString() ?: ""
                    val hint = node.hintText?.toString() ?: ""
                    val tooltip = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        node.tooltipText?.toString() ?: ""
                    } else ""
                    val stateDesc = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        node.stateDescription?.toString() ?: ""
                    } else ""
                    val paneTitle = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        node.paneTitle?.toString() ?: ""
                    } else ""
                    
                    // Check all attributes for blocked keywords
                    val allTextProps = listOf(text, contentDesc, hint, tooltip, stateDesc, paneTitle)
                    for (prop in allTextProps) {
                        if (prop.isBlank() || prop.equals("null", ignoreCase = true) || prop.equals("undefined", ignoreCase = true)) continue
                        
                        // Check custom keywords
                        val check = BlockedKeywordEngine.evaluate(prop, customKeywords, emptySet(), blockedCategories)
                        if (check.isBlocked) {
                            isBlockedEarly = true
                            blockedItem = check.matchedKeyword
                            return
                        }

                        // Check blocked websites
                        if (looksLikeUrl(prop)) {
                            for (blocked in blockedWebsites) {
                                if (prop.contains(blocked, ignoreCase = true)) {
                                    isBlockedEarly = true
                                    blockedItem = prop
                                    return
                                }
                            }
                        }
                    }

                    // 1. Détection de l'URL par heuristique
                    if (node.isEditable && text.isNotEmpty() && looksLikeUrl(text)) {
                        detectedUrl = text
                    }

                    // 2. Identification des EditText
                    if (node.isEditable || className.contains("EditText", ignoreCase = true)) {
                        if (text.isNotEmpty()) editTexts.add(text)
                    }

                    // 3. Identification des SearchView
                    val isSearchField = className.contains("SearchView", ignoreCase = true) ||
                        viewId.contains("search", ignoreCase = true) || 
                        viewId.contains("query", ignoreCase = true) || 
                        contentDesc.contains("search", ignoreCase = true) || 
                        hint.contains("search", ignoreCase = true)

                    if (isSearchField) {
                        if (text.isNotEmpty()) {
                            searchViews.add(text)
                            if (node.isEditable && !looksLikeUrl(text)) {
                                detectedSearchQuery = text
                            }
                        }
                    }

                    // 4. Identification des TextView
                    if (className.contains("TextView", ignoreCase = true) && text.isNotEmpty()) {
                        textViews.add(text)
                    }

                    // 5. Identification des WebViews
                    if (className.contains("WebView", ignoreCase = true)) {
                        if (text.isNotEmpty()) webViews.add(text)
                        else if (contentDesc.isNotEmpty()) webViews.add(contentDesc)
                    }

                    // 6. Détection de boutons
                    val isButton = node.isClickable && (
                        className.contains("Button", ignoreCase = true) || 
                        viewId.contains("btn", ignoreCase = true) || 
                        viewId.contains("button", ignoreCase = true)
                    )
                    if (isButton) {
                        if (text.isNotEmpty()) {
                            buttons.add(text)
                        } else if (contentDesc.isNotEmpty()) {
                            buttons.add(contentDesc)
                        }
                    }

                    // 7. Détection de en-têtes, titres et TextView importants
                    val isHeadingNode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        node.isHeading
                    } else false
                    
                    val isHeader = isHeadingNode || 
                        className.contains("Heading", ignoreCase = true) || 
                        viewId.contains("title", ignoreCase = true) || 
                        viewId.contains("header", ignoreCase = true)

                    if (isHeader && text.isNotEmpty()) {
                        headers.add(text)
                        titles.add(text)
                        if (detectedPageTitle == null) {
                            detectedPageTitle = text
                        }
                    } else if (text.isNotEmpty() && text.length > 2 && text.length < 150) {
                        if (text.length > 15 && contents.size < 8) {
                            contents.add(text)
                        }
                    }

                } catch (e: Exception) {
                    // Ignorer les erreurs d'analyse des nœuds individuels
                }

                // Parcourir les enfants
                for (i in 0 until node.childCount) {
                    val child = node.getChild(i)
                    if (child != null) {
                        traverse(child, depth + 1)
                        child.recycle()
                    }
                }
            }

            traverse(root, 0)

            return ScanResult(
                url = detectedUrl,
                searchQuery = detectedSearchQuery ?: (if (searchViews.isNotEmpty()) searchViews.first() else null),
                pageTitle = detectedPageTitle,
                headers = headers,
                importantContent = contents,
                buttons = buttons,
                editTexts = editTexts,
                searchViews = searchViews,
                textViews = textViews,
                webViews = webViews,
                titles = titles,
                isBlockedEarly = isBlockedEarly,
                blockedItem = blockedItem
            )
        }

        /**
         * Extrait le titre de la page depuis le changement de fenêtre d'accessibilité.
         */
        fun extractPageTitleFromEvent(event: android.view.accessibility.AccessibilityEvent): String? {
            if (event.eventType == android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val texts = event.text
                if (!texts.isNullOrEmpty()) {
                    val title = texts[0]?.toString()?.trim()
                    if (!title.isNullOrBlank() && title != "Chrome" && title != "Firefox" && title != "Edge" && title != "Brave") {
                        return title
                    }
                }
            }
            return null
        }

        private fun looksLikeUrl(text: String): Boolean {
            if (text.startsWith("http://") || text.startsWith("https://")) return true
            if (text.contains(".") && !text.contains(" ") && text.length > 3) {
                val lastDot = text.lastIndexOf('.')
                if (lastDot > 0 && lastDot < text.length - 1) {
                    val tld = text.substring(lastDot + 1)
                    if (tld.length in 2..6 && tld.all { it.isLetter() }) {
                        return true
                    }
                }
            }
            return false
        }
    }
}
