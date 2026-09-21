package com.example.kay

import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.util.Log

class KayVoiceInteractionSessionService : VoiceInteractionSessionService() {

    companion object {
        private const val TAG = "KAY_ASSISTANT"
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "KAY_ASSISTANT_SESSION_SERVICE_CREATED")
    }

    override fun onNewSession(args: Bundle): VoiceInteractionSession {
        Log.i(TAG, "KAY_ASSISTANT_NEW_SESSION_REQUESTED")
        return KayVoiceInteractionSession(this)
    }
}
