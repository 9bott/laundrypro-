import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLocalePrefKey = 'locale';

/// Supported app languages (must match [AppLocalizations.supportedLocales]).
const Set<String> kSupportedLanguageCodes = {'ar', 'en', 'bn'};

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  void setLocale(Locale locale) {
    final code = locale.languageCode;
    if (!kSupportedLanguageCodes.contains(code)) return;
    state = Locale(code);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(kLocalePrefKey, code),
    );
  }

  /// Loads saved preference, or falls back to device locale if supported, else Arabic.
  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kLocalePrefKey);
    if (saved != null && kSupportedLanguageCodes.contains(saved)) {
      state = Locale(saved);
      return;
    }
    final platform =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    if (kSupportedLanguageCodes.contains(platform)) {
      state = Locale(platform);
      return;
    }
    state = const Locale('ar');
  }
}
