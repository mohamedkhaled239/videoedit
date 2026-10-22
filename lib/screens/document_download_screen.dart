import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../models/resolved_media.dart';
import '../providers/document_download_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_colors.dart';
import '../utils/native_ad_factory.dart';
import '../widgets/studio_brand.dart';

/// Downloads direct files and resolves supported social links through RapidAPI.
class DocumentDownloadScreen extends StatefulWidget {
  const DocumentDownloadScreen({super.key, this.activateAds = false});

  // Only keep the embedded ad alive while this tab is visible.
  final bool activateAds;

  @override
  State<DocumentDownloadScreen> createState() => _DocumentDownloadScreenState();
}

class _DocumentDownloadScreenState extends State<DocumentDownloadScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _isDownloading = false;
  NativeAd? _nativeAd;
  bool _nativeAdReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.activateAds) _loadNativeAd();
  }

  @override
  void didUpdateWidget(covariant DocumentDownloadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activateAds && !oldWidget.activateAds) {
      _loadNativeAd();
    } else if (!widget.activateAds && oldWidget.activateAds) {
      _disposeNativeAd();
    }
  }

  Future<void> _loadNativeAd() async {
    if (_nativeAd != null) return;
    await AdService.initialize();
    if (!mounted || !widget.activateAds || !AdService.canLoadAds) return;

    late final NativeAd ad;
    ad = NativeAdHelper.createNativeAd(
      adUnitId: AdService.nativeAdUnitId,
      templateType: TemplateType.medium,
      onAdLoaded: (_) {
        if (!mounted || !widget.activateAds) {
          ad.dispose();
          return;
        }
        setState(() => _nativeAdReady = true);
      },
      onAdFailedToLoad: (_, error) {
        debugPrint('Video downloader native ad failed: ${error.message}');
        ad.dispose();
        if (identical(_nativeAd, ad)) _nativeAd = null;
      },
    );
    _nativeAd = ad;
    await ad.load();
  }

  void _disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _nativeAdReady = false;
  }

  @override
  void dispose() {
    _disposeNativeAd();
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
        if (mounted) unawaited(_resolveAndChooseMedia());
      },
    );
  }

  Future<void> _resolveAndChooseMedia() async {
    if (!mounted) return;
    final provider = context.read<DocumentDownloadProvider>();
    final options = await provider.resolveMedia(_urlController.text);
    if (!mounted) return;
    if (options == null) {
      _showMessage(
        provider.errorMessage ?? 'تعذر قراءة الرابط. حاول مرة أخرى.',
        error: true,
      );
      setState(() => _isDownloading = false);
      return;
    }

    final selected = options.length == 1
        ? options.first
        : await _chooseMedia(options);
    if (!mounted) return;
    if (selected == null) {
      setState(() => _isDownloading = false);
      return;
    }
    unawaited(_downloadValidatedFile(selected));
  }

  Future<ResolvedMedia?> _chooseMedia(List<ResolvedMedia> options) {
    return showModalBottomSheet<ResolvedMedia>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر الجودة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (options.first.thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    options.first.thumbnail.toString(),
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              if (options.first.thumbnail != null) const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ListTile(
                      leading: Icon(
                        option.kind == 'audio'
                            ? Icons.audio_file_outlined
                            : Icons.video_file_outlined,
                      ),
                      title: Text(option.label),
                      subtitle: option.fileExtension == null
                          ? null
                          : Text(option.fileExtension!.toUpperCase()),
                      trailing: const Icon(Icons.download_rounded),
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadValidatedFile(ResolvedMedia media) async {
    final provider = context.read<DocumentDownloadProvider>();
    try {
      final downloaded = await provider.downloadDocument(
        media.url.toString(),
        preferredExtension: media.fileExtension,
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
        DownloadedFileKind.image when downloaded.savedToPhotos =>
          'تم حفظ ${downloaded.fileName} وإضافته إلى Photos.',
        DownloadedFileKind.image =>
          'تم حفظ ${downloaded.fileName} داخل التطبيق، لكن تعذّرت إضافته إلى Photos.',
        _ => 'تم حفظ ${downloaded.fileName} بنجاح.',
      };
      _showMessage(
        message,
        error:
            (downloaded.kind == DownloadedFileKind.video ||
                downloaded.kind == DownloadedFileKind.image) &&
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
                  6,
                  isTablet ? 32 : 20,
                  124,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 760 : 610),
                    child: Column(
                      children: [
                        _buildDownloadCard(provider),
                        if (_nativeAdReady && _nativeAd != null) ...[
                          const SizedBox(height: 18),
                          NativeAdWidget(
                            nativeAd: _nativeAd!,
                            height: 320,
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
              'رابط الفيديو أو المنشور',
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
                if (value == null || value.trim().isEmpty) {
                  return 'ألصق رابط الفيديو أولًا';
                }
                if (provider.extractUrl(value) == null) {
                  return 'أدخل رابطًا صحيحًا أو نصًا يحتوي على رابط';
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
              label: provider.isResolving
                  ? 'جاري قراءة الرابط'
                  : _isDownloading
                  ? 'جاري تنزيل الفيديو'
                  : 'تنزيل الفيديو',
              icon: Icons.download_for_offline_outlined,
              onPressed: _startDownload,
              busy: _isDownloading,
            ),
            if (provider.downloadedFilePath != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _openDownloadedFile,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح آخر فيديو تم تنزيله'),
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
