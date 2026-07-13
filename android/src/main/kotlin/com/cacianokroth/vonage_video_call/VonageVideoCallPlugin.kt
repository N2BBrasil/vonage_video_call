package com.cacianokroth.vonage_video_call

import ConnectionCallback
import ConnectionState
import SessionConfig
import VonageVideoCallHostApi
import VonageVideoCallPlatformApi
import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.content.Context
import android.opengl.GLSurfaceView
import android.os.Bundle
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
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class VonageVideoCallPlugin : FlutterPlugin, VonageVideoCallHostApi, ActivityAware {
  private lateinit var platformApi: VonageVideoCallPlatformApi
  private lateinit var videoPlatformView: VonageVideoCallPlatformView
  
  private var context: Context? = null
  private var session: Session? = null
  private var publisher: Publisher? = null
  private var subscriber: Subscriber? = null
  private var audioInitiallyEnabled = true
  private var videoInitiallyEnabled = true

  private var isEnding = false
  private var isReinitializing = false
  private var isCallActive = false
  private val remoteStreams = mutableMapOf<String, Stream>()

  private var lastTouchX = 0f
  private var lastTouchY = 0f

  private var currentActivity: Activity? = null
  private var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null
  private var publisherGlSurfaceView: GLSurfaceView? = null

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
    VonageVideoCallVideoFactory.resetViewInstance()
    context = null
  }
  
  override fun initSession(config: SessionConfig) {
    if (session != null) {
      isReinitializing = true
      endSession()
      isReinitializing = false
    }

    isEnding = false
    remoteStreams.clear()

    notifyConnectionChanges(ConnectionState.CONNECTING)
    
    audioInitiallyEnabled = config.audioInitiallyEnabled
    videoInitiallyEnabled = config.videoInitiallyEnabled
    
    session = Session.Builder(context, config.apiKey, config.id).build().also {
      it.setSessionListener(sessionListener)
      it.setReconnectionListener(reconnectionListener)
      it.connect(config.token)
    }
  }
  
  override fun endSession() {
    isEnding = true
    stopForegroundService()
    cleanUpSubscriber()
    cleanUpPublisher()
    remoteStreams.clear()
    if (!isReinitializing) {
      notifyConnectionChanges(ConnectionState.DISCONNECTED)
    }
    session?.setSessionListener(null)
    session?.setReconnectionListener(null)
    session?.disconnect()
    session = null
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
  
  override fun subscriberVideoIsEnabled(): Boolean {
    return subscriber?.stream?.hasVideo() ?: false
  }
  
  private val sessionListener: Session.SessionListener = object : Session.SessionListener {
    @SuppressLint("ClickableViewAccessibility")
    override fun onConnected(session: Session) {
      isCallActive = true
      context?.let { VonageCallForegroundService.start(it) }

      publisher = Publisher.Builder(context).build().apply {
        setPublisherListener(object : PublisherKit.PublisherListener {
          override fun onStreamCreated(publisherKit: PublisherKit, stream: Stream) {
            Log.d(TAG, "onStreamCreated: Publisher Stream Created. Own stream ${stream.streamId}")
          }
          
          override fun onStreamDestroyed(publisherKit: PublisherKit, stream: Stream) {
            Log.d(
              TAG, "onStreamDestroyed: Publisher Stream Destroyed. Own stream ${stream.streamId}"
            )

            if (isEnding || this@VonageVideoCallPlugin.session == null) return

            cleanUpPublisher()
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
          val glView = view as GLSurfaceView
          glView.setZOrderMediaOverlay(true)
          publisherGlSurfaceView = glView
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

          val density = containerView.resources.displayMetrics.density
          val topMargin = 200f * density
          val bottomMargin = 296f * density

          newPosX = newPosX.coerceIn(0f, maxX.toFloat().coerceAtLeast(0f))
          val minY = topMargin
          val maxYf = (maxY.toFloat() - bottomMargin)
          newPosY = newPosY.coerceIn(minY.coerceAtMost(maxYf), maxYf.coerceAtLeast(minY))
          
          view.animate().x(newPosX).y(newPosY).setDuration(0).start()
          
          lastTouchX = x
          lastTouchY = y
        }
        
        else -> return
      }
    }
    
    override fun onDisconnected(session: Session) {
      isEnding = false
      stopForegroundService()
      notifyConnectionChanges(ConnectionState.DISCONNECTED)
      this@VonageVideoCallPlugin.session = null
    }
    
    override fun onStreamReceived(session: Session?, stream: Stream?) {
      if (stream == null) return
      if (stream.streamId.equals(publisher?.stream?.streamId)) return

      remoteStreams[stream.streamId] = stream

      if (subscriber?.stream?.streamId == stream.streamId) return
      if (subscriber != null) return

      subscribeTo(stream)
    }

    override fun onStreamDropped(session: Session?, stream: Stream?) {
      if (stream == null) return

      remoteStreams.remove(stream.streamId)

      if (subscriber?.stream?.streamId != stream.streamId) return

      cleanUpSubscriber()
      notifySubscriberConnectionChanges(false)

      val nextStream = remoteStreams.values.lastOrNull()
      if (nextStream != null) {
        subscribeTo(nextStream)
      } else {
        notifyConnectionChanges(ConnectionState.WAITING)
      }
    }
    
    override fun onError(p0: Session?, opentokError: OpentokError?) {
      if (opentokError != null) notifyError(opentokError.message)
      stopForegroundService()
      cleanViews()
      notifyConnectionChanges(ConnectionState.DISCONNECTED)
      this@VonageVideoCallPlugin.session = null
    }

  }

  private fun subscribeTo(stream: Stream) {
    val currentSession = session ?: return

    subscriber = Subscriber.Builder(context, stream).build().also {
      it.renderer.setStyle(
        BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL
      )

      it.setSubscriberListener(object : SubscriberKit.SubscriberListener {
        override fun onConnected(subscriberKit: SubscriberKit) {
          runOnUiThread {
            subscriber?.view?.let { videoPlatformView.subscriberContainer.addView(it) }
          }
          notifySubscriberConnectionChanges(true)
          notifyConnectionChanges(ConnectionState.ON_CALL)
          notifySubscriberVideoChanges(subscriberKit.stream?.hasVideo() ?: false)
        }

        override fun onDisconnected(subscriberKit: SubscriberKit) {
          notifySubscriberConnectionChanges(false)
          cleanUpSubscriber()
          notifyConnectionChanges(ConnectionState.WAITING)
        }

        override fun onError(subscriberKit: SubscriberKit, opentokError: OpentokError) {
          notifyError(opentokError.message)
          cleanUpSubscriber()
          notifySubscriberConnectionChanges(false)
          notifyConnectionChanges(ConnectionState.WAITING)
        }
      })

      it.setVideoListener(object : SubscriberKit.VideoListener {
        override fun onVideoDataReceived(subscriberKit: SubscriberKit) {
        }

        override fun onVideoDisabled(subscriberKit: SubscriberKit, reason: String) {
          notifySubscriberVideoChanges(false)
        }

        override fun onVideoEnabled(subscriberKit: SubscriberKit, reason: String) {
          notifySubscriberVideoChanges(true)
        }

        override fun onVideoDisableWarning(subscriberKit: SubscriberKit) {}

        override fun onVideoDisableWarningLifted(subscriberKit: SubscriberKit) {}
      })
    }

    currentSession.subscribe(subscriber)
  }

  private val reconnectionListener: Session.ReconnectionListener = object : Session.ReconnectionListener {
    override fun onReconnecting(session: Session) {
      notifyConnectionChanges(ConnectionState.RECONNECTING)
    }
    
    override fun onReconnected(session: Session) {
      val hasSubscriber = subscriber != null
      notifyConnectionChanges(if (hasSubscriber) ConnectionState.ON_CALL else ConnectionState.WAITING)
    }
  }
  
  private fun notifyConnectionChanges(state: ConnectionState) {
    runOnUiThread {
      platformApi.onConnectionStateChanges(ConnectionCallback(state)) {}
    }
  }
  
  private fun notifySubscriberConnectionChanges(isConnected: Boolean) {
    runOnUiThread {
      platformApi.onSubscriberConnectionChanges(isConnected) {}
    }
  }
  
  private fun notifySubscriberVideoChanges(isEnabled: Boolean) {
    runOnUiThread {
      platformApi.onSubscriberVideoChanges(isEnabled) {}
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
      publisher?.destroy()
      lastTouchX = 0f
      lastTouchY = 0f
      publisher = null
    }
    publisherGlSurfaceView = null
    videoPlatformView.publisherContainer.removeAllViews()
  }
  
  private fun cleanUpSubscriber() {
    if (subscriber != null) {
      session?.unsubscribe(subscriber)
      subscriber = null
    }

    runOnUiThread {
      videoPlatformView.subscriberContainer.removeAllViews()
    }
  }
  
  private fun runOnUiThread(callback: () -> Unit) {
    Handler(Looper.getMainLooper()).post(callback)
  }

  private fun stopForegroundService() {
    isCallActive = false
    context?.let { VonageCallForegroundService.stop(it) }
  }
  
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    currentActivity = binding.activity
    activityLifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
      override fun onActivityPaused(activity: Activity) {
        if (activity != currentActivity) return
        // While an in-call foreground service is running, keep publishing when
        // the app is backgrounded/locked (T32). Only pause outside an active call.
        if (isCallActive) return
        publisherGlSurfaceView?.onPause()
        session?.onPause()
      }
      override fun onActivityResumed(activity: Activity) {
        if (activity != currentActivity) return
        // Mirror onActivityPaused: during an active call we never paused, so
        // there is nothing to resume.
        if (isCallActive) return
        session?.onResume()
        publisherGlSurfaceView?.onResume()
      }
      override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
      override fun onActivityStarted(activity: Activity) {}
      override fun onActivityStopped(activity: Activity) {}
      override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
      override fun onActivityDestroyed(activity: Activity) {}
    }
    binding.activity.application.registerActivityLifecycleCallbacks(activityLifecycleCallbacks)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    unregisterLifecycleCallbacks()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    session?.onPause()
    unregisterLifecycleCallbacks()
  }

  private fun unregisterLifecycleCallbacks() {
    activityLifecycleCallbacks?.let {
      currentActivity?.application?.unregisterActivityLifecycleCallbacks(it)
    }
    activityLifecycleCallbacks = null
    currentActivity = null
  }
}
