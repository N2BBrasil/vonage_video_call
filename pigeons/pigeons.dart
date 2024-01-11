import 'package:pigeon/pigeon.dart';

// #docregion config
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/vonage_video_call_api.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/cacianokroth/vonage_video_call/VonageVideoCall.kt',
    kotlinOptions: KotlinOptions(errorClassName: 'VonageVideoCallError'),
    swiftOut: 'ios/Classes/VonageVideoCall.g.swift',
    swiftOptions: SwiftOptions(),
    // Set this to a unique prefix for your plugin or application, per Objective-C naming conventions.
    objcOptions: ObjcOptions(prefix: 'VVC'),
    dartPackageName: 'vonage_video_call_api',
  ),
)
// #enddocregion config

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

  bool subscriberVideoIsEnabled();
}

@FlutterApi()
abstract class VonageVideoCallPlatformApi {
  void onSessionConnected(String connectionId);

  void onConnectionStateChanges(ConnectionCallback connection);

  void onAudioOutputDeviceChange(AudioOutputDeviceCallback outputDevice);

  void onSubscriberConnectionChanges(bool connected);

  void onSubscriberVideoChanges(bool enabled);

  void onError(String error);
}
