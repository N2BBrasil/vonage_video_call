import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class VonageVideoCallView extends StatelessWidget {
  const VonageVideoCallView({super.key});

  static const viewType = 'VonageVideoCallRendererView';

  static const StandardMessageCodec _decoder = StandardMessageCodec();

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: viewType,
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <Factory<
                  OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: _decoder,
              onFocus: () => params.onFocusChanged(true),
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create();
          },
        );
      case TargetPlatform.iOS:
        return const UiKitView(
          viewType: viewType,
          creationParamsCodec: _decoder,
          layoutDirection: TextDirection.ltr,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
        );
      default:
        throw UnsupportedError('Unsupported platform view');
    }
  }
}
