import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tsbd_app/services/language_service.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String translate(String key) {
    final languageCode = locale.languageCode;

    if (LanguageService.translations.containsKey(languageCode) &&
        LanguageService.translations[languageCode]!.containsKey(key)) {
      return LanguageService.translations[languageCode]![key]!;
    }

    // Fallback to English
    if (LanguageService.translations[LanguageService.englishCode]!.containsKey(
      key,
    )) {
      return LanguageService.translations[LanguageService.englishCode]![key]!;
    }

    // Return the key if no translation is found
    return key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'bn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
