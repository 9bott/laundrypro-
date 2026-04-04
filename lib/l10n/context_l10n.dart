import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

bool useArabicDigits(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';
