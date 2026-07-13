import Flutter
import UIKit
import OpenTok

public class VonageVideoCallPlugin: NSObject, FlutterPlugin, VonageVideoCallHostApi {
  private var platformApi: VonageVideoCallPlatformApi?
  private var videoFactory: VonageVideoCallVideoFactory?
  
  private var session: OTSession?
  private var publisher: OTPublisher?
  private var subscriber: OTSubscriber?

  private var isEnding = false
  private var disconnectingSession: OTSession?
  private var remoteStreams: [String: OTStream] = [:]

  private var audioInitiallyEnabled = true
  private var videoInitiallyEnabled = true

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance:VonageVideoCallPlugin! = VonageVideoCallPlugin()
    let binaryMessenger = registrar.messenger()
    
    VonageVideoCallHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: instance)
    instance.platformApi = VonageVideoCallPlatformApi(binaryMessenger: binaryMessenger)
    instance.videoFactory = VonageVideoCallVideoFactory(binaryMessenger: binaryMessenger)
    
    registrar.register(instance.videoFactory!, withId:"VonageVideoCallRendererView")
  }
  
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    cleanUpPublisher()
    cleanUpSubscriber()
    session?.disconnect(nil)
    session = nil
    VonageVideoCallHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    platformApi = nil
    videoFactory = nil
  }
  
  func initSession(config: SessionConfig) throws {
    var error: OTError?

    // Re-entry guard (T22): tear down any existing session (connecting or
    // connected) so a fast retry does not orphan a still-connecting session
    // whose delegate keeps firing.
    if session != nil {
      try endSession()
    }
    // Safety nil (T50): drop any held session if a terminal callback never
    // arrived, and reset the ending flag for the fresh session.
    disconnectingSession = nil
    isEnding = false
    // Reset the remote-stream map (T13) so a fresh session never inherits
    // stale OTStreams from a prior session that ended via didFailWithError
    // (which nils session without going through endSession).
    remoteStreams.removeAll()

    notifyConnectionChanges(state: .connecting)

    audioInitiallyEnabled = config.audioInitiallyEnabled
    videoInitiallyEnabled = config.videoInitiallyEnabled

    session = OTSession(apiKey: config.apiKey, sessionId: config.id, delegate: self)
    session?.connect(withToken: config.token, error: &error)


    if let error = error {
      notifyError(error: error.description)
    }
  }

  func endSession() throws {
    var error: OTError?

    isEnding = true
    cleanUpPublisher()
    cleanUpSubscriber()
    remoteStreams.removeAll()
    notifyConnectionChanges(state: .disconnected)
    session?.disconnect(&error)
    // Retain the session through the async disconnect window (T50) so late
    // delegate callbacks fire against a valid reference, not a dropped one.
    disconnectingSession = session
    session = nil

    if let error = error {
      notifyError(error: error.description)
    }
  }
  
  func switchCamera() throws {
    publisher?.cameraPosition = publisher?.cameraPosition == .back ? .front : .back
  }
  
  func toggleAudio(enabled: Bool) throws {
    publisher?.publishAudio = enabled
    
  }
  
  func toggleVideo(enabled: Bool) throws {
    publisher?.publishVideo = enabled
    videoFactory?.publisherView?.isHidden = !enabled
  }
  
  func subscriberVideoIsEnabled() throws -> Bool {
    return subscriber?.stream?.hasVideo ?? false
  }
  
  private func notifyConnectionChanges(state: ConnectionState) {
    platformApi?.onConnectionStateChanges(connection: ConnectionCallback(state: state)) {}
  }
  
  private func notifySubscriberConnectionChanges(isConnected: Bool) {
    platformApi?.onSubscriberConnectionChanges(connected: isConnected) {}
  }
  
  private func notifySubscriberVideoChanges(isEnabled: Bool) {
    platformApi?.onSubscriberVideoChanges(enabled: isEnabled) {}
  }
  
  private func notifyError(error: String) {
    platformApi?.onError(error: error) {}
  }
  
  
  private func cleanViews() {
    cleanUpPublisher()
    cleanUpSubscriber()
  }
  
  private func cleanUpPublisher() {
    guard let pub = publisher else { return }
    var error: OTError?
    pub.view?.removeFromSuperview()
    session?.unpublish(pub, error: &error)
    publisher = nil
    videoFactory?.publisherView = nil
    if let error = error {
      notifyError(error: error.description)
    }
  }
  
  private func cleanUpSubscriber() {
    guard let sub = subscriber else { return }
    var error: OTError?
    sub.view?.removeFromSuperview()
    session?.unsubscribe(sub, error: &error)
    subscriber = nil
    videoFactory?.subscriberView = nil
    if let error = error {
      notifyError(error: error.description)
    }
  }
}

