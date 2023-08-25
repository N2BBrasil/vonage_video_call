package com.cacianokroth.vonage_video_call

import AudioOutputDevice
import AudioOutputDeviceCallback
import ConnectionCallback
import ConnectionState
import SessionConfig
import SubscriberConnectionCallback
import VonageVideoCallHostApi
import VonageVideoCallPlatformApi
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import com.opentok.android.AudioDeviceManager
import com.opentok.android.BaseVideoRenderer
import com.opentok.android.OpentokError
import com.opentok.android.Publisher
import com.opentok.android.PublisherKit
import com.opentok.android.Session
import com.opentok.android.Stream
import com.opentok.android.Subscriber
import com.opentok.android.SubscriberKit
import io.flutter.embedding.engine.plugins.FlutterPlugin

class VonageVideoCallPlugin : FlutterPlugin, VonageVideoCallHostApi {
  private lateinit var platformApi: VonageVideoCallPlatformApi
  private lateinit var videoPlatformView: VonageVideoCallPlatformView
  
  private var context: Context? = null
  private var session: Session? = null
  private var audioDevice: CustomAudioDevice? = null
  
  private var publisher: Publisher? = null
  
  private var subscriber: Subscriber? = null
  private var subscriberConnectionCallback: SubscriberConnectionCallback? = null
  
  private var audioInitiallyEnabled = true
  private var videoInitiallyEnabled = true
  
  private var lastTouchX = 0f
  private var lastTouchY = 0f
  
  companion object {
    private val TAG = VonageVideoCallPlugin::class.java.simpleName
  }
  
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    flutterPluginBinding.platformViewRegistry.registerViewFactory(
      "VonageVideoCallRendererView", VonageVideoCallVideoFactory(),
    )
    
