package com.cacianokroth.vonage_video_call

import android.content.Context
import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.platform.PlatformView

class VonageVideoCallPlatformView(
  context: Context?,
  private val mountable: Boolean = true,
) : PlatformView {
  // Shared, reused container holding the OpenTok publisher/subscriber surfaces.
  private val videoContainer: VonageVideoCallContainer =
    VonageVideoCallVideoFactory.getContainerInstance(context)

  val subscriberContainer get() = videoContainer.subscriberContainer
  val publisherContainer get() = videoContainer.publisherContainer

  override fun getView(): View {
    // Side-effect free: Flutter calls getView() repeatedly (focus, accessibility,
    // hit-testing), so re-parenting the shared container lives in the factory's
    // create() instead. Detaching here orphans the live video surfaces mid-call.
    if (mountable) {
      VonageVideoCallVideoFactory.activeView = this
    }
    return videoContainer
  }

  override fun dispose() {
    // Detach the shared container without destroying the OpenTok surfaces, so the
    // next create() can re-attach it. Guard against detaching from a newer mount
    // that already took ownership of the container.
    if (mountable && VonageVideoCallVideoFactory.activeView === this) {
      detachFromParent()
      VonageVideoCallVideoFactory.activeView = null
    }
  }

  private fun detachFromParent() {
    (videoContainer.parent as? ViewGroup)?.removeView(videoContainer)
  }
}
