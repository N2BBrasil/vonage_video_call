package com.cacianokroth.vonage_video_call

enum class OutputDevice {
  SPEAKER_PHONE,
  RECEIVER,
  HEAD_PHONES,
  BLUETOOTH
}

data class OutputDeviceCallback(val type: OutputDevice, val name: String) {}