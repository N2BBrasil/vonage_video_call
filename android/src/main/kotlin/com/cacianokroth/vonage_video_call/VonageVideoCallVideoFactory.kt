package com.cacianokroth.vonage_video_call

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VonageVideoCallVideoFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  companion object {
    private lateinit var view: VonageVideoCallPlatformView
    
    fun getViewInstance(context: Context?): VonageVideoCallPlatformView {
      if (!this::view.isInitialized) {
        view = VonageVideoCallPlatformView(context)
      }
      return view
    }
  }
  
  override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
    return getViewInstance(context)
  }
}