    val binaryMessenger = flutterPluginBinding.binaryMessenger
    context = flutterPluginBinding.applicationContext
    videoPlatformView = VonageVideoCallVideoFactory.getViewInstance(context)
    VonageVideoCallHostApi.setUp(binaryMessenger, this)
    platformApi = VonageVideoCallPlatformApi(binaryMessenger)
  }
  
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    VonageVideoCallHostApi.setUp(binding.binaryMessenger, null)
    context = null
  }
  
  override fun initSession(config: SessionConfig) {
    notifyConnectionChanges(ConnectionState.CONNECTING)
    
    audioInitiallyEnabled = config.audioInitiallyEnabled
    videoInitiallyEnabled = config.videoInitiallyEnabled
    
    if (audioDevice == null) {
      audioDevice = CustomAudioDevice(
        context,
      ) { device ->
        Log.d(TAG, "Audio output changed to ${device.type}")
        
        runOnUiThread {
          platformApi.onAudioOutputDeviceChange(
            AudioOutputDeviceCallback(
              type = getAudioOutputDevice(device.type),
              name = device.name,
            )
          ) {}
        }
      }
    }
    
    if (session == null) AudioDeviceManager.setAudioDevice(audioDevice)
    
    session = Session.Builder(context, config.apiKey, config.id).build()
    session!!.setSessionListener(sessionListener)
    session!!.connect(config.token)
  }
  
  override fun endSession() {
    notifyConnectionChanges(ConnectionState.DISCONNECTED)
    session?.setSessionListener(null)
    session?.disconnect()
  }
  
  override fun switchCamera() {
    publisher?.cycleCamera()
  }
  
  override fun toggleAudio(enabled: Boolean) {
    publisher?.publishAudio = enabled
  }
  
  override fun toggleVideo(enabled: Boolean) {
    publisher?.publishVideo = enabled
    
    if (enabled) {
      videoPlatformView.publisherContainer.visibility = View.VISIBLE
    } else {
      videoPlatformView.publisherContainer.visibility = View.GONE
    }
  }
  
  override fun listAvailableOutputDevices(): List<AudioOutputDeviceCallback> {
    return audioDevice!!.availableOutputs.map {
      AudioOutputDeviceCallback(
        getAudioOutputDevice(it.type),
        it.name,
      )
    }
  }
  
  override fun setOutputDevice(deviceName: String) {
    audioDevice!!.changeOutputType(audioDevice!!.availableOutputs.first { it.name == deviceName }.type)
  }
  
  private fun getAudioOutputDevice(type: OutputDevice): AudioOutputDevice {
    return when (type) {
      OutputDevice.SPEAKER_PHONE -> AudioOutputDevice.SPEAKER
      OutputDevice.BLUETOOTH -> AudioOutputDevice.BLUETOOTH
      OutputDevice.RECEIVER -> AudioOutputDevice.RECEIVER
      OutputDevice.HEAD_PHONES -> AudioOutputDevice.HEADPHONE
    }
  }
  
  private val sessionListener: Session.SessionListener = object : Session.SessionListener {
    @SuppressLint("ClickableViewAccessibility")
    override fun onConnected(session: Session) {
      publisher = Publisher.Builder(context).build().apply {
        setPublisherListener(object : PublisherKit.PublisherListener {
          override fun onStreamCreated(publisherKit: PublisherKit, stream: Stream) {
            Log.d(TAG, "onStreamCreated: Publisher Stream Created. Own stream ${stream.streamId}")
          }
          
          override fun onStreamDestroyed(publisherKit: PublisherKit, stream: Stream) {
            Log.d(
              TAG, "onStreamDestroyed: Publisher Stream Destroyed. Own stream ${stream.streamId}"
            )
            
            cleanViews()
          }
          
          override fun onError(publisherKit: PublisherKit, opentokError: OpentokError) {
            notifyError(opentokError.message)
          }
        })
        
        renderer.setStyle(BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL)
        
        view.layoutParams = ViewGroup.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )
        
        publishAudio = audioInitiallyEnabled
        publishVideo = videoInitiallyEnabled
        
        videoPlatformView.publisherContainer.addView(view)
        videoPlatformView.publisherContainer.setOnTouchListener { view, event ->
          handleTouch(view, event)
          true
        }
        
        if (view is GLSurfaceView) {
          (view as GLSurfaceView).setZOrderOnTop(true)
        }
        
        videoPlatformView.publisherContainer.visibility =
          if (videoInitiallyEnabled) View.VISIBLE else View.GONE
      }
      
      session.publish(publisher)
      notifyConnectionChanges(ConnectionState.WAITING)
      
      runOnUiThread {
        platformApi.onSessionConnected(session.connection.connectionId) {}
      }
    }
    
    private fun handleTouch(view: View, event: MotionEvent) {
      val x = event.rawX
      val y = event.rawY
      
      when (event.action) {
        MotionEvent.ACTION_DOWN -> {
          lastTouchX = x
          lastTouchY = y
        }
        
        MotionEvent.ACTION_MOVE -> {
          val dx = x - lastTouchX
          val dy = y - lastTouchY
          
          var newPosX = view.x + dx
          var newPosY = view.y + dy
          
          val containerView = videoPlatformView.view
          val maxX = containerView.width - view.width
          val maxY = containerView.height - view.height
          
          newPosX = newPosX.coerceIn(0f, maxX.toFloat())
          newPosY = newPosY.coerceIn(200f, maxY.toFloat() - 296f)
          
          view.animate().x(newPosX).y(newPosY).setDuration(0).start()
          
          lastTouchX = x
          lastTouchY = y
        }
        
        else -> return
      }
    }
    
    override fun onDisconnected(session: Session) {
      notifyConnectionChanges(ConnectionState.DISCONNECTED)
    }
    
    override fun onStreamReceived(session: Session?, stream: Stream?) {
      if (subscriber != null) return
      if (stream?.streamId.equals(publisher?.stream?.streamId)) return
      
      subscriber = Subscriber.Builder(context, stream).build().also {
        it.renderer.setStyle(
          BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL
        )
        
        it.setSubscriberListener(object : SubscriberKit.SubscriberListener {
          override fun onConnected(subscriberKit: SubscriberKit) {}
          
          override fun onDisconnected(subscriberKit: SubscriberKit) {
            notifyConnectionChanges(ConnectionState.WAITING)
          }
          
          override fun onError(subscriberKit: SubscriberKit, opentokError: OpentokError) {
            notifyError(opentokError.message)
          }
        })
        
        it.setVideoListener(object : SubscriberKit.VideoListener {
          override fun onVideoDataReceived(subscriberKit: SubscriberKit) {
            notifySubscriberConnectionChanges(videoEnabled = true)
          }
          
          override fun onVideoDisabled(subscriberKit: SubscriberKit, reason: String) {
            notifySubscriberConnectionChanges(videoEnabled = false)
          }
          
          override fun onVideoEnabled(subscriberKit: SubscriberKit, reason: String) {
            notifySubscriberConnectionChanges(videoEnabled = true)
          }
          
          override fun onVideoDisableWarning(subscriberKit: SubscriberKit) {}
          
          override fun onVideoDisableWarningLifted(subscriberKit: SubscriberKit) {}
        })
        
        notifySubscriberConnectionChanges(connected = true)
      }
      
      session!!.subscribe(subscriber)
      videoPlatformView.subscriberContainer.addView(subscriber!!.view)
      notifyConnectionChanges(ConnectionState.ON_CALL)
      
    }
    
    override fun onStreamDropped(session: Session?, p1: Stream?) {
      if (subscriber != null) {
        cleanUpSubscriber()
        notifySubscriberConnectionChanges(false)
      }
    }
    
    override fun onError(p0: Session?, opentokError: OpentokError?) {
      if (opentokError != null) notifyError(opentokError.message)
    }
    
  }
  
  private fun notifyConnectionChanges(state: ConnectionState) {
    runOnUiThread {
      platformApi.onConnectionStateChanges(ConnectionCallback(state)) {}
    }
  }
  
  private fun notifySubscriberConnectionChanges(
    connected: Boolean? = null, videoEnabled: Boolean? = null
  ) {
    subscriberConnectionCallback = if (subscriberConnectionCallback == null) {
      SubscriberConnectionCallback(
        connected ?: false,
        videoEnabled ?: false,
      )
    } else {
      subscriberConnectionCallback!!.copy(
        connected = connected ?: subscriberConnectionCallback!!.connected,
        videoEnabled = videoEnabled ?: subscriberConnectionCallback!!.videoEnabled,
      )
    }
    
    runOnUiThread {
      platformApi.onSubscriberConnectionChanges(subscriberConnectionCallback!!) {}
    }
  }
  
  private fun notifyError(error: String) {
    runOnUiThread {
      platformApi.onError(error) {}
    }
  }
  
  private fun cleanViews() {
    cleanUpPublisher()
    cleanUpSubscriber()
  }
  
  private fun cleanUpPublisher() {
    if (publisher != null) {
      session?.unpublish(publisher)
      publisher?.capturer?.stopCapture()
      lastTouchX = 0f
      lastTouchY = 0f
      publisher = null
    }
    
    videoPlatformView.publisherContainer.removeAllViews()
  }
  
  private fun cleanUpSubscriber() {
    if (subscriber != null) {
      session?.unsubscribe(subscriber)
      subscriber = null
    }
    
    videoPlatformView.subscriberContainer.removeAllViews()
  }
  
  private fun runOnUiThread(callback: () -> Unit) {
    Handler(Looper.getMainLooper()).post(callback)
  }
}