extension VonageVideoCallPlugin: OTSessionDelegate {
  public func sessionDidConnect(_ sessionDelegate: OTSession) {
    var error: OTError?
    
    guard let pub = OTPublisher(delegate: self) else { return }
    publisher = pub
    
    pub.publishAudio = audioInitiallyEnabled
    pub.publishVideo = videoInitiallyEnabled
    
    session?.publish(pub, error: &error)
    
    if let error = error {
      notifyError(error: error.description)
    }
    
    guard let pubView = pub.view else { return }

    videoFactory?.publisherView = pubView

    if videoFactory?.view == nil {
      videoFactory?.publisherView = pubView
    } else {
      videoFactory?.view?.addPublisherView(pubView)
    }
    
    videoFactory?.publisherView?.isHidden = !videoInitiallyEnabled
    
    notifyConnectionChanges(state: .waiting)
    
    if let connectionId = session?.connection?.connectionId {
      platformApi?.onSessionConnected(connectionId: connectionId) {}
    }
  }
  
  public func sessionDidDisconnect(_ session: OTSession) {
    notifyConnectionChanges(state: .disconnected)
    // Release the retained session and clear the ending flag on the terminal
    // path (T50 / T35).
    disconnectingSession = nil
    isEnding = false
  }

  public func session(_ session: OTSession, didFailWithError error: OTError) {
    notifyError(error: error.description)
    cleanViews()
    notifyConnectionChanges(state: .disconnected)
    self.session = nil
    // Terminal path: release the retained session, clear the ending flag, and
    // drop tracked remote streams (T50 / T35 / T13) so they can't leak into a
    // retry that skips endSession.
    disconnectingSession = nil
    isEnding = false
    remoteStreams.removeAll()
  }

  public func session(_ session: OTSession, streamCreated stream: OTStream) {
    guard stream.streamId != publisher?.stream?.streamId else { return }

    // Track every live remote stream (T13) even when a subscriber already
    // exists, so a later drop can re-subscribe to a remaining one.
    remoteStreams[stream.streamId] = stream

    // Already subscribed to THIS stream — nothing to do.
    guard subscriber?.stream?.streamId != stream.streamId else { return }
    // Single-active-subscriber invariant: only subscribe when free.
    guard subscriber == nil else { return }

    subscribeTo(stream)
  }

  private func subscribeTo(_ stream: OTStream) {
    var error: OTError?
    guard let sub = OTSubscriber(stream: stream, delegate: self) else { return }
    subscriber = sub

    session?.subscribe(sub, error: &error)

    if let error = error {
      notifyError(error: error.description)
      cleanUpSubscriber()
      notifySubscriberConnectionChanges(isConnected: false)
      notifyConnectionChanges(state: .waiting)
    }
  }

  public func session(_ session: OTSession, streamDestroyed stream: OTStream) {
    remoteStreams.removeValue(forKey: stream.streamId)

    guard let sub = subscriber, sub.stream?.streamId == stream.streamId else { return }
    cleanUpSubscriber()
    notifySubscriberConnectionChanges(isConnected: false)

    // If other remote streams remain, re-subscribe to one instead of only
    // going .waiting (T13). cleanUpSubscriber() nils subscriber, preserving
    // the single-active-subscriber invariant.
    if let next = remoteStreams.values.first {
      subscribeTo(next)
    } else {
      notifyConnectionChanges(state: .waiting)
    }
  }
  
  public func sessionDidBeginReconnecting(_ session: OTSession) {
    notifyConnectionChanges(state: .reconnecting)
  }
  
  public func sessionDidReconnect(_ session: OTSession) {
    let hasSubscriber = subscriber != nil
    notifyConnectionChanges(state: hasSubscriber ? .onCall : .waiting)
  }
}

extension VonageVideoCallPlugin: OTPublisherDelegate {
  public func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    print("onStreamCreated: Publisher Stream Created. Own stream \(stream.streamId)")
  }
  
  public func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
    // Publisher-only teardown event (T35): during endSession (or after the
    // session is gone) never flip DISCONNECTED back to WAITING.
    guard !isEnding, session != nil else { return }

    if subscriber != nil {
      notifySubscriberConnectionChanges(isConnected: false)
    }
    // Tear down ONLY the publisher — a publisher-only stream death must not
    // kill the remote subscriber (T35).
    cleanUpPublisher()
    notifyConnectionChanges(state: .waiting)
  }
  
  public func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
    notifyError(error: error.description)
  }
}

extension VonageVideoCallPlugin: OTSubscriberDelegate {
  public func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
    guard let sub = subscriber, let subView = sub.view else { return }
    
    sub.viewScaleBehavior = .fill

    videoFactory?.subscriberView = subView

    if videoFactory?.view == nil {
      videoFactory?.subscriberView = subView
    } else {
      videoFactory?.view?.addSubscriberView(subView)
    }
    
    subView.contentMode = .scaleAspectFill

    notifySubscriberConnectionChanges(isConnected: true)
    notifyConnectionChanges(state: .onCall)
    notifySubscriberVideoChanges(isEnabled: subscriber?.stream?.hasVideo ?? false)
  }

  public func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
    notifyError(error: error.description)
    cleanUpSubscriber()
    notifySubscriberConnectionChanges(isConnected: false)
    notifyConnectionChanges(state: .waiting)
  }
  
  public func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {}
  
  public func subscriberVideoEnabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
    notifySubscriberVideoChanges(isEnabled: true)
  }

  public func subscriberVideoDisabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
    notifySubscriberVideoChanges(isEnabled: false)
  }
}
