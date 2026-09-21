package com.example.kay

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.service.voice.VoiceInteractionSession
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KayVoiceInteractionSession(context: android.content.Context) :
    VoiceInteractionSession(context) {

    companion object {
        private const val TAG = "KAY_ASSISTANT"
        private const val SESSION_TTS_DELAY_MS = 300L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    @Volatile private var currentUtteranceId: String? = null
    private var onUtteranceDone: (() -> Unit)? = null

    private var speechRecognizer: KayCommandRecognizer? = null
    private var silenceReminderGiven = false
    @Volatile private var listening = false
    @Volatile private var sessionActive = false
    private var recognitionTimeout: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "KAY_SESSION_CREATED")
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.let { KayVoiceStyle.apply(it, context) }
            }
            Log.i(TAG, "KAY_SESSION_TTS_READY: $ttsReady")
        }
    }

    @Suppress("DEPRECATION")
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        sessionActive = true
        KayVoiceInteractionService.sessionActive = true
        silenceReminderGiven = false
        Log.i(TAG, "KAY_SESSION_ON_SHOW")
        KayForegroundService.instance?.releaseWakeWordMicrophone()
        mainHandler.postDelayed({
            if (!sessionActive) return@postDelayed
            speakAsync("Estou ouvindo") {
                if (!sessionActive) return@speakAsync
                startRecognition()
            }
        }, SESSION_TTS_DELAY_MS)
    }

    override fun onHide() {
        Log.i(TAG, "KAY_SESSION_ON_HIDE")
        sessionActive = false
        KayVoiceInteractionService.sessionActive = false
        cancelRecognitionTimeout()
        stopRecognition()
        tts?.stop()
        super.onHide()
    }

    override fun finish() {
        Log.i(TAG, "KAY_SESSION_FINISH_REQUESTED")
        sessionActive = false
        KayVoiceInteractionService.sessionActive = false
        cancelRecognitionTimeout()
        stopRecognition()
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.finish()
    }

    override fun onDestroy() {
        Log.i(TAG, "KAY_SESSION_DESTROYED")
        sessionActive = false
        KayVoiceInteractionService.sessionActive = false
        cancelRecognitionTimeout()
        stopRecognition()
        tts?.stop()
        tts?.shutdown()
        tts = null
        KayForegroundService.onSessionFinished?.invoke()
        super.onDestroy()
    }

    // ── Recognition ────────────────────────────────────────────────────

    private fun startRecognition() {
        if (listening || !sessionActive) return
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            Log.w(TAG, "KAY_SESSION_RECOGNITION_UNAVAILABLE")
            speakAsync("Reconhecimento de voz indisponível.") { finish() }
            return
        }

        Log.i(TAG, "KAY_SESSION_RECOGNITION_START")
        listening = true
        mainHandler.post {
            if (!sessionActive) return@post
            speechRecognizer?.destroy()
            speechRecognizer = KayCommandRecognizer(context).apply {
                setRecognitionListener(createListener())
            }
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            }
            speechRecognizer?.startListening(intent)
        }
    }

    private fun stopRecognition() {
        listening = false
        mainHandler.post {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }

    private fun cancelRecognitionTimeout() {
        recognitionTimeout?.let { mainHandler.removeCallbacks(it) }
        recognitionTimeout = null
    }

    private fun createListener() = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            Log.i(TAG, "KAY_SESSION_READY_FOR_SPEECH")
        }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {
            Log.i(TAG, "KAY_SESSION_END_OF_SPEECH")
        }

        override fun onError(error: Int) {
            if (!listening || !sessionActive) return
            listening = false
            cancelRecognitionTimeout()
            if (error == KayCommandRecognizer.INITIAL_SILENCE) {
                if (!silenceReminderGiven) {
                    silenceReminderGiven = true
                    speakAsync("Pode falar. Estou ouvindo.") {
                        if (sessionActive) startRecognition()
                    }
                } else {
                    speakAsync("Vou aguardar você me chamar novamente.") { finish() }
                }
                return
            }
            val msg = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Não ouvi nenhum comando."
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                    "Permissão de microfone necessária."
                else -> "Erro de reconhecimento ($error)."
            }
            Log.w(TAG, "KAY_SESSION_RECOGNITION_ERROR: code=$error msg=$msg")
            speakAsync(msg) { finish() }
        }

        override fun onResults(results: Bundle?) {
            if (!listening || !sessionActive) return
            listening = false
            cancelRecognitionTimeout()
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val text = matches?.firstOrNull()?.lowercase() ?: ""
            Log.i(TAG, "KAY_SESSION_COMMAND_RECEIVED: \"$text\"")
            if (text.isBlank()) {
                speakAsync("Não ouvi nenhum comando.") { finish() }
                return
            }
            executeCommand(text)
        }

        override fun onPartialResults(partialResults: Bundle?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    // ── Command Execution ──────────────────────────────────────────────

    private fun executeCommand(text: String) {
        val command = parseCommand(text)
        if (command == null) {
            Log.w(TAG, "KAY_SESSION_COMMAND_NOT_RECOGNIZED: \"$text\"")
            speakAsync("Não entendi o comando. Tente novamente.") { finish() }
            return
        }

        Log.i(TAG, "KAY_SESSION_COMMAND_EXECUTING: $command")
        when (command) {
            "time" -> {
                val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
                speakAsync("Agora são $timeStr.") { finish() }
            }
            else -> {
                val packageName = when (command) {
                    "youtube" -> "com.google.android.youtube"
                    "spotify" -> "com.spotify.music"
                    "chrome" -> "com.android.chrome"
                    else -> null
                }
                val label = when (command) {
                    "youtube" -> "YouTube"
                    "spotify" -> "Spotify"
                    "chrome" -> "Chrome"
                    "settings" -> "Configurações"
                    else -> command
                }
                speakAsync("Abrindo $label.") {
                    val result = openApp(command, packageName)
                    Log.i(TAG, "KAY_SESSION_APP_LAUNCH: $command → $result")
                    finish()
                }
            }
        }
    }

    private fun parseCommand(text: String): String? {
        var value = text.lowercase()
        val accents = mapOf(
            'á' to 'a', 'à' to 'a', 'ã' to 'a', 'â' to 'a',
            'é' to 'e', 'ê' to 'e', 'í' to 'i',
            'ó' to 'o', 'ô' to 'o', 'õ' to 'o',
            'ú' to 'u', 'ç' to 'c',
        )
        for ((from, to) in accents) value = value.replace(from, to)
        value = value.replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()
        value = value.replaceFirst(Regex("^(kay|kai|kei)\\s+"), "")
        value = value
            .replaceFirst(Regex("^por favor\\s+"), "")
            .replaceFirst(Regex("\\s+por favor$"), "")
            .trim()

        if (Regex(
                "^(que horas sao|que hora e|qual e a hora|qual a hora|" +
                    "me diga as horas|me diz as horas|me diga o horario)$",
            ).containsMatchIn(value)
        ) {
            return "time"
        }

        val match = Regex(
            "^(?:abrir|abre|abra)(?: o| a| as| os)? " +
                "(youtube|you tube|spotify|chrome|google chrome|" +
                "configuracoes|configuracao|ajustes)$",
        ).find(value)
        return when (match?.groupValues?.get(1)) {
            "youtube", "you tube" -> "youtube"
            "spotify" -> "spotify"
            "chrome", "google chrome" -> "chrome"
            "configuracoes", "configuracao", "ajustes" -> "settings"
            else -> null
        }
    }

    private fun openApp(command: String, packageName: String?): String {
        return try {
            val intent = if (command == "settings") {
                Intent(Settings.ACTION_SETTINGS)
            } else {
                context.packageManager.getLaunchIntentForPackage(packageName!!)
            }
            if (intent == null) {
                Log.w(TAG, "KAY_SESSION_INTENT_NULL: $command pkg=$packageName")
                return "unavailable"
            }
            val resolved = context.packageManager.resolveActivity(intent, 0)
            if (resolved == null) {
                Log.w(TAG, "KAY_SESSION_INTENT_UNRESOLVED: $command pkg=$packageName")
                return "unavailable"
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            Log.i(
                TAG,
                "KAY_SESSION_ACTIVITY_STARTED: $command → ${resolved.activityInfo.packageName}/${resolved.activityInfo.name}",
            )
            "opened"
        } catch (e: ActivityNotFoundException) {
            Log.e(TAG, "KAY_SESSION_ACTIVITY_NOT_FOUND: $command", e)
            "unavailable"
        } catch (e: SecurityException) {
            Log.e(TAG, "KAY_SESSION_SECURITY_ERROR: $command", e)
            "denied"
        } catch (e: Exception) {
            Log.e(TAG, "KAY_SESSION_OPEN_APP_ERROR: $command", e)
            "error"
        }
    }

    // ── TTS ────────────────────────────────────────────────────────────

    private fun speakAsync(text: String, onDone: () -> Unit) {
        if (ttsReady) tts?.let { KayVoiceStyle.apply(it, context) }
        if (!ttsReady || tts == null) {
            Log.i(TAG, "KAY_SESSION_TTS_SKIP: ttsReady=$ttsReady")
            onDone()
            return
        }
        mainHandler.post {
            if (!sessionActive) return@post
            val uttId = "kay_session_${System.currentTimeMillis()}"
            currentUtteranceId = uttId
            onUtteranceDone = onDone
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(u: String?) {}
                override fun onDone(u: String?) {
                    if (u == currentUtteranceId && sessionActive) {
                        mainHandler.post { onUtteranceDone?.invoke() }
                    }
                }
                override fun onError(u: String?) {
                    if (u == currentUtteranceId && sessionActive) {
                        mainHandler.post { onUtteranceDone?.invoke() }
                    }
                }
            })
            val bundle = Bundle()
            bundle.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, bundle, uttId)
        }
    }
}
