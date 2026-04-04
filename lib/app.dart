import 'package:flutter/material.dart';
import 'package:laundrypro/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/locale/app_locale_controller.dart';
import 'core/router/app_router.dart';
import 'features/staff/presentation/providers/staff_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/offline_pending_provider.dart';
import 'shared/widgets/animated_bg.dart';
import 'l10n.dart';

/// Root application widget — Material 3, RTL-ready, router-driven.
class LaundryProApp extends ConsumerStatefulWidget {
  const LaundryProApp({super.key});

  @override
  ConsumerState<LaundryProApp> createState() => _LaundryProAppState();
}

class _LaundryProAppState extends ConsumerState<LaundryProApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(localeProvider.notifier).loadSaved();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Env.hasSupabase) {
      Future.microtask(() async {
        await ref.read(staffOfflineSyncProvider).processAll();
        bumpOfflinePendingBadge(ref);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appName ?? 'Point',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      locale: locale,
      supportedLocales: laundryProSupportedLocales,
      localizationsDelegates: laundryProLocalizationDelegates,
      routerConfig: router,
      builder: (context, child) {
        final rtl = locale.languageCode == 'ar';
        return Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: AnimatedBackground(
            extraOrbs: true,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
