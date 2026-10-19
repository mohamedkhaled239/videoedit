import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  String get appTitle;

  String get pasteLinkHint;

  String get urlHint;

  String get paste;

  String get downloadFile;

  String get enterFileUrl;

  String get enterValidUrl;

  String get status;

  String get downloading;

  String get fetchingInfo;

  String get saving;

  String get processing;

  String get downloadSuccess;

  String get unsupportedFile;

  String get downloadFailed;

  String get saveFailed;

  String errorOccurred(String error);

  String get albumName;

  String get arabic;
  String get english;
  String get chooseLanguage;
  String get cancel;
  String languageChangedTo(String language);
  String get reportProblem;
  String get describeProblem;
  String get writeProblemDetails;
  String get send;
  String get thankYouForReporting;
  String get frequentlyAskedQuestions;
  String get howToTrimVideo;
  String get trimVideoDescription;
  String get howToMergeVideos;
  String get mergeVideosDescription;
  String get howToSaveVideo;
  String get saveVideoDescription;
  String get close;
  String get privacyPolicy;
  String get dataProtection;
  String get dataProtectionDescription;
  String get dataUsage;
  String get dataUsageDescription;
  String get temporaryFiles;
  String get temporaryFilesDescription;
  String get updates;
  String get updatesDescription;
  String get agree;
  String get copyrights;
  String get appCopyright;
  String get allRightsReserved;
  String get license;
  String get licenseDescription;
  String get usedLibraries;
  String get usedLibrariesDescription;
  String get personalUse;
  String get personalUseDescription;
  String get ok;
  String get contactUs;
  String get email;
  String get emailAddress;
  String get phone;
  String get phoneNumber;
  String get website;
  String get websiteUrl;
  String get settings;
  String get language;
  String get reportAProblem;
  String get faq;
  String get privacyPolicyTitle;
  String get contactUsTitle;
  String get cannotOpenLink;
  String get linkCopied;
  String get tapToPaste;
  String get downloadFileNavBar;
  String get editVideoNavBar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
