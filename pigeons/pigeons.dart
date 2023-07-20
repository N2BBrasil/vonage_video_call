import 'package:pigeon/pigeon.dart';

enum ConnectionState {
  disconnected,
  connecting,
  waiting,
  on_call,
}

enum AudioOutputDevice {
  speaker,
  headphone,
  bluetooth,
  receiver,
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
  final AudioOutputDevice type;
  final String name;

  const AudioOutputDeviceCallback({
    required this.type,
    required this.name,
  });
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

  List<AudioOutputDeviceCallback> listAvailableOutputDevices();

  void setOutputDevice(String deviceName);
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
