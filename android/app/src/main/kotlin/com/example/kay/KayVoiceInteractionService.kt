package com.example.kay

import android.service.voice.VoiceInteractionService
import android.util.Log
import android.content.ComponentName

class KayVoiceInteractionService : VoiceInteractionService() {

    companion object {
        private const val TAG = "KAY_ASSISTANT"

        @Volatile
        var instance: KayVoiceInteractionService? = null
            private set

        @Volatile
        var sessionActive = false

        fun isAvailable(): Boolean = instance?.let {
            it.ready && isActiveService(it, ComponentName(it, KayVoiceInteractionService::class.java))
        } == true
    }

    @Volatile private var ready = false

    override fun onReady() {
        super.onReady()
        if (instance !== this) return
        ready = true
        Log.i(TAG, "KAY_ASSISTANT_SERVICE_READY")
    }

    override fun onShutdown() {
        ready = false
        super.onShutdown()
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.i(TAG, "KAY_ASSISTANT_SERVICE_CREATED")
    }

    override fun onDestroy() {
        ready = false
        instance = null
        Log.i(TAG, "KAY_ASSISTANT_SERVICE_DESTROYED")
        super.onDestroy()
    }
}
