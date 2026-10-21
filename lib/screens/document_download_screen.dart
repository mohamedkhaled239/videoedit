import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../providers/document_download_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_colors.dart';
import '../widgets/studio_brand.dart';

/// Downloads direct, authorized file URLs. Platform pages and protected streams
/// are not treated as direct media files.
class DocumentDownloadScreen extends StatefulWidget {
  const DocumentDownloadScreen({super.key, this.activateAds = false});

  // Only keep the banner alive while this tab is visible.
  final bool activateAds;

  @override
  State<DocumentDownloadScreen> createState() => _DocumentDownloadScreenState();
}

class _DocumentDownloadScreenState extends State<DocumentDownloadScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _isDownloading = false;
  BannerAd? _bannerAd;
  bool _bannerReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.activateAds) _loadBanner();
  }

  @override
  void didUpdateWidget(covariant DocumentDownloadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activateAds && !oldWidget.activateAds) {
      _loadBanner();
    } else if (!widget.activateAds && oldWidget.activateAds) {
      _disposeBanner();
    }
  }

  Future<void> _loadBanner() async {
    if (_bannerAd != null) return;
    await AdService.initialize();
    if (!mounted || !widget.activateAds || !AdService.canLoadAds) return;

    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted || !widget.activateAds) {
            ad.dispose();
            return;
          }
          setState(() => _bannerReady = true);
        },
        onAdFailedToLoad: (_, error) {
          debugPrint('File manager banner failed: ${error.message}');
          ad.dispose();
          if (identical(_bannerAd, ad)) _bannerAd = null;
        },
      ),
    );
    _bannerAd = ad;
    await ad.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerReady = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    _urlController.text = value;
    setState(() {});
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _focusNode.unfocus();
    setState(() => _isDownloading = true);
    AdService.showInterstitialAd(
      onAdDismissed: () {
        if (mounted) unawaited(_downloadValidatedFile());
      },
    );
  }

  Future<void> _downloadValidatedFile() async {
    final provider = context.read<DocumentDownloadProvider>();
    try {
      final downloaded = await provider.downloadDocument(
        _urlController.text.trim(),
      );
      if (!mounted) return;
      if (downloaded == null) {
        _showMessage(
          provider.errorMessage ?? 'تعذّر تحميل الملف. حاول مرة أخرى.',
          error: true,
        );
        return;
      }

      final message = switch (downloaded.kind) {
        DownloadedFileKind.video when downloaded.savedToPhotos =>
          'تم حفظ ${downloaded.fileName} وإضافته إلى Photos.',
        DownloadedFileKind.video =>
          'تم حفظ ${downloaded.fileName} داخل التطبيق، لكن تعذّرت إضافته إلى Photos.',
        _ => 'تم حفظ ${downloaded.fileName} بنجاح.',
      };
      _showMessage(
        message,
        error:
            downloaded.kind == DownloadedFileKind.video &&
            !downloaded.savedToPhotos,
      );
      _urlController.clear();
      setState(() {});
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openDownloadedFile() async {
    final path = context.read<DocumentDownloadProvider>().downloadedFilePath;
    if (path == null) return;
    await OpenFile.open(path);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentDownloadProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 32 : 20,
                  18,
                  isTablet ? 32 : 20,
                  124,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 760 : 610),
                    child: Column(
                      children: [
                        const StudioAppBar(
                          icon: Icons.download_for_offline_outlined,
                        ),
                        const SizedBox(height: 24),
                        // const _DownloadStatus(),
                        const SizedBox(height: 18),
                        const Text(
                          'تنزيل الملفات بسهولة وأمان',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'الصق رابطًا مباشرًا لملف مستند لحفظه على جهازك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildDownloadCard(provider),
                        if (_bannerReady && _bannerAd != null) ...[
                          const SizedBox(height: 18),
                          SizedBox(
                            width: _bannerAd!.size.width.toDouble(),
                            height: _bannerAd!.size.height.toDouble(),
                            child: AdWidget(ad: _bannerAd!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadCard(DocumentDownloadProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الرابط المباشر للملف',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            TextFormField(
              controller: _urlController,
              focusNode: _focusNode,
              enabled: !_isDownloading,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final uri = Uri.tryParse(value?.trim() ?? '');
                if (value == null || value.trim().isEmpty) {
                  return 'ألصق رابط الملف أولًا';
                }
                if (uri == null ||
                    !const {'http', 'https'}.contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  return 'أدخل رابطًا مباشرًا وصحيحًا للملف';
                }
                return null;
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://example.com/video.mp4',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                suffixIcon: IconButton(
                  tooltip: 'لصق',
                  onPressed: _isDownloading ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isDownloading ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_go_outlined),
              label: const Text('لصق من الحافظة'),
            ),
            const SizedBox(height: 18),
            if (_isDownloading) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: provider.downloadProgress == 0
                    ? null
                    : provider.downloadProgress,
              ),
              const SizedBox(height: 8),
              Text(
                'جاري التنزيل ${provider.downloadProgress > 0 ? '${(provider.downloadProgress * 100).round()}%' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            MintButton(
              label: _isDownloading ? 'جاري تنزيل الملف' : 'تنزيل الملف',
              icon: Icons.download_for_offline_outlined,
              onPressed: _startDownload,
              busy: _isDownloading,
            ),
            if (provider.downloadedFilePath != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _openDownloadedFile,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح آخر ملف تم تنزيله'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: error ? AppColors.error : AppColors.primaryDark,
      ),
    );
  }
}
