import Flutter
import UIKit
import OpenTok

public class VonageVideoCallPlugin: NSObject, FlutterPlugin, VonageVideoCallHostApi {
  private var platformApi: VonageVideoCallPlatformApi?
  private var videoFactory: VonageVideoCallVideoFactory?
  
  private var session: OTSession?
  private var publisher: OTPublisher?
  private var subscriber: OTSubscriber?
  
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
    
    cleanUpPublisher()
    cleanUpSubscriber()
    notifyConnectionChanges(state: .disconnected)
    session?.disconnect(&error)
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
    
    let pub = OTPublisher(delegate: self)
    publisher = pub
    
    pub.publishAudio = audioInitiallyEnabled
    pub.publishVideo = videoInitiallyEnabled
    
    session?.publish(pub, error: &error)
    
    if let error = error {
      notifyError(error: error.description)
    }
    
    guard let pubView = pub.view else { return }
    
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
  }
  
  public func session(_ session: OTSession, didFailWithError error: OTError) {
    notifyError(error: error.description)
    cleanViews()
    notifyConnectionChanges(state: .disconnected)
    self.session = nil
  }
  
  public func session(_ session: OTSession, streamCreated stream: OTStream) {
    guard subscriber == nil else { return }
    guard stream.streamId != publisher?.stream?.streamId else { return }
    
    var error: OTError?
    let sub = OTSubscriber(stream: stream, delegate: self)
    subscriber = sub
    
    session.subscribe(sub, error: &error)
    notifySubscriberConnectionChanges(isConnected: true)
    notifyConnectionChanges(state: .onCall)
    
    if let error = error {
      notifyError(error: error.description)
    }
  }
  
  public func session(_ session: OTSession, streamDestroyed stream: OTStream) {
    guard let sub = subscriber, sub.stream?.streamId == stream.streamId else { return }
    cleanUpSubscriber()
    notifySubscriberConnectionChanges(isConnected: false)
    notifyConnectionChanges(state: .waiting)
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
    cleanViews()
  }
  
  public func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
    notifyError(error: error.description)
  }
}

extension VonageVideoCallPlugin: OTSubscriberDelegate {
  public func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
    guard let sub = subscriber, let subView = sub.view else { return }
    
    sub.viewScaleBehavior = .fill
    
    if videoFactory?.view == nil {
      videoFactory?.subscriberView = subView
    } else {
      videoFactory?.view?.addSubscriberView(subView)
    }
    
    subView.contentMode = .scaleAspectFill
  }
  
  public func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
    notifyError(error: error.description)
  }
  
  public func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {}
  
  public func subscriberVideoEnabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
    notifySubscriberVideoChanges(isEnabled: true)
  }
  
  public func subscriberVideoDisabled(_ subscriber: OTSubscriberKit, reason: OTSubscriberVideoEventReason) {
    notifySubscriberVideoChanges(isEnabled: false)
  }
}
