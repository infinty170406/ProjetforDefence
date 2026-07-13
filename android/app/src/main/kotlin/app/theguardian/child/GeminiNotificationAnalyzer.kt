package app.theguardian.child

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

data class GeminiAnalysisResult(
    val risk: String,        // "SAFE", "LOW", "MEDIUM", "HIGH", "CRITICAL"
    val score: Int,          // 0-100
    val category: String,    // "GROOMING", "VIOLENCE", "DROGUE", etc.
    val blocked: Boolean,
    val confidence: Double,
    val reason: String
)

object GeminiNotificationAnalyzer {

    private const val TAG = "GeminiAnalyzer"
    private const val GEMINI_MODEL = "gemini-1.5-flash"

    /**
     * Analyse le contenu d'une notification via l'API Gemini.
     */
    suspend fun analyze(context: Context, extracted: ExtractedNotification): GeminiAnalysisResult = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val apiKey = prefs.getString("gemini_api_key", null)
            ?: prefs.getString("flutter.gemini_api_key", null)

        if (apiKey.isNullOrBlank()) {
            Log.w(TAG, "Gemini API key is not configured. Defaulting to SAFE.")
            return@withContext GeminiAnalysisResult(
                risk = "SAFE",
                score = 0,
                category = "NONE",
                blocked = false,
                confidence = 1.0,
                reason = "Clé API Gemini non configurée dans SharedPreferences."
            )
        }

        try {
            val systemPrompt = """
                Tu es un expert en protection de l'enfance et en sécurité numérique.
                Analyse la notification suivante reçue sur le téléphone d'un enfant :
                
                Application : ${extracted.applicationName}
                Expéditeur : ${extracted.sender}
                Conversation : ${extracted.conversationTitle}
                Message : ${extracted.messageText}
                
                Identifie les menaces potentielles parmi : cyberharcèlement, grooming (prédateurs sexuels), chantage/extorsion, violence, drogues, escroquerie, suicide, automutilation, contenu sexuel, menace physique, radicalisation, harcèlement scolaire, ou manipulation psychologique.
                
                Tu DOIS impérativement retourner un objet JSON respectant exactement cette structure :
                {
                  "risk": "SAFE" | "LOW" | "MEDIUM" | "HIGH" | "CRITICAL",
                  "score": <un entier entre 0 et 100 indiquant le niveau de danger>,
                  "category": "GROOMING" | "VIOLENCE" | "DROGUE" | "CYBERHARCELEMENT" | "SUICIDE" | "AUTOMUTILATION" | "CONTENU_SEXUEL" | "MENACE" | "ESCROQUERIE" | "RADICALISATION" | "HARCELEMENT_SCOLAIRE" | "MANIPULATION" | "NONE",
                  "blocked": true | false,
                  "confidence": <un nombre décimal entre 0.0 et 1.0>,
                  "reason": "<une explication claire et concise en français résumant pourquoi cette décision a été prise>"
                }
                
                Ne génère aucun texte avant ou après le JSON. Renvoie uniquement le JSON brut.
            """.trimIndent()

            // Construction du payload HTTP
            val payload = JSONObject().apply {
                put("contents", org.json.JSONArray().apply {
                    put(JSONObject().apply {
                        put("parts", org.json.JSONArray().apply {
                            put(JSONObject().apply {
                                put("text", systemPrompt)
                            })
                        })
                    })
                })
                put("generationConfig", JSONObject().apply {
                    put("responseMimeType", "application/json")
                })
            }

            val urlString = "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$apiKey"
            val url = URL(urlString)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.doOutput = true
            conn.connectTimeout = 8000
            conn.readTimeout = 8000

            OutputStreamWriter(conn.outputStream, StandardCharsets.UTF_8).use { writer ->
                writer.write(payload.toString())
                writer.flush()
            }

            val responseCode = conn.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val responseText = conn.inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
                val responseJson = JSONObject(responseText)
                
                // Extraction du texte de la réponse Gemini
                val candidates = responseJson.optJSONArray("candidates")
                if (candidates != null && candidates.length() > 0) {
                    val candidate = candidates.getJSONObject(0)
                    val content = candidate.optJSONObject("content")
                    val parts = content?.optJSONArray("parts")
                    if (parts != null && parts.length() > 0) {
                        val text = parts.getJSONObject(0).optString("text")
                        
                        // Parse le JSON interne retourné par Gemini
                        val innerJson = JSONObject(text.trim())
                        return@withContext GeminiAnalysisResult(
                            risk = innerJson.optString("risk", "SAFE").uppercase(),
                            score = innerJson.optInt("score", 0),
                            category = innerJson.optString("category", "NONE").uppercase(),
                            blocked = innerJson.optBoolean("blocked", false),
                            confidence = innerJson.optDouble("confidence", 0.0),
                            reason = innerJson.optString("reason", "Aucune explication fournie par l'IA.")
                        )
                    }
                }
                throw Exception("Invalid format or empty candidates in Gemini response")
            } else {
                val errorText = conn.errorStream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() } ?: ""
                Log.e(TAG, "Gemini API error code: $responseCode, details: $errorText")
                throw Exception("HTTP error code $responseCode from Gemini API")
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to analyze notification with Gemini: ${e.message}")
            // Fallback SAFE en cas d'erreur réseau pour ne pas bloquer les notifications
            return@withContext GeminiAnalysisResult(
                risk = "SAFE",
                score = 0,
                category = "NONE",
                blocked = false,
                confidence = 0.0,
                reason = "Erreur de connexion à Gemini : ${e.message}"
            )
        }
    }
}
