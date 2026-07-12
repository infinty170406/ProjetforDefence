package app.theguardian.child

import android.view.accessibility.AccessibilityEvent

/**
 * Responsable de filtrer et de catégoriser les événements d'accessibilité.
 * Détermine si un événement est utile à analyser et de quel type d'activité il s'agit.
 */
class AccessibilityEventParser {
    
    enum class EventType {
        BYPASS_ATTEMPT,
        APP_LAUNCH,
        WEB_NAVIGATION,
        IGNORED
    }

    companion object {
        private const val OWN_PACKAGE = "app.theguardian.child"

        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.sec.android.app.sbrowser",
            "org.mozilla.firefox",
            "com.opera.browser",
            "com.microsoft.emmx",
            "com.brave.browser",
            "com.duckduckgo.mobile.android",
            "com.miui.browser"
        )

        private val INTEREST_PACKAGES = BROWSER_PACKAGES + setOf(
            "com.google.android.googlequicksearchbox",
            "com.google.android.youtube",
            "com.google.android.apps.youtube.kids"
        )

        /**
         * Analyse un événement d'accessibilité et retourne sa classification.
         */
        fun parseEvent(event: AccessibilityEvent?): EventType {
            if (event == null) return EventType.IGNORED
            val pkg = event.packageName?.toString() ?: return EventType.IGNORED

            // Ignorer l'application elle-même et l'interface système
            if (pkg == OWN_PACKAGE || pkg == "com.android.systemui") {
                return EventType.IGNORED
            }

            // Détecter les tentatives de contournement dans les paramètres (désactivé pour les tests)
            // if (pkg == "com.android.settings") {
            //     return EventType.BYPASS_ATTEMPT
            // }

            // Changements d'application (fenêtres)
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                if (INTEREST_PACKAGES.contains(pkg)) {
                    return EventType.WEB_NAVIGATION
                }
                return EventType.APP_LAUNCH
            }

            // Contenus et scrolls dans les navigateurs ou applications d'intérêt
            if (INTEREST_PACKAGES.contains(pkg)) {
                val et = event.eventType
                if (et == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
                    et == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
                    et == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
                    return EventType.WEB_NAVIGATION
                }
            }

            return EventType.IGNORED
        }
    }
}
