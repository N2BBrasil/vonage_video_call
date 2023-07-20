# Run this file to regenerate pigeon files
dart run pigeon \
  --input pigeons/pigeons.dart \
  --dart_out lib/vonage_video_call_api.dart \
  --java_package "com.cacianokroth.vonage_videocall" \
  --kotlin_out  android/src/main/kotlin/com/cacianokroth/vonage_video_call/VonageVideoCall.kt \
  --swift_out ios/Classes/VonageVideoCall.g.swift