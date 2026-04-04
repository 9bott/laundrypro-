// Values from android/app/google-services.json (project point-pro-326bc).
// Regenerate with FlutterFire CLI if the Firebase app changes.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web — add web in Firebase console and regenerate.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
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
}
