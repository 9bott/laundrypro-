import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'core/config/env.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/utils/offline_queue.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] step 1: Flutter binding OK');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    debugPrint('[BOOT] step 2: Firebase OK');
  } catch (e) {
    debugPrint('[BOOT] step 2 FAILED: $e');
  }

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await FirebaseAuth.instance.setSettings(forceRecaptchaFlow: false);
    } catch (e) {
      debugPrint('[Firebase Auth] Android setSettings: $e');
    }
  }

  if (!kIsWeb && Platform.isIOS) {
    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      debugPrint('[Firebase Auth] iOS: verification disabled for testing');
    } catch (e) {
      debugPrint('[Firebase Auth] iOS setSettings: $e');
    }
  }

  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[CRASH] Flutter error: ${details.exception}');
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[CRASH] Platform error: $error');
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('[BOOT] step 3: Crashlytics OK');
  } catch (e) {
    debugPrint('[BOOT] step 3 FAILED: $e');
  }

  try {
    await Hive.initFlutter();
    debugPrint('[BOOT] step 4: Hive OK');
  } catch (e) {
    debugPrint('[BOOT] step 4 FAILED: $e');
  }

  try {
    if (Env.hasSupabase) {
      await SupabaseService.init(
        url: Env.supabaseUrl.trim(),
        anonKey: Env.supabaseAnonKey.trim(),
      );
      debugPrint('[BOOT] step 5: Supabase OK');
    } else {
      debugPrint('[BOOT] step 5: Supabase SKIPPED');
    }
  } catch (e) {
    debugPrint('[BOOT] step 5 FAILED: $e');
  }

  try {
    await NotificationService.initialize();
    debugPrint('[BOOT] step 6: Notifications OK');
  } catch (e) {
    debugPrint('[BOOT] step 6 FAILED: $e');
  }

  debugPrint('[BOOT] step 7: starting runApp');
  runZonedGuarded(
    () => runApp(const ProviderScope(child: LaundryProApp())),
    (error, stack) {
      debugPrint('[CRASH] Zone error: $error');
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

Future<void> _precacheSplashLogoAsset() async {
  const provider = AssetImage('assets/images/app_logo.png');
  final stream = provider.resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo image, bool synchronousCall) {
      if (!completer.isCompleted) completer.complete();
    },
    onError: (Object exception, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    },
  );
  stream.addListener(listener);
  try {
    await completer.future;
  } finally {
    stream.removeListener(listener);
  }
}
