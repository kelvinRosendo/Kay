package com.example.kay

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.SpeechRecognizer

/** Keeps the configured silence window even when the provider times out early. */
class KayCommandRecognizer(private val context: Context) {
    companion object {
        const val INITIAL_SILENCE = 1001
        @Volatile
        var initialWaitMs = 10_000L
        @Volatile
        var postWarningMs = 5_000L
        // The window used by the *next* recognition attempt; the foreground
        // service picks initialWaitMs or postWarningMs.
        @Volatile
        var windowMs = 10_000L
    }
    private val handler = Handler(Looper.getMainLooper())
    private var engine: SpeechRecognizer? = null
    private lateinit var listener: RecognitionListener
    private var request: Intent? = null
    private var active = false
    private var heardSpeech = false
    private var deadline = 0L
    private var generation = 0
    private val timeout = Runnable {
        if (active) completeError(if (heardSpeech) SpeechRecognizer.ERROR_SPEECH_TIMEOUT else INITIAL_SILENCE)
    }

    fun setRecognitionListener(value: RecognitionListener) { listener = value }

    fun startListening(intent: Intent) {
        destroy()
        active = true
        heardSpeech = false
        deadline = 0L
        request = Intent(intent)
        // Bound provider initialization too; initial silence starts only when it is ready.
        handler.postDelayed(timeout, 30_000)
        launch()
    }

    private fun launch() {
        if (!active) return
        val token = ++generation
        engine?.destroy()
        try {
            engine = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(object : RecognitionListener {
                    private fun current() = active && generation == token
                    override fun onReadyForSpeech(params: Bundle?) {
                        if (!current()) return
                        if (deadline == 0L) deadline = SystemClock.elapsedRealtime() + windowMs
                        handler.removeCallbacks(timeout)
                        handler.postDelayed(timeout, (deadline - SystemClock.elapsedRealtime()).coerceAtLeast(0))
                        listener.onReadyForSpeech(params)
                    }
                    override fun onBeginningOfSpeech() {
                        if (!current()) return
                        heardSpeech = true
                        handler.removeCallbacks(timeout)
                        handler.postDelayed(timeout, 30_000)
                        listener.onBeginningOfSpeech()
                    }
                    override fun onRmsChanged(rmsdB: Float) { if (current()) listener.onRmsChanged(rmsdB) }
                    override fun onBufferReceived(buffer: ByteArray?) { if (current()) listener.onBufferReceived(buffer) }
                    override fun onEndOfSpeech() { if (current()) listener.onEndOfSpeech() }
                    override fun onError(error: Int) {
                        if (!current()) return
                        if (!heardSpeech && (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                            if (deadline != 0L && SystemClock.elapsedRealtime() >= deadline) completeError(INITIAL_SILENCE)
                            else {
                                ++generation
                                handler.postDelayed({ if (active) launch() }, 150)
                            }
                        } else completeError(error)
                    }
                    override fun onResults(results: Bundle?) {
                        if (!current()) return
                        if (results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).isNullOrEmpty()) {
                            onError(SpeechRecognizer.ERROR_NO_MATCH)
                            return
                        }
                        active = false
                        handler.removeCallbacksAndMessages(null)
                        listener.onResults(results)
                    }
                    override fun onPartialResults(results: Bundle?) { if (current()) listener.onPartialResults(results) }
                    override fun onEvent(type: Int, params: Bundle?) { if (current()) listener.onEvent(type, params) }
                })
                startListening(request!!)
            }
        } catch (_: RuntimeException) { completeError(SpeechRecognizer.ERROR_CLIENT) }
    }

    private fun completeError(error: Int) {
        if (!active) return
        destroy()
        listener.onError(error)
    }
    fun stopListening() { engine?.stopListening() }
    fun destroy() {
        active = false
        ++generation
        handler.removeCallbacksAndMessages(null)
        engine?.destroy()
        engine = null
    }
}
