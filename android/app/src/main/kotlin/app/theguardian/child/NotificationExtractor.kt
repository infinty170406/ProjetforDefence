package app.theguardian.child

import android.app.Notification
import android.app.Person
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.service.notification.StatusBarNotification
import java.util.Locale

data class ExtractedNotification(
    val id: Int,
    val packageName: String,
    val applicationName: String,
    val sender: String,
    val conversationTitle: String,
    val messageText: String,
    val timestamp: Long,
    val androidCategory: String,
    val importance: Int,
    val subText: String,
    val isIgnored: Boolean
)

object NotificationExtractor {

    private val SYSTEM_PACKAGES = setOf(
        "android",
        "com.android.systemui",
        "com.android.providers.downloads",
        "com.google.android.gms",
        "com.android.vending",
        "com.google.android.apps.docs",
        "com.google.android.googlequicksearchbox",
        "com.sec.android.app.samsungapps"
    )

    private val IGNORE_CATEGORIES = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        setOf(
            Notification.CATEGORY_SYSTEM,
            Notification.CATEGORY_SERVICE,
            Notification.CATEGORY_TRANSPORT,
            Notification.CATEGORY_PROGRESS,
            Notification.CATEGORY_STATUS
        )
    } else {
        emptySet()
    }

    private val IGNORE_KEYWORDS = setOf(
        "téléchargement", "télécharger", "downloading", "download",
        "batterie", "battery", "charge", "mise à jour", "updating", "update",
        "météo", "weather", "calendrier", "calendar", "agenda"
    )

    fun extract(context: Context, sbn: StatusBarNotification, importance: Int): ExtractedNotification {
        val notification = sbn.notification
        val extras = notification.extras ?: Bundle()
        val packageName = sbn.packageName

        // Nom convivial de l'application
        val pm = context.packageManager
        val appName = try {
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (e: Exception) {
            packageName
        }

        // Extraction des textes de base
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""

        // Recherche du titre de la conversation et de l'expéditeur (MessagingStyle)
        var conversationTitle = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString() ?: ""
        var sender = title // Par défaut, le titre est souvent l'expéditeur

        // Reconstruction du message complet (notamment pour les messages longs ou groupés)
        val fullMessageBuilder = StringBuilder()
        if (text.isNotEmpty()) {
            fullMessageBuilder.append(text)
        } else if (bigText.isNotEmpty()) {
            fullMessageBuilder.append(bigText)
        }

        // Extraction spécifique pour le style de messagerie Android 7.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                fullMessageBuilder.setLength(0) // On remplace par le flux de messages
                for (msgParcel in messages) {
                    if (msgParcel is Bundle) {
                        val msgText = msgParcel.getCharSequence("text")?.toString() ?: ""
                        val msgSenderBundle = msgParcel.get("sender")
                        var msgSender = ""
                        if (msgSenderBundle != null) {
                            msgSender = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && msgSenderBundle is Person) {
                                msgSenderBundle.name?.toString() ?: ""
                            } else {
                                msgSenderBundle.toString()
                            }
                        }
                        
                        if (msgText.isNotEmpty()) {
                            if (msgSender.isNotEmpty()) {
                                fullMessageBuilder.append("$msgSender : ")
                            }
                            fullMessageBuilder.append(msgText).append("\n")
                            // Le dernier expéditeur est considéré comme le principal
                            if (msgSender.isNotEmpty()) {
                                sender = msgSender
                            }
                        }
                    }
                }
            }
        }

        val finalMessage = fullMessageBuilder.toString().trim()
        val category = notification.category ?: ""

        // Détection d'exclusion (système, batterie, téléchargement...)
        val isIgnored = checkIgnored(packageName, category, title, finalMessage, subText)

        return ExtractedNotification(
            id = sbn.id,
            packageName = packageName,
            applicationName = appName,
            sender = if (sender.isBlank()) "Inconnu" else sender,
            conversationTitle = conversationTitle,
            messageText = finalMessage,
            timestamp = sbn.postTime,
            androidCategory = category,
            importance = importance,
            subText = subText,
            isIgnored = isIgnored
        )
    }

    private fun checkIgnored(
        pkg: String,
        category: String,
        title: String,
        message: String,
        subText: String
    ): Boolean {
        // 1. Filtrer les packages système connus
        if (SYSTEM_PACKAGES.contains(pkg) || pkg.startsWith("com.android.") || pkg.startsWith("com.google.android.system")) {
            return true
        }

        // 2. Filtrer par catégories système Android
        if (category.isNotEmpty() && IGNORE_CATEGORIES.contains(category)) {
            return true
        }

        // 3. Filtrer par mots-clés système (Météo, batterie, etc.)
        val lowerTitle = title.lowercase(Locale.getDefault())
        val lowerMsg = message.lowercase(Locale.getDefault())
        val lowerSub = subText.lowercase(Locale.getDefault())

        for (keyword in IGNORE_KEYWORDS) {
            if (lowerTitle.contains(keyword) || lowerMsg.contains(keyword) || lowerSub.contains(keyword)) {
                return true
            }
        }

        // 4. Si le message est totalement vide, on ignore
        if (message.isEmpty() && title.isEmpty()) {
            return true
        }

        return false
    }
}
