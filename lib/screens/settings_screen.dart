import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Notification test only.
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:videoedit/utils/app_colors.dart';
import 'package:videoedit/widgets/custom_app_bar.dart';
import 'package:videoedit/l10n/app_localizations.dart';
import 'package:videoedit/providers/locale_provider.dart';
import 'package:videoedit/screens/fcm_diagnostics_screen.dart';
// import 'package:videoedit/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _supportUrl = 'https://3reeb.com';
  static const _marketingUrl = 'https://3reeb.com/app-ads.txt';

  /* Disabled for production. Keep this helper commented so it can be restored
     during internal QA without exposing notification diagnostics to users.
  Future<void> _testNotifications() async {
    final service = NotificationService();
    final localNotificationShown = await service.showTestNotification();
    final token = service.token ?? await service.refreshToken(maxAttempts: 1);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختبار الإشعارات', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              localNotificationShown
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: localNotificationShown ? AppColors.primary : Colors.red,
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              localNotificationShown
                  ? 'تم عرض إشعار الاختبار المحلي بنجاح.'
                  : 'تعذّر عرض الإشعار المحلي. راجع إذن الإشعارات.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              token != null
                  ? 'Firebase Messaging متصل والتوكن جاهز.'
                  : 'الإشعار المحلي يعمل، لكن FCM token غير متاح حاليًا.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (token != null)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('نسخ FCM token'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
  */

  void _showLanguageDialog() {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.chooseLanguage,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _languageOption(
                AppLocalizations.of(context)!.arabic,
                localeProvider,
              ),
              const SizedBox(height: 8),
              _languageOption(
                AppLocalizations.of(context)!.english,
                localeProvider,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _languageOption(String language, LocaleProvider localeProvider) {
    final isSelected = localeProvider.currentLanguageName == language;

    return GestureDetector(
      onTap: () async {
        await localeProvider.setLocaleByName(language);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.languageChangedTo(language),
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: .2)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              language,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.reportProblem,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.describeProblem),
              const SizedBox(height: 12),
              TextField(
                controller: reportController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.writeProblemDetails,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (reportController.text.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.thankYouForReporting,
                      ),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                  reportController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                AppLocalizations.of(context)!.send,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFAQDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.frequentlyAskedQuestions,
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _faqItem(
                  AppLocalizations.of(context)!.howToTrimVideo,
                  AppLocalizations.of(context)!.trimVideoDescription,
                ),
                const SizedBox(height: 12),
                _faqItem(
                  AppLocalizations.of(context)!.howToMergeVideos,
                  AppLocalizations.of(context)!.mergeVideosDescription,
                ),
                const SizedBox(height: 12),
                _faqItem(
                  AppLocalizations.of(context)!.howToSaveVideo,
                  AppLocalizations.of(context)!.saveVideoDescription,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        );
      },
    );
  }

  Widget _faqItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          answer,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.privacyPolicy,
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policySection(
                  AppLocalizations.of(context)!.dataProtection,
                  AppLocalizations.of(context)!.dataProtectionDescription,
                ),
                const SizedBox(height: 12),
                _policySection(
                  AppLocalizations.of(context)!.dataUsage,
                  AppLocalizations.of(context)!.dataUsageDescription,
                ),
                const SizedBox(height: 12),
                _policySection(
                  AppLocalizations.of(context)!.temporaryFiles,
                  AppLocalizations.of(context)!.temporaryFilesDescription,
                ),
                const SizedBox(height: 12),
                _policySection(
                  AppLocalizations.of(context)!.updates,
                  AppLocalizations.of(context)!.updatesDescription,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.agree),
            ),
          ],
        );
      },
    );
  }

  void _showCopyrightsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.copyrights,
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _copyrightSection(
                  AppLocalizations.of(context)!.appCopyright,
                  AppLocalizations.of(context)!.allRightsReserved,
                ),
                const SizedBox(height: 12),
                _copyrightSection(
                  AppLocalizations.of(context)!.license,
                  AppLocalizations.of(context)!.licenseDescription,
                ),
                const SizedBox(height: 12),
                _copyrightSection(
                  AppLocalizations.of(context)!.usedLibraries,
                  AppLocalizations.of(context)!.usedLibrariesDescription,
                ),
                const SizedBox(height: 12),
                _copyrightSection(
                  AppLocalizations.of(context)!.personalUse,
                  AppLocalizations.of(context)!.personalUseDescription,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
  }

  Widget _policySection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _copyrightSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.contactUsTitle,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _contactMethod(
                Icons.email,
                AppLocalizations.of(context)!.email,
                AppLocalizations.of(context)!.emailAddress,
              ),
              const SizedBox(height: 12),
              _contactMethod(
                Icons.language,
                AppLocalizations.of(context)!.website,
                AppLocalizations.of(context)!.websiteUrl,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEmail(String email) async {
    final gmailUrl = Uri.parse(
      'googlegmail://co?to=$email&subject=${Uri.encodeComponent('تواصل من تطبيق Alzeeb')}',
    );

    final mailtoUrl = Uri.parse('mailto:$email');

    final gmailWebUrl = Uri.parse(
      'https://mail.google.com/mail/?view=cm&to=$email&su=${Uri.encodeComponent('تواصل من تطبيق Alzeeb')}',
    );

    try {
      if (await canLaunchUrl(gmailUrl)) {
        await launchUrl(gmailUrl);
        return;
      }

      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl);
        return;
      }

      if (await canLaunchUrl(gmailWebUrl)) {
        await launchUrl(gmailWebUrl, mode: LaunchMode.externalApplication);
        return;
      }

      _showContactErrorSnackbar();
    } catch (e) {
      _showContactErrorSnackbar();
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showContactErrorSnackbar();
      }
    } catch (e) {
      _showContactErrorSnackbar();
    }
  }

  void _showContactErrorSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotOpenLink),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _contactMethod(IconData icon, String title, String value) {
    return GestureDetector(
      onTap: () async {
        if (value.contains('@')) {
          await _openEmail(value);
        } else if (value.startsWith('http')) {
          await _openUrl(value);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Icon(Icons.open_in_new, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CustomAppBar(
            isBack: false,
            title: AppLocalizations.of(context)!.settings,
          ),

          const SizedBox(height: 20),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                /* Internal notification diagnostic intentionally hidden in
                   production builds.
                SettingsItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'اختبار الإشعارات',
                  onTap: _testNotifications,
                ),
                */
                SettingsItem(
                  icon: Icons.language,
                  title: AppLocalizations.of(context)!.language,
                  onTap: _showLanguageDialog,
                ),
                SettingsItem(
                  icon: Icons.bug_report_outlined,
                  title: 'تشخيص إشعارات FCM',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FcmDiagnosticsScreen(),
                      ),
                    );
                  },
                ),
                SettingsItem(
                  icon: Icons.report_problem_outlined,
                  title: AppLocalizations.of(context)!.reportAProblem,
                  onTap: _showReportDialog,
                ),
                SettingsItem(
                  icon: Icons.help_outline,
                  title: AppLocalizations.of(context)!.faq,
                  onTap: _showFAQDialog,
                ),
                SettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: AppLocalizations.of(context)!.privacyPolicyTitle,
                  onTap: _showPrivacyDialog,
                ),
                SettingsItem(
                  icon: Icons.support_agent_outlined,
                  title: AppLocalizations.of(context)!.supportUrl,
                  subtitle: _supportUrl,
                  onTap: () => _openUrl(_supportUrl),
                ),
                SettingsItem(
                  icon: Icons.campaign_outlined,
                  title: AppLocalizations.of(context)!.marketingUrl,
                  subtitle: _marketingUrl,
                  onTap: () => _openUrl(_marketingUrl),
                ),
                SettingsItem(
                  icon: Icons.copyright_outlined,
                  title: AppLocalizations.of(context)!.copyrights,
                  onTap: _showCopyrightsDialog,
                ),
                SettingsItem(
                  icon: Icons.phone_outlined,
                  title: AppLocalizations.of(context)!.contactUs,
                  onTap: _showContactDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null && subtitle != null)
              const Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
