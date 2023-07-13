import 'package:pigeon/pigeon.dart';

enum ConnectionState {
  disconnected,
  connecting,
  waiting,
  on_call,
}

enum AudioOutputDevice {
  speaker,
  receiver,
  headphone,
  bluetooth,
}

class SubscriberConnectionCallback {
  final bool connected;
  final bool videoEnabled;

  const SubscriberConnectionCallback({
    this.connected = false,
    this.videoEnabled = false,
  });
}

class AudioOutputDeviceCallback {
  final AudioOutputDevice device;

  const AudioOutputDeviceCallback(this.device);
}

class ConnectionCallback {
  final ConnectionState state;

  const ConnectionCallback(this.state);
}

class SessionConfig {
  final String id;
  final String apiKey;
  final String token;
  final bool audioInitiallyEnabled;
  final bool videoInitiallyEnabled;

  const SessionConfig({
    required this.id,
    required this.apiKey,
    required this.token,
    this.audioInitiallyEnabled = true,
    this.videoInitiallyEnabled = true,
  });
}

@HostApi()
abstract class VonageVideoCallHostApi {
  void initSession(SessionConfig config);

  void endSession();

  void switchCamera();

  void toggleAudio(bool enabled);

  void toggleVideo(bool enabled);

  List<String> listAvailableOutputDevices();

  void setOutputDevice(AudioOutputDevice device);
}

@FlutterApi()
abstract class VonageVideoCallPlatformApi {
  void onSessionConnected(String connectionId);

  void onConnectionStateChanges(ConnectionCallback connection);

  void onSubscriberConnectionChanges(
    SubscriberConnectionCallback subscriberConnection,
  );

  void onAudioOutputDeviceChange(AudioOutputDeviceCallback outputDevice);

  void onError(String error);
}
