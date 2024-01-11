import 'package:vonage_video_call/vonage_video_call_api.dart';

export 'vonage_video_call_api.dart'
    show ConnectionState, AudioOutputDevice, SessionConfig;
export 'vonage_video_call_view.dart';

class VonageVideoCall
    implements VonageVideoCallPlatformApi, VonageVideoCallHostApi {
  final _vonageHostApi = VonageVideoCallHostApi();

  final void Function(ConnectionCallback)? onConnectionChange;

  final void Function(AudioOutputDeviceCallback)? onDeviceUpdate;

  final void Function(bool)? onSubscriberConnectionChange;

  final void Function(bool)? onSubscriberVideoChange;

  final void Function(String)? onVideoCallError;

  final void Function(String)? onConnectedOnSession;

  VonageVideoCall({
    this.onConnectionChange,
    this.onSubscriberConnectionChange,
    this.onSubscriberVideoChange,
    this.onDeviceUpdate,
    this.onVideoCallError,
    this.onConnectedOnSession,
  }) {
    VonageVideoCallPlatformApi.setup(this);
  }

  @override
  void onSessionConnected(String connectionId) {
    onConnectedOnSession?.call(connectionId);
  }

  @override
  void onConnectionStateChanges(ConnectionCallback connection) {
    onConnectionChange?.call(connection);
  }

  @override
  void onAudioOutputDeviceChange(AudioOutputDeviceCallback outputDevice) {
    onDeviceUpdate?.call(outputDevice);
  }

  @override
  void onSubscriberConnectionChanges(bool connected) {
    onSubscriberConnectionChange?.call(connected);
  }

  @override
  void onSubscriberVideoChanges(bool enabled) {
    onSubscriberVideoChange?.call(enabled);
  }

  @override
  void onError(String error) {
    onVideoCallError?.call(error);
  }

  @override
  Future<void> initSession(SessionConfig sessionConfig) async {
    try {
      return await _vonageHostApi.initSession(sessionConfig);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> endSession() async {
    try {
      return await _vonageHostApi.endSession();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> toggleAudio(bool enabled) async {
    try {
      return await _vonageHostApi.toggleAudio(enabled);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    try {
      return await _vonageHostApi.switchCamera();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> toggleVideo(bool enabled) async {
    try {
      return await _vonageHostApi.toggleVideo(enabled);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<AudioOutputDeviceCallback?>> listAvailableOutputDevices() async {
    try {
      return await _vonageHostApi.listAvailableOutputDevices();
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> setOutputDevice(String deviceName) async {
    try {
      return await _vonageHostApi.setOutputDevice(deviceName);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<bool> subscriberVideoIsEnabled() {
    try {
      return _vonageHostApi.subscriberVideoIsEnabled();
    } catch (_) {
      return Future.value(false);
    }
  }
}
