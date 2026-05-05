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
    
    
    if(error != nil) {
      notifyError(error: error!.description)
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
    
    publisher = OTPublisher(delegate: self)
    
    publisher!.publishAudio = audioInitiallyEnabled
    publisher!.publishVideo = videoInitiallyEnabled
    
    session?.publish(publisher!, error: &error)
    
    if(error != nil) {
      notifyError(error: error!.description)
    }
    
    if(publisher?.view == nil) {
      return
    }
    
    if(videoFactory?.view == nil) {
      videoFactory?.publisherView = publisher!.view
    } else {
      videoFactory?.view?.addPublisherView(publisher!.view!)
    }
    
    videoFactory?.publisherView?.isHidden = !videoInitiallyEnabled
    
    notifyConnectionChanges(state: .waiting)
    platformApi?.onSessionConnected(connectionId: session!.connection!.connectionId) {}
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
  
  // OnStreamCreated
  public func session(_ session: OTSession, streamCreated stream: OTStream) {
    var error: OTError?
    
    if(subscriber != nil) {
      return
    }
    
    if(stream.streamId == publisher?.stream?.streamId) {
      return
    }
    
    subscriber = OTSubscriber(stream: stream, delegate: self)
    session.subscribe(subscriber!, error: &error)
    notifySubscriberConnectionChanges(isConnected: true)
    notifyConnectionChanges(state: .onCall)
    
    if(error != nil) {
      notifyError(error: error!.description)
    }
    
  }
  
  // OnStreamDestroyed
  public func session(_ session: OTSession, streamDestroyed stream: OTStream) {
    if(subscriber != nil) {
      if(subscriber!.stream!.streamId.elementsEqual(stream.streamId)) {
        cleanUpSubscriber()
        notifySubscriberConnectionChanges(isConnected: false)
      }
    }
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
    if(subscriber?.view == nil) {
      return
    }
    
    subscriber?.viewScaleBehavior = .fill
    
    if(videoFactory?.view == nil) {
      videoFactory?.subscriberView = subscriber!.view
    } else {
      videoFactory?.view?.addSubscriberView(subscriber!.view!)
    }
    
    subscriber?.view?.contentMode = .scaleAspectFill
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
