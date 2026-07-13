package com.cacianokroth.vonage_video_call

import android.content.Context
import android.view.ViewGroup
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class VonageVideoCallVideoFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  companion object {
    private var container: VonageVideoCallContainer? = null
    private var view: VonageVideoCallPlatformView? = null

    // The wrapper that currently owns the mounted container. Used so a stale
    // wrapper's dispose() does not detach the container from a newer mount.
    internal var activeView: VonageVideoCallPlatformView? = null

    // Single source of truth for the OpenTok publisher/subscriber surfaces.
    // Created once and reused across platform-view mount/unmount cycles so the
    // live surfaces are never destroyed, only re-parented.
    fun getContainerInstance(context: Context?): VonageVideoCallContainer {
      if (container == null) {
        container = VonageVideoCallContainer(context)
      }
      return container!!
    }

    fun getViewInstance(context: Context?): VonageVideoCallPlatformView {
      if (view == null) {
        view = VonageVideoCallPlatformView(context, mountable = false)
      }
      return view!!
    }

    fun resetViewInstance() {
      view = null
      container = null
      activeView = null
    }
  }

  override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
    // Re-parent the shared container here — create() runs exactly once per mount.
    // getView() must NOT do this: Flutter calls getView() repeatedly (focus,
    // accessibility, hit-testing) and detaching there orphans the live video
    // surfaces mid-call, blacking out the screen.
    val container = getContainerInstance(context)
    (container.parent as? ViewGroup)?.removeView(container)
    return VonageVideoCallPlatformView(context)
  }
}
