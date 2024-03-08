# vonage_video_call
Vonage 1 to 1 video call plugin

## Important:
When integrate this plugin in flutter app with version 1.0.0 or above, have to do the process to add VonageClientSDKVideo with swift package manager, because flutter can`t support this in plugin implementation.

- Open Runner.xcworkspace file in Xcode and add the VonageClientSDKVideo with swift package manager in project dependency.
- Add the following code in your Podfile

```
  pod 'VonageClientSDKVideo'
```