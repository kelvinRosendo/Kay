package com.example.kay

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.RemoteException
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.SpeechRecognizer

/** Adapts the installed recognizer to the assistant's declared recognition service. */
class KayRecognitionService : RecognitionService() {
    private var recognizer: SpeechRecognizer? = null
    private var callback: Callback? = null

    @Suppress("DEPRECATION")
    override fun onStartListening(intent: Intent, listener: Callback) {
        release()
        callback = listener
        // Never delegate to ourselves, even if Android selects Kay as the default recognizer.
        val candidates = packageManager.queryIntentServices(Intent(SERVICE_INTERFACE), 0)
            .map { it.serviceInfo }
            .filter { it.packageName != packageName && it.enabled && it.exported }
            .map { ComponentName(it.packageName, it.name) }
        val preferred = Settings.Secure.getString(contentResolver, "voice_recognition_service")
            ?.let { ComponentName.unflattenFromString(it) }
        val target = candidates.firstOrNull { it == preferred } ?: candidates.firstOrNull()
        if (target == null) {
            deliver(listener, true) { error(SpeechRecognizer.ERROR_CLIENT) }
            return
        }
        try {
            recognizer = SpeechRecognizer.createSpeechRecognizer(this, target).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) = deliver(listener) { readyForSpeech(params ?: Bundle()) }
                    override fun onBeginningOfSpeech() = deliver(listener) { beginningOfSpeech() }
                    override fun onRmsChanged(rmsdB: Float) = deliver(listener) { rmsChanged(rmsdB) }
                    override fun onBufferReceived(buffer: ByteArray?) = deliver(listener) { bufferReceived(buffer ?: byteArrayOf()) }
                    override fun onEndOfSpeech() = deliver(listener) { endOfSpeech() }
                    override fun onError(error: Int) = deliver(listener, true) { error(error) }
                    override fun onResults(results: Bundle?) = deliver(listener, true) { results(results ?: Bundle()) }
                    override fun onPartialResults(partialResults: Bundle?) = deliver(listener) { partialResults(partialResults ?: Bundle()) }
                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
                startListening(Intent(intent))
            }
        } catch (_: RuntimeException) {
            deliver(listener, true) { error(SpeechRecognizer.ERROR_CLIENT) }
        }
    }

    private fun deliver(listener: Callback, terminal: Boolean = false, action: Callback.() -> Unit) {
        if (callback !== listener) return
        try {
            listener.action()
        } catch (_: RemoteException) {
            release()
        } finally {
            if (terminal) release()
        }
    }

    override fun onStopListening(listener: Callback) {
        if (callback === listener) recognizer?.stopListening()
    }

    override fun onCancel(listener: Callback) {
        if (callback === listener) release()
    }

    private fun release() {
        callback = null
        recognizer?.destroy()
        recognizer = null
    }

    override fun onDestroy() {
        release()
        super.onDestroy()
    }
}
