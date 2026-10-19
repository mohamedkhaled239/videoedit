import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../providers/app_config_provider.dart';
import '../providers/document_download_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_colors.dart';
import '../widgets/studio_brand.dart';

class DocumentDownloadScreen extends StatefulWidget {
  const DocumentDownloadScreen({super.key, this.activateAds = false});

  final bool activateAds;

  @override
  State<DocumentDownloadScreen> createState() => _DocumentDownloadScreenState();
}

class _DocumentDownloadScreenState extends State<DocumentDownloadScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.activateAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAds());
    }
  }

  @override
  void didUpdateWidget(covariant DocumentDownloadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activateAds && !oldWidget.activateAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAds());
    }
  }

  Future<void> _initializeAds() async {
    if (!mounted) return;
    final enabled = context.read<AppConfigProvider>().config.enableAds;
    AdService.setAdsEnabled(enabled);
    if (!enabled) return;
    await AdService.initialize();
    if (!mounted) return;
    AdService.loadInterstitialAd();
    AdService.loadAppOpenAd();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value != null && value.isNotEmpty) {
      _urlController.text = value;
      setState(() {});
    }
  }

  Future<void> _startDownload() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _focusNode.unfocus();
    setState(() => _isDownloading = true);
    AdService.showInterstitialAd(onAdDismissed: _downloadDocument);
  }

  Future<void> _downloadDocument() async {
    final provider = context.read<DocumentDownloadProvider>();
    try {
      final document = await provider.downloadDocument(
        _urlController.text.trim(),
      );
      if (!mounted) return;

      if (document == null) {
        _showMessage(
          provider.errorMessage ?? 'تعذّر تحميل الملف. حاول مرة أخرى.',
          error: true,
        );
        return;
      }

      await OpenFile.open(document.path);
      if (!mounted) return;
      _showMessage('تم تحميل ${document.fileName} وحفظه بنجاح.');
      _urlController.clear();
      provider.reset();
      setState(() {});
    } catch (error, stackTrace) {
      debugPrint('Document flow failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('تعذّر تحميل الملف. حاول مرة أخرى.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 32 : 20,
                  isTablet ? 24 : 18,
                  isTablet ? 32 : 20,
                  124,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 760 : 610),
                    child: Column(
                      children: [
                        const StudioAppBar(icon: Icons.folder_copy_outlined),
                        const SizedBox(height: 18),
                        _buildStatus(),
                        const SizedBox(height: 19),
                        const Text(
                          'تنزيل الملفات بسهولة وأمان',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'الصق رابطًا مباشرًا لمستند أو ملف مضغوط لحفظه على جهازك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 27),
                        _buildDownloadCard(),
                        _AdaptiveBannerSlot(
                          enabled: context
                              .watch<AppConfigProvider>()
                              .config
                              .enableAds,
                        ),
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

  Widget _buildStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: AppColors.primary,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'تنزيل المستندات والملفات المدعومة',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard() {
    final provider = context.watch<DocumentDownloadProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFF202733)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.link_rounded, color: AppColors.primary, size: 19),
                SizedBox(width: 6),
                Text(
                  'الرابط المباشر للملف',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'https://example.com/document.pdf',
                hintStyle: const TextStyle(
                  color: Color(0xFF7D8691),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFF090E16),
                prefixIcon: IconButton(
                  tooltip: 'مسح',
                  onPressed: _urlController.text.isEmpty
                      ? null
                      : () {
                          _urlController.clear();
                          setState(() {});
                        },
                  icon: const Icon(Icons.close_rounded, size: 21),
                ),
                suffixIcon: IconButton(
                  tooltip: 'لصق',
                  onPressed: _isDownloading ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_outlined, size: 21),
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
                errorStyle: const TextStyle(
                  color: Color(0xFFFF8879),
                  fontWeight: FontWeight.w600,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 17,
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isDownloading ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_go_outlined, size: 21),
              label: const Text('لصق من الحافظة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surfaceLight,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'أنواع الملفات المدعومة',
              style: TextStyle(
                color: Color(0xFF87908F),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _FileTypeChip(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                ),
                _FileTypeChip(label: 'Word', icon: Icons.description_outlined),
                _FileTypeChip(label: 'Text', icon: Icons.text_snippet_outlined),
                _FileTypeChip(label: 'Excel', icon: Icons.table_chart_outlined),
                _FileTypeChip(
                  label: 'PowerPoint',
                  icon: Icons.slideshow_outlined,
                ),
                _FileTypeChip(label: 'ZIP', icon: Icons.folder_zip_outlined),
              ],
            ),
            const SizedBox(height: 18),
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: provider.downloadProgress == 0
                      ? null
                      : provider.downloadProgress,
                  minHeight: 5,
                  color: AppColors.primary,
                  backgroundColor: AppColors.outline,
                ),
              ),
              const SizedBox(height: 10),
            ],
            MintButton(
              label: _isDownloading
                  ? 'جاري تنزيل الملف ${provider.downloadProgress > 0 ? '${(provider.downloadProgress * 100).round()}%' : ''}'
                  : 'تنزيل الملف',
              icon: Icons.download_for_offline_outlined,
              onPressed: _startDownload,
              busy: _isDownloading,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: error
            ? const Color(0xFFB84949)
            : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}

class _AdaptiveBannerSlot extends StatefulWidget {
  const _AdaptiveBannerSlot({required this.enabled});

  final bool enabled;

  @override
  State<_AdaptiveBannerSlot> createState() => _AdaptiveBannerSlotState();
}

class _AdaptiveBannerSlotState extends State<_AdaptiveBannerSlot> {
  BannerAd? _bannerAd;
  AdSize? _bannerSize;
  int? _requestedWidth;
  bool _loadScheduled = false;
  bool _isLoaded = false;

  @override
  void didUpdateWidget(covariant _AdaptiveBannerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _disposeBanner();
    } else if (!oldWidget.enabled && widget.enabled) {
      _requestedWidth = null;
    }
  }

  void _scheduleLoad(int width) {
    if (_loadScheduled || !widget.enabled || width <= 0) return;
    if (_requestedWidth == width && _bannerAd != null) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) _loadBanner(width);
    });
  }

  Future<void> _loadBanner(int width) async {
    _requestedWidth = width;
    await AdService.initialize();
    if (!mounted || !widget.enabled || !AdService.canLoadAds) return;
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null || _requestedWidth != width) return;

    _disposeBanner(keepRequestedWidth: true);
    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted || !identical(_bannerAd, loadedAd)) {
            loadedAd.dispose();
            return;
          }
          setState(() {
            _bannerSize = size;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Banner failed to load: ${error.message}');
          failedAd.dispose();
          if (mounted && identical(_bannerAd, failedAd)) {
            setState(() {
              _bannerAd = null;
              _bannerSize = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd = ad;
    await ad.load();
  }

  void _disposeBanner({bool keepRequestedWidth = false}) {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerSize = null;
    _isLoaded = false;
    if (!keepRequestedWidth) _requestedWidth = null;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.floor();
        if (widget.enabled && width != _requestedWidth) _scheduleLoad(width);

        final ad = _bannerAd;
        final size = _bannerSize;
        if (!widget.enabled || !_isLoaded || ad == null || size == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Center(
            child: SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}

class _FileTypeChip extends StatelessWidget {
  const _FileTypeChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF123B32),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
