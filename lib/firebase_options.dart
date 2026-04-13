import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjTBilLfos6X02NlwSxlBtHFU-jRh7xek',
    appId: '1:183334770022:android:668af1d098f3093a8ea4a7',
    messagingSenderId: '183334770022',
    projectId: 'point-pro-326bc',
    storageBucket: 'point-pro-326bc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA3J3IhE3mHJfDydA6hzDNn4-L5rvLj-ns',
    appId: '1:183334770022:ios:888e72c7a5e94ecc8ea4a7',
    messagingSenderId: '183334770022',
    projectId: 'point-pro-326bc',
    storageBucket: 'point-pro-326bc.firebasestorage.app',
    iosBundleId: 'com.laundrypro.app',
  );
}
