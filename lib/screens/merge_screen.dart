import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../providers/video_editor_provider.dart';
import '../utils/app_colors.dart';
import '../utils/export_sharing.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/studio_brand.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, required this.mainVideoPath});

  final String mainVideoPath;

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<String> _selectedVideos = [];
  bool _isPicking = false;
  bool _isProcessing = false;

  Future<void> _pickVideos() async {
    if (_isPicking || _isProcessing) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      if (result == null || !mounted) return;

      final validPaths = <String>[];
      var skippedFiles = 0;
      for (final path in result.paths.whereType<String>()) {
        final file = File(path);
        if (path == widget.mainVideoPath || _selectedVideos.contains(path)) {
          continue;
        }
        if (await file.exists() && await file.length() > 0) {
          validPaths.add(path);
        } else {
          skippedFiles++;
        }
      }

      if (!mounted) return;
      setState(() => _selectedVideos.addAll(validPaths));
      if (skippedFiles > 0) {
        _showMessage('تم تجاهل بعض الملفات غير الصالحة.', error: true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('تعذّر اختيار المقاطع. حاول مرة أخرى.', error: true);
      }
      debugPrint('Video picker failed: $error');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _mergeVideos() async {
    if (_selectedVideos.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);

    final provider = context.read<VideoEditorProvider>();
    final result = await provider.mergeVideos(
      widget.mainVideoPath,
      List<String>.unmodifiable(_selectedVideos),
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result == null) {
      _showMessage(
        provider.errorMessage ?? 'تعذّر دمج المقاطع. حاول مرة أخرى.',
        error: true,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      exportedVideoSnackBar(
        context,
        result,
        message: 'تم دمج المقاطع وحفظ الفيديو بنجاح.',
      ),
    );
    // Remain on the completion state so the Share action is usable.
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: error
            ? const Color(0xFFB84949)
            : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<VideoEditorProvider>().exportProgress;
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const CustomAppBar(isBack: true, title: 'دمج المقاطع'),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 28 : 18,
                          18,
                          isTablet ? 28 : 18,
                          20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 16),
                            const Text(
                              'ترتيب المقاطع',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'سيتم الدمج حسب الترتيب الظاهر من أعلى لأسفل.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: _buildClipsList()),
                            const SizedBox(height: 14),
                            _buildActions(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isProcessing) _ProcessingOverlay(progress: progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F8F9), Color(0xFFFFFFFF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.video_collection_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أنشئ فيديو واحدًا متصلًا',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedVideos.length + 1} مقطع في المشروع',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipsList() {
    return ListView.separated(
      itemCount: _selectedVideos.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final isMain = index == 0;
        final path = isMain ? widget.mainVideoPath : _selectedVideos[index - 1];
        return _ClipTile(
          order: index + 1,
          fileName: p.basename(path),
          isMain: isMain,
          onRemove: isMain || _isProcessing
              ? null
              : () => setState(() => _selectedVideos.removeAt(index - 1)),
        );
      },
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isPicking || _isProcessing ? null : _pickVideos,
            icon: _isPicking
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_to_photos_outlined),
            label: Text(_isPicking ? 'جاري فتح المعرض...' : 'إضافة مقاطع'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.outline),
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        MintButton(
          label: _isProcessing ? 'جاري دمج المقاطع...' : 'دمج وحفظ الفيديو',
          icon: Icons.merge_type_rounded,
          onPressed: _selectedVideos.isEmpty || _isProcessing
              ? null
              : _mergeVideos,
          busy: _isProcessing,
          height: 54,
        ),
      ],
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.order,
    required this.fileName,
    required this.isMain,
    required this.onRemove,
  });

  final int order;
  final String fileName;
  final bool isMain;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMain
              ? AppColors.primary.withValues(alpha: .4)
              : AppColors.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMain
                  ? AppColors.primary.withValues(alpha: .14)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMain ? 'المقطع الأساسي' : 'مقطع إضافي',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (isMain)
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary)
          else
            IconButton(
              tooltip: 'إزالة المقطع',
              onPressed: onRemove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF7168),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: .82),
        child: Center(
          child: Container(
            width: 290,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.movie_filter_outlined,
                  color: AppColors.primary,
                  size: 46,
                ),
                const SizedBox(height: 16),
                const Text(
                  'جاري دمج المقاطع',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress > 0 ? '$percent%' : 'يتم تجهيز المقاطع...',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 15),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress.clamp(0.0, 1.0) : null,
                    minHeight: 7,
                    color: AppColors.primary,
                    backgroundColor: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا تغلق التطبيق حتى اكتمال الحفظ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
