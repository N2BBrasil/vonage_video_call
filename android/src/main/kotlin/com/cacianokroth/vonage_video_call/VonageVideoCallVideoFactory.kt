package com.cacianokroth.vonage_video_call

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VonageVideoCallVideoFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  companion object {
    private var view: VonageVideoCallPlatformView? = null
    
    fun getViewInstance(context: Context?): VonageVideoCallPlatformView {
      if (view == null) {
        view = VonageVideoCallPlatformView(context)
      }
      return view!!
    }
    
    fun resetViewInstance() {
      view = null
    }
  }
  
  override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
    return getViewInstance(context)
  }
}

