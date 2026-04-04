import 'package:flutter/material.dart';
import 'package:laundrypro/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Global Material/Cupertino delegates plus generated [AppLocalizations].
List<LocalizationsDelegate<dynamic>> get laundryProLocalizationDelegates =>
    <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];

List<Locale> get laundryProSupportedLocales => AppLocalizations.supportedLocales;
