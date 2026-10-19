// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Document Downloader & Video Editor';

  @override
  String get pasteLinkHint =>
      'Paste a direct document link to save it on your device';

  @override
  String get urlHint => 'https://example.com/document.pdf';

  @override
  String get paste => 'Paste';

  @override
  String get downloadFile => 'Download File';

  @override
  String get enterFileUrl => 'Please enter the direct file URL';

  @override
  String get enterValidUrl => 'Please enter a valid URL';

  @override
  String get status => 'Status';

  @override
  String get downloading => 'Downloading';

  @override
  String get fetchingInfo => 'Fetching information';

  @override
  String get saving => 'Saving';

  @override
  String get processing => 'Processing';

  @override
  String get downloadSuccess => 'File downloaded successfully ✓';

  @override
  String get unsupportedFile => 'This file type is not supported';

  @override
  String get downloadFailed => 'Failed to download file';

  @override
  String get saveFailed => 'Failed to save file';

  @override
  String errorOccurred(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get albumName => 'Video Editing App';

  String get arabic => 'Arabic';
  String get english => 'English';
  String get chooseLanguage => 'Choose Language';
  String get cancel => 'Cancel';
  String languageChangedTo(String language) => 'Language changed to $language';
  String get reportProblem => 'Report a Problem';
  String get describeProblem => 'Describe the problem you are facing:';
  String get writeProblemDetails => 'Write the problem details here...';
  String get send => 'Send';
  String get thankYouForReporting =>
      'Thank you for reporting! Your issue will be reviewed soon.';
  String get frequentlyAskedQuestions => 'Frequently Asked Questions';
  String get howToTrimVideo => 'How do I trim a video?';
  String get trimVideoDescription =>
      'Select a video from the main page, then click on the "Trim Video" tool';
  String get howToMergeVideos => 'How do I merge multiple videos?';
  String get mergeVideosDescription =>
      'Use the "Merge Videos" tool and select several videos';
  String get howToSaveVideo => 'How do I save the edited video?';
  String get saveVideoDescription =>
      'After editing, click on "Save to Gallery"';
  String get close => 'Close';
  String get privacyPolicy => 'Privacy Policy';
  String get dataProtection => 'Data Protection';
  String get dataProtectionDescription =>
      'We are committed to protecting our users\' data with the highest levels of security and encryption.';
  String get dataUsage => 'Data Usage';
  String get dataUsageDescription =>
      'We do not share user data with third parties without explicit consent.';
  String get temporaryFiles => 'Temporary Files';
  String get temporaryFilesDescription =>
      'Temporary files are automatically deleted after you finish using the app.';
  String get updates => 'Updates';
  String get updatesDescription =>
      'We may update this policy from time to time. Please review it regularly.';
  String get agree => 'Agree';
  String get copyrights => 'Copyrights';
  String get appCopyright => '© 2026 Video Editing App';
  String get allRightsReserved => 'All rights reserved';
  String get license => 'License';
  String get licenseDescription =>
      'This app is licensed under the MIT license. You can use it according to the license terms.';
  String get usedLibraries => 'Used Libraries';
  String get usedLibrariesDescription =>
      'The app uses several open-source libraries. We thank all contributors.';
  String get personalUse => 'Personal Use';
  String get personalUseDescription =>
      'You can use this app for personal and commercial purposes.';
  String get ok => 'OK';
  String get contactUs => 'Contact Us';
  String get email => 'Email';
  String get emailAddress => 'mojz.mna@gmail.com';
  String get phone => 'Phone';
  String get phoneNumber => '+966 50 123 4567';
  String get website => 'X';
  String get websiteUrl => 'https://x.com/ln_95n';
  String get settings => 'Settings';
  String get language => 'Language';
  String get reportAProblem => 'Report a Problem';
  String get faq => 'FAQ';
  String get privacyPolicyTitle => 'Privacy Policy';
  String get contactUsTitle => 'Contact Us';
  String get cannotOpenLink => 'Cannot open link';
  String get linkCopied => 'Link Copied!';
  String get tapToPaste => 'Tap to paste the link';

  String get downloadFileNavBar => 'Download File';

  String get editVideoNavBar => 'Edit Video';
}
