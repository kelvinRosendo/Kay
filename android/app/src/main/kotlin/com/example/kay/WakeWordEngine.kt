package com.example.kay

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer

class WakeWordEngine(
    private val context: Context,
    private val onDetected: () -> Unit,
    private val onError: () -> Unit,
) {
    private val executor = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger()
    @Volatile private var running = false
    @Volatile private var recording = false
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var recorder: AudioRecord? = null
    private var thread: Thread? = null

    fun start() {
        val token = generation.incrementAndGet()
        executor.execute {
            try {
                releaseMicrophone()
                if (!running) return@execute
                if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    onError()
                    return@execute
                }
                if (model == null) model = Model(prepareModel().absolutePath)
                if (token != generation.get() || !running) return@execute

                val decoder = Recognizer(
                    model, 16_000f,
                    """["kay", "kai", "k", "hey kay", "hey kai", "okay", "ok", "[unk]"]""",
                )
                recognizer = decoder
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
                recorder = audio
                check(audio.state == AudioRecord.STATE_INITIALIZED) { "Microfone indisponível" }
                audio.startRecording()
                check(audio.recordingState == AudioRecord.RECORDSTATE_RECORDING)
                recording = true

                val detected = AtomicBoolean(false)
                thread = Thread {
                    try {
                        val buffer = ShortArray(1600)
                        var previous = ""
                        var stable = 0
                        while (recording && token == generation.get() && running) {
                            val count = audio.read(buffer, 0, buffer.size)
                            if (count < 0) error("Falha na captura de áudio")
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
                                    if (token == generation.get() && running) onDetected()
                                }
                                break
                            }
                        }
                    } catch (_: Exception) {
                        if (running && token == generation.get()) onError()
                    }
                }.also { it.name = "kay-wake-audio-callback"; it.start() }
            } catch (_: Exception) {
                releaseMicrophone()
                if (running) onError()
            }
        }
    }

    fun stop() {
        generation.incrementAndGet()
        executor.execute { releaseMicrophone() }
    }

    fun dispose() {
        running = false
        generation.incrementAndGet()
        executor.execute {
            releaseMicrophone()
            model?.close()
            model = null
        }
        executor.shutdown()
    }

    fun setRunning(value: Boolean) {
        running = value
        if (!value) stop()
    }

    private fun releaseMicrophone() {
        recording = false
        try { recorder?.stop() } catch (_: IllegalStateException) {}
        thread?.join(1000)
        thread = null
        recorder?.release()
        recorder = null
        recognizer?.close()
        recognizer = null
    }

    private fun prepareModel(): File {
        val name = "vosk-model-small-en-us-0.15"
        val directory = File(context.filesDir, name)
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
        val children = context.assets.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            context.assets.open(path).use { input ->
                destination.outputStream().use { input.copyTo(it) }
            }
        } else {
            destination.exists() || destination.mkdirs()
            children.forEach { copyAsset("$path/$it", File(destination, it)) }
        }
    }
}
