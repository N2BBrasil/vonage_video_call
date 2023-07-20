package com.cacianokroth.vonage_video_call

import android.content.Context
import android.view.View
import io.flutter.plugin.platform.PlatformView

class VonageVideoCallPlatformView(context: Context?) : PlatformView {
  private val videoContainer: VonageVideoCallContainer = VonageVideoCallContainer(context)
  
  val subscriberContainer get() = videoContainer.subscriberContainer
  val publisherContainer get() = videoContainer.publisherContainer
  
  override fun getView(): View {
    return videoContainer
  }
  
  override fun dispose() {}
}