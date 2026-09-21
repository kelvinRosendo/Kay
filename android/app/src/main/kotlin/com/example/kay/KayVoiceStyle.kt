package com.example.kay

import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale
import android.content.Context

object KayVoiceStyle {
    fun apply(tts: TextToSpeech, context: Context) {
        tts.language = Locale("pt", "BR")
        val voices = tts.voices.orEmpty().filter { it.locale.language == "pt" && it.locale.country == "BR" }
        // Gender is not a standard Android Voice field; use it only when explicitly named.
        val male = voices.filter {
            Regex("(^|[^a-z])(male|masculino|masculina)([^a-z]|$)").containsMatchIn(it.name.lowercase())
        }.sortedWith(compareBy({ it.isNetworkConnectionRequired }, { -it.quality }, { it.name })).firstOrNull()
        val selected = context.getSharedPreferences("kay_voice", Context.MODE_PRIVATE).getString("name", null)
        val preferred = voices.firstOrNull { it.name == selected } ?: male
        if (preferred != null) tts.voice = preferred
        tts.setPitch(0.82f)
        tts.setSpeechRate(0.48f)
        Log.i("KAY_ASSISTANT", "KAY_TTS_VOICES: ${voices.map { it.name }}")
        Log.i("KAY_ASSISTANT", "KAY_TTS_SELECTED: ${tts.voice?.name}; maleIdentified=${male != null}; pitch=0.82")
    }
}
