package com.cacianokroth.vonage_video_call

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.FrameLayout
import android.widget.LinearLayout

class VonageVideoCallContainer @JvmOverloads constructor(
  context: Context?,
  attrs: AttributeSet? = null,
  defStyle: Int = 0,
  defStyleRes: Int = 0
) : LinearLayout(context, attrs, defStyle, defStyleRes) {
  
  var subscriberContainer: FrameLayout
    private set
  
  var publisherContainer: FrameLayout
    private set
  
  init {
    val mainView = LayoutInflater.from(context).inflate(R.layout.view_video, this, true)
    
    subscriberContainer = mainView.findViewById(R.id.subscriber_container)
    publisherContainer = mainView.findViewById(R.id.publisher_container)
  }
}
