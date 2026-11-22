import 'package:flutter/services.dart';

/// Keeps track of which way round the app may be shown, so a screen that
/// turns the phone (the MVP picker turns it upright) can put it back the way
/// it was when it closes. Flutter can't be asked for the current setting, so
/// everything that changes it goes through here.
class ScreenOrientation {
  static const all = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const portrait = [DeviceOrientation.portraitUp];

  static List<DeviceOrientation> _current = all;

  /// What is allowed right now.
  static List<DeviceOrientation> get current => _current;

  static Future<void> set(List<DeviceOrientation> orientations) {
    _current = orientations;
    return SystemChrome.setPreferredOrientations(orientations);
  }
}
