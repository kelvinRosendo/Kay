package com.example.kay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class KayForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "kay_active"
        const val NOTIFICATION_ID = 7001
        const val ACTION_START = "com.example.kay.START"
        const val ACTION_STOP = "com.example.kay.STOP"
        const val ACTION_SET_FOREGROUND = "com.example.kay.SET_FOREGROUND"

        var onStateUpdate: ((String) -> Unit)? = null
        var onWakeDetected: (() -> Unit)? = null
        var isFlutterInForeground = false

        @Volatile
        var instance: KayForegroundService? = null
            private set

        @Volatile
        var running = false
            private set

        @Volatile
        var voskReady = false
            private set

        var onSessionFinished: (() -> Unit)? = null
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val generation = AtomicInteger()

    @Volatile private var isActive = false
    @Volatile private var isRecording = false
    private var wakeModel: Model? = null
    private var wakeRecognizer: Recognizer? = null
    private var wakeRecorder: AudioRecord? = null
    private var wakeThread: Thread? = null

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    @Volatile private var currentUtteranceId: String? = null
    private var onUtteranceDone: (() -> Unit)? = null

    private var speechRecognizer: KayCommandRecognizer? = null
    private var silenceReminderGiven = false
    @Volatile private var commandListening = false
    @Volatile private var shortWindow = false

    override fun onCreate() {
        super.onCreate()
        instance = this
        onSessionFinished = {
            mainHandler.post {
                if (instance != null && isActive) {
                    updateNotification("Kay ativo — aguardando a palavra Kay")
                    notifyState("idle")
                    startWakeWordDetection()
                }
            }
        }
        createNotificationChannel()
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.let { KayVoiceStyle.apply(it, this) }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                if (!isActive) {
                    isActive = true
                    running = true
                    startForeground(
                        NOTIFICATION_ID,
                        buildNotification("Kay ativo — aguardando a palavra Kay"),
                    )
                    startWakeWordDetection()
                } else {
                    startWakeWordDetection()
                }
            }
            ACTION_STOP -> {
                isActive = false
                running = false
                stopCommandRecognition()
                stopWakeWordDetection()
                tts?.stop()
                tts?.shutdown()
                tts = null
                @Suppress("DEPRECATION")
                stopForeground(true)
                stopSelf()
            }
            ACTION_SET_FOREGROUND -> {
                isFlutterInForeground = intent.getBooleanExtra("foreground", false)
            }
            null -> {
                if (isActive) {
                    startForeground(
                        NOTIFICATION_ID,
                        buildNotification("Kay ativo — aguardando a palavra Kay"),
                    )
                    startWakeWordDetection()
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        instance = null
        running = false
        onSessionFinished = null
        isActive = false
        stopCommandRecognition()
        stopWakeWordDetection()
        tts?.stop()
        tts?.shutdown()
        tts = null
        executor.shutdownNow()
        super.onDestroy()
    }

    // ── Wait configuration ───────────────────────────────────────────

    /// Applies the Flutter-side timing to the recognizer and cancels any
    /// stale timers when an active recognition window exists.
    fun setWaitConfig(waitMs: Long, silenceMs: Long) {
        KayCommandRecognizer.initialWaitMs = waitMs.coerceAtLeast(10_000)
        KayCommandRecognizer.postWarningMs = silenceMs.coerceAtLeast(3_000)
        mainHandler.post {
            if (commandListening) {
                speechRecognizer?.destroy()
                speechRecognizer = null
                if (isActive) startCommandRecognition()
            }
        }
    }

    // ── Public API ─────────────────────────────────────────────────────

    fun releaseWakeWordMicrophone() {
        Log.i("KAY_ASSISTANT", "KAY_SERVICE_RELEASING_MICROPHONE_FOR_SESSION")
        stopWakeWordDetection()
    }

    // ── Notification ───────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Kay ativo",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Mantém o Kay ativo em segundo plano" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Kay")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun notifyState(state: String) {
        mainHandler.post { onStateUpdate?.invoke(state) }
    }

    // ── Wake Word Detection (Vosk) ─────────────────────────────────────

    private fun startWakeWordDetection() {
        val token = generation.incrementAndGet()
        executor.execute {
            try {
                releaseMicrophone()
                if (!isActive || token != generation.get()) return@execute

                if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    mainHandler.post {
                        updateNotification("Erro: permissão de microfone necessária")
                    }
                    return@execute
                }

                if (wakeModel == null) {
                    wakeModel = Model(prepareModel().absolutePath)
                }
                if (token != generation.get() || !isActive) return@execute

                val decoder = Recognizer(
                    wakeModel, 16_000f,
                    """["kay", "kai", "k", "hey kay", "hey kai", "okay", "ok", "[unk]"]""",
                )
                wakeRecognizer = decoder

                val bufSize = maxOf(
                    6400,
                    AudioRecord.getMinBufferSize(
                        16_000,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                    ),
                )
                val audio = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    16_000,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufSize,
                )
                wakeRecorder = audio

                if (audio.state != AudioRecord.STATE_INITIALIZED) {
                    audio.release()
                    return@execute
                }
                audio.startRecording()
                if (audio.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                    audio.release()
                    return@execute
                }
                isRecording = true
                voskReady = true

                val detected = AtomicBoolean(false)
                wakeThread = Thread {
                    try {
                        val buffer = ShortArray(1600)
                        var previous = ""
                        var stable = 0
                        while (isRecording && token == generation.get() && isActive) {
                            val count = audio.read(buffer, 0, buffer.size)
                            if (count < 0) break
                            if (count == 0) continue
                            val isFinal = decoder.acceptWaveForm(buffer, count)
                            val json = JSONObject(
                                if (isFinal) decoder.result else decoder.partialResult,
                            )
                            val text = json
                                .optString(if (isFinal) "text" else "partial")
                                .trim().lowercase()
                            stable = if (text == previous) stable + 1 else 1
                            previous = text
                            if (text in setOf("kay", "kai", "k", "hey kay", "hey kai")
                                && (isFinal || stable >= 3)
                            ) {
                                if (detected.compareAndSet(false, true)) {
                                    mainHandler.post {
                                        if (token == generation.get() && isActive) {
                                            onWakeWordDetected()
                                        }
                                    }
                                }
                                break
                            }
                        }
                    } catch (_: Exception) {
                    }
                }.also { it.name = "kay-wake-audio"; it.start() }
            } catch (_: Exception) {
                releaseMicrophone()
            }
        }
    }

    private fun stopWakeWordDetection() {
        generation.incrementAndGet()
        voskReady = false
        executor.execute { releaseMicrophone() }
    }

    private fun releaseMicrophone() {
        isRecording = false
        try { wakeRecorder?.stop() } catch (_: IllegalStateException) {}
        try { wakeThread?.join(1000) } catch (_: InterruptedException) {}
        wakeThread = null
        wakeRecorder?.release()
        wakeRecorder = null
        wakeRecognizer?.close()
        wakeRecognizer = null
    }

    // ── Wake Word Detected ─────────────────────────────────────────────

    private fun onWakeWordDetected() {
        if (!isActive) return
        silenceReminderGiven = false
        shortWindow = false

        stopWakeWordDetection()
        Log.i("KAY_ASSISTANT", "KAY_SERVICE_WAKE_DETECTED")

        // Prefer VoiceInteractionService session when available
        if (KayVoiceInteractionService.isAvailable()) {
            Log.i("KAY_ASSISTANT", "KAY_SERVICE_USING_VIS_SESSION")
            val args = Bundle().apply {
                putString("trigger", "wake_word")
            }
            KayVoiceInteractionService.instance?.showSession(args, 0)
            return
        }

        // Fallback: foreground service handles everything
        if (isFlutterInForeground) {
            mainHandler.post { onWakeDetected?.invoke() }
            return
        }

        mainHandler.post {
            updateNotification("Kay detectado — ouvindo comando")
            notifyState("listening")
            speakAsync("Estou ouvindo") {
                if (!isActive) return@speakAsync
                startCommandRecognition()
            }
        }
    }

    // ── Command Recognition (SpeechRecognizer) ─────────────────────────

    private fun startCommandRecognition() {
        if (!isActive) return

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            mainHandler.post { updateNotification("Reconhecimento de voz indisponível") }
            restartWakeWordDetection()
            return
        }

        commandListening = true
        mainHandler.post {
            speechRecognizer?.destroy()
            KayCommandRecognizer.windowMs =
                if (shortWindow) KayCommandRecognizer.postWarningMs
                else KayCommandRecognizer.initialWaitMs
            speechRecognizer = KayCommandRecognizer(this).apply {
                setRecognitionListener(createCommandListener())
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

    private fun stopCommandRecognition() {
        commandListening = false
        mainHandler.post {
            speechRecognizer?.stopListening()
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }

    private fun createCommandListener() = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}

        override fun onError(error: Int) {
            if (!isActive || !commandListening) return
            commandListening = false
            if (error == KayCommandRecognizer.INITIAL_SILENCE) {
                if (!silenceReminderGiven) {
                    silenceReminderGiven = true
                    shortWindow = true
                    speakAsync("Pode falar. Estou ouvindo.") {
                        if (isActive) startCommandRecognition()
                    }
                } else {
                    speakAsync("Vou aguardar você me chamar novamente.") { restartWakeWordDetection() }
                }
                return
            }
            val msg = when (error) {
                SpeechRecognizer.ERROR_NO_MATCH,
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Não ouvi nenhum comando"
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                    "Permissão de microfone necessária"
                SpeechRecognizer.ERROR_AUDIO -> "Erro de áudio"
                SpeechRecognizer.ERROR_NETWORK,
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Erro de rede"
                else -> "Erro de reconhecimento"
            }
            mainHandler.post { updateNotification("Erro: $msg") }
            restartWakeWordDetection()
        }

        override fun onResults(results: Bundle?) {
            if (!isActive || !commandListening) return
            commandListening = false
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            val text = matches?.firstOrNull()?.lowercase() ?: ""
            if (text.isBlank()) {
                mainHandler.post { updateNotification("Não ouvi nenhum comando") }
                restartWakeWordDetection()
                return
            }
            executeCommand(text)
        }

        override fun onPartialResults(partialResults: Bundle?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    // ── Command Execution (fallback when VIS not available) ────────────

    private fun executeCommand(text: String) {
        val command = parseCommand(text)
        if (command == null) {
            mainHandler.post { updateNotification("Comando não reconhecido: $text") }
            speakAsync("Não entendi o comando. Tente novamente.") {
                restartWakeWordDetection()
            }
            return
        }

        when (command) {
            "time" -> {
                val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
                mainHandler.post {
                    updateNotification("Horário: $timeStr")
                    notifyState("speaking")
                }
                speakAsync("Agora são $timeStr") {
                    restartWakeWordDetection()
                }
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
                mainHandler.post {
                    updateNotification("Abrindo $label")
                    notifyState("speaking")
                }
                speakAsync("Abrindo $label") {
                    val result = openApp(command, packageName)
                    mainHandler.post {
                        when (result) {
                            "opened" -> updateNotification("Kay ativo — aguardando a palavra Kay")
                            "unavailable" -> updateNotification("$label não encontrado")
                            "denied" -> updateNotification("Permissão negada para $label")
                            else -> updateNotification("Erro ao abrir $label")
                        }
                    }
                    restartWakeWordDetection()
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
                packageManager.getLaunchIntentForPackage(packageName!!)
            }
            if (intent == null) {
                Log.w("KAY_ASSISTANT", "KAY_SERVICE_INTENT_NULL: $command pkg=$packageName")
                return "unavailable"
            }
            val resolved = packageManager.resolveActivity(intent, 0)
            if (resolved == null) {
                Log.w("KAY_ASSISTANT", "KAY_SERVICE_INTENT_UNRESOLVED: $command pkg=$packageName")
                return "unavailable"
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            Log.i(
                "KAY_ASSISTANT",
                "KAY_SERVICE_ACTIVITY_STARTED: $command → ${resolved.activityInfo.packageName}",
            )
            "opened"
        } catch (e: ActivityNotFoundException) {
            Log.e("KAY_ASSISTANT", "KAY_SERVICE_ACTIVITY_NOT_FOUND: $command", e)
            "unavailable"
        } catch (e: SecurityException) {
            Log.e("KAY_ASSISTANT", "KAY_SERVICE_SECURITY_ERROR: $command", e)
            "denied"
        } catch (e: Exception) {
            Log.e("KAY_ASSISTANT", "KAY_SERVICE_OPEN_APP_ERROR: $command", e)
            "error"
        }
    }

    // ── TTS ────────────────────────────────────────────────────────────

    private fun speakAsync(text: String, onDone: () -> Unit) {
        if (ttsReady) tts?.let { KayVoiceStyle.apply(it, this) }
        if (!ttsReady || tts == null) {
            onDone()
            return
        }
        mainHandler.post {
            val uttId = "kay_${System.currentTimeMillis()}"
            currentUtteranceId = uttId
            onUtteranceDone = onDone
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(u: String?) {}
                override fun onDone(u: String?) {
                    if (u == currentUtteranceId) {
                        mainHandler.post { onUtteranceDone?.invoke() }
                    }
                }
                override fun onError(u: String?) {
                    if (u == currentUtteranceId) {
                        mainHandler.post { onUtteranceDone?.invoke() }
                    }
                }
            })
            val bundle = Bundle()
            bundle.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, uttId)
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, bundle, uttId)
        }
    }

    // ── Restart ────────────────────────────────────────────────────────

    private fun restartWakeWordDetection() {
        if (!isActive) return
        silenceReminderGiven = false
        shortWindow = false
        mainHandler.post {
            updateNotification("Kay ativo — aguardando a palavra Kay")
            notifyState("idle")
        }
        startWakeWordDetection()
    }

    // ── Model ──────────────────────────────────────────────────────────

    private fun prepareModel(): File {
        val name = "vosk-model-small-en-us-0.15"
        val directory = File(filesDir, name)
        val marker = File(directory, ".complete-v1")
        if (!marker.exists()) {
            copyAsset(name, directory)
            marker.writeText(
                "30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498",
            )
        }
        return directory
    }

    private fun copyAsset(path: String, destination: File) {
        val children = assets.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            assets.open(path).use { input ->
                destination.outputStream().use { input.copyTo(it) }
            }
        } else {
            destination.exists() || destination.mkdirs()
            children.forEach { copyAsset("$path/$it", File(destination, it)) }
        }
    }
}
