package com.example.prayer_analyzer

object PrayerConfig {
    // Labels matching the User's request and Python config
    const val LABEL_QAYYAM = "Qayyam"
    const val LABEL_RUKU = "Ruku"
    const val LABEL_SUJUD = "Sujud"
    const val LABEL_TASHAHHUD = "Tashahhud"
    const val LABEL_UNKNOWN = "Unknown"
    const val LABEL_NONE = "none"

    val CLASSES = listOf(LABEL_QAYYAM, LABEL_RUKU, LABEL_SUJUD, LABEL_TASHAHHUD)

    // Configuration from Python
    const val FRAME_SKIP = 4
    const val CONFIRM_FRAMES = 8
    
    // Minimum duration in seconds to consider a pose stable
    val MIN_POSE_DURATION = mapOf(
        LABEL_QAYYAM to 0.15, // Reduced from 2.0 to match Python config: 0.15
        LABEL_RUKU to 1.0,
        LABEL_SUJUD to 1.0,
        LABEL_TASHAHHUD to 0.15
    )

    const val TRANSITION_COOLDOWN = 0.5 // Seconds
    const val DEFAULT_CONFIDENCE = 0.6
    const val MIN_BUFFER_AGREEMENT = 0.75
}
