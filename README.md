# vonage_video_call

Vonage Video (OpenTok) 1 to 1 video call plugin for Flutter (Android and iOS).

## Installation

```yaml
dependencies:
  vonage_video_call:
    git:
      url: https://github.com/N2BBrasil/vonage_video_call.git
      ref: v1.5.1 # pin a release tag, see CHANGELOG.md
```

## Requirements

|             | Android         | iOS  |
| ----------- | --------------- | ---- |
| Min version | `minSdk 24`     | 15.0 |
| Build       | `compileSdk 37` | -    |

### Android

The plugin manifest already declares `RECORD_AUDIO`, `BLUETOOTH_CONNECT`, the `FOREGROUND_SERVICE*` permissions and the foreground service that keeps the call alive while the app is in background. The app must request the camera and microphone runtime permissions before calling `initSession`.

### iOS

Add the usage descriptions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used during video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone is used during video calls</string>
```

Since 1.0.0 the app must also add `VonageClientSDKVideo` itself, because the plugin can't ship it as a Swift package:

1. Open `ios/Runner.xcworkspace` in Xcode and add the Swift package `https://github.com/opentok/vonage-client-sdk-video` to the Runner target, using the version pinned in `ios/vonage_video_call.podspec`.
2. Add the pod to `ios/Podfile`:

```ruby
pod 'VonageClientSDKVideo'
```

## Usage

```dart
import 'package:vonage_video_call/vonage_vide_call.dart';

final call = VonageVideoCall(
  onConnectedOnSession: (connectionId) {},
  onConnectionChange: (connection) {}, // connection.state: ConnectionState
  onSubscriberConnectionChange: (connected) {},
  onSubscriberVideoChange: (enabled) {},
  onVideoCallError: (error) {},
);

await call.initSession(SessionConfig(
  id: sessionId,
  apiKey: apiKey,
  token: token,
  audioInitiallyEnabled: true,
  videoInitiallyEnabled: true,
));

// Renders the publisher and subscriber videos
const VonageVideoCallView();

await call.toggleAudio(false);
await call.toggleVideo(false);
await call.switchCamera();
final remoteVideoEnabled = await call.subscriberVideoIsEnabled();

await call.endSession();
call.dispose();
```

`ConnectionState`: `disconnected`, `connecting`, `reconnecting`, `waiting` (connected, waiting for the remote participant) and `on_call`.

## Development

Platform channels are generated with [pigeon](https://pub.dev/packages/pigeon). After editing `pigeons/pigeons.dart`, run `./run_pigeon.sh`.

## Release

Releases are automated with [release-please](https://github.com/googleapis/release-please). Don't bump `pubspec.yaml` or edit `CHANGELOG.md` by hand.

1. Merge into `master` using [Conventional Commits](https://www.conventionalcommits.org). On squash merge, the PR title is the commit message.
2. release-please opens or updates a Release PR with the new version in `pubspec.yaml` and the `CHANGELOG.md` entry.
3. Merging the Release PR creates the `vX.Y.Z` tag and the GitHub Release.

| Commit                                                   | Version bump |
| -------------------------------------------------------- | ------------ |
| `feat:`                                                  | minor        |
| `fix:`, `perf:`, `ref:`, `deps:`, `revert:`              | patch        |
| `feat!:` or `BREAKING CHANGE:` footer                    | major        |
| `chore:`, `ci:`, `docs:`, `refactor:`, `test:`, `build:` | none         |
