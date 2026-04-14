import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants/app_assets.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _enabledKey = 'biometric_enabled';

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      debugPrint('[Biometric] isAvailable error: $e');
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (e) {
      debugPrint('[Biometric] isEnabled error: $e');
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (e) {
      debugPrint('[Biometric] setEnabled error: $e');
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'استخدم البصمة أو Face ID للدخول',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('[Biometric] authenticate error: $e');
      return false;
    }
  }

  static Future<String> getBiometricLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'البصمة';
      return 'البصمة';
    } catch (e) {
      debugPrint('[Biometric] getBiometricLabel error: $e');
      return 'البصمة';
    }
  }

  /// مسار الصورة المناسب لزر الدخول الحيوي (Face ID مقابل البصمة).
  static Future<String> loginIconAssetPath() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final hasFace = types.contains(BiometricType.face) ||
          types.contains(BiometricType.iris);
      if (hasFace) return AppAssets.faceIdLoginIcon;
    } catch (e) {
      debugPrint('[Biometric] loginIconAssetPath error: $e');
      /* fallback below */
    }
    return AppAssets.fingerprintLoginIcon;
  }
}
