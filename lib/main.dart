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
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[Firebase] skipped: $e');
  }

  if (!kIsWeb) {
    try {
      // Force enable in all modes for debugging
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Test that Crashlytics is working
      await FirebaseCrashlytics.instance
          .log('Crashlytics initialized successfully');
      await FirebaseCrashlytics.instance.setCustomKey('platform', 'ios');
      await FirebaseCrashlytics.instance.setCustomKey('build', '14');

      FlutterError.onError = (FlutterErrorDetails details) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('[Crashlytics] error: $e');
    }
  }

  await Hive.initFlutter();

  if (Env.hasSupabase) {
    final url = Env.supabaseUrl.trim();
    final key = Env.supabaseAnonKey.trim();
    debugPrint('[Supabase] hasSupabase=true url="$url" keyLen=${key.length}');
    await SupabaseService.init(
      url: url,
      anonKey: key,
    );
  } else {
    debugPrint('[Supabase] hasSupabase=false SUPABASE_URL/SUPABASE_ANON_KEY missing');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('[Firebase] skipped: $e');
  }

  // TEMPORARY: Remove after confirming Crashlytics works
  FirebaseCrashlytics.instance.crash();

  runZonedGuarded(
    () => runApp(const ProviderScope(child: LaundryProApp())),
    (error, stack) {
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
