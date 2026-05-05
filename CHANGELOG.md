## 1.4.0

* Fix: Proper resource cleanup in endSession (camera, publisher, subscriber)
* Fix: Session invalidation after fatal errors (Android + iOS)
* Fix: Remove force unwraps preventing runtime crashes (iOS)
* Fix: Race conditions in subscriber connection flow (Android)
* Fix: State transition back to WAITING when remote participant drops
* Feat: Reconnection handling with new `reconnecting` state
* Fix: Activity lifecycle integration for camera management (Android)
* Fix: Ensure delegate callbacks run on main thread (iOS)
* Fix: Memory leaks in VideoFactory and singleton view management

## 1.3.0

* Updated Vonage Video SDK to 2.33.0 (Android and iOS)
* New publisher and subscriber statistics (video layer metrics, transport stats)
* Video freeze/pause tracking and decoding metrics for subscribers
* Video quality changed events for publishers and subscribers
* Publisher degradation preference settings
* iOS: Support for Apple silicon Macs running macOS 14+

## 1.2.0

* Updated Vonage Video SDK to 2.32.1 (Android and iOS)

## 0.0.1

* Initial release.
