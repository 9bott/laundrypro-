import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Centralised runtime security checks (root/jailbreak, screenshot prevention).
abstract final class AppSecurityService {
  static final _noScreenshot = NoScreenshot.instance;
  static bool _screenshotPrevented = false;

  /// Returns `true` when the device is rooted (Android) or jailbroken (iOS).
  /// Always returns `false` on web or in debug builds (so emulator testing works).
  static Future<bool> isDeviceCompromised() async {
    if (kIsWeb || kDebugMode) return false;
    try {
      return await JailbreakRootDetection.instance.isJailBroken;
    } catch (e) {
      debugPrint('[Security] jailbreak check failed: $e');
      return false;
    }
  }

  /// Prevents screenshots / screen recording on the current screen.
  static Future<void> enableScreenshotPrevention() async {
    if (kIsWeb || _screenshotPrevented) return;
    try {
      await _noScreenshot.screenshotOff();
      _screenshotPrevented = true;
    } catch (e) {
      debugPrint('[Security] screenshotOff failed: $e');
    }
  }

  /// Re-allows screenshots (call when leaving sensitive screens).
  static Future<void> disableScreenshotPrevention() async {
    if (kIsWeb || !_screenshotPrevented) return;
    try {
      await _noScreenshot.screenshotOn();
      _screenshotPrevented = false;
    } catch (e) {
      debugPrint('[Security] screenshotOn failed: $e');
    }
  }
}
