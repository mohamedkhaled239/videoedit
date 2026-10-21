import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/projects_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_colors.dart';
import '../utils/export_sharing.dart';
import 'audio_mix_screen.dart';
import 'edit_screen.dart';
import 'merge_screen.dart';
import 'player_screen.dart';
import 'trim_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenDownloads,
    required this.onOpenProjects,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenProjects;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<bool> _pickVideo() async {
    if (_isPicking) return false;
    setState(() => _isPicking = true);
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null || !mounted) return false;
      final editor = context.read<VideoEditorProvider>();
      await editor.loadVideo(file.path);
      if (!mounted || editor.metadata == null) return false;
      await context.read<ProjectsProvider>().saveCurrent(
        videoPath: file.path,
        thumbnailPath: editor.thumbnailPath,
        durationMs: editor.metadata!.duration,
      );
      return true;
    } catch (error) {
      if (mounted) _showMessage('تعذّر فتح الفيديو: $error', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _runTool(String tool) async {
    final editor = context.read<VideoEditorProvider>();
    if (editor.videoPath == null && !await _pickVideo()) return;
    if (!mounted || editor.videoPath == null) return;
    final path = editor.videoPath!;
    switch (tool) {
      case 'trim':
        _open(TrimScreen(videoPath: path));
        return;
      case 'crop':
        _open(EditScreen(videoPath: path, editType: EditType.crop));
        return;
      case 'speed':
        _open(EditScreen(videoPath: path, editType: EditType.speed));
        return;
      case 'quality':
        _open(EditScreen(videoPath: path, editType: EditType.compress));
        return;
      case 'rotate':
        _open(EditScreen(videoPath: path, editType: EditType.rotate));
        return;
      case 'flip':
        _open(EditScreen(videoPath: path, editType: EditType.flip));
        return;
      case 'merge':
        _open(MergeScreen(mainVideoPath: path));
        return;
      case 'mute':
        await _muteVideo(editor);
        return;
      case 'audio':
        _open(const AudioMixScreen());
        return;
    }
  }

  Future<void> _muteVideo(VideoEditorProvider editor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('كتم صوت الفيديو؟'),
        content: const Text('سيتم إنشاء نسخة جديدة بدون المسار الصوتي.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('كتم وتصدير'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await editor.removeAudio();
    if (!mounted) return;
    if (result == null) {
      _showMessage(editor.errorMessage ?? 'تعذّر كتم الصوت', error: true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      exportedVideoSnackBar(
        context,
        result,
        message: 'تم إنشاء الفيديو بدون صوت وحفظه في المعرض',
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openPreviewWithAd(String videoPath) {
    AdService.showInterstitialAd(
      onAdDismissed: () {
        if (mounted) _open(PlayerScreen(videoPath: videoPath));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<VideoEditorProvider>();
    final showDownloads = context
        .watch<AppConfigProvider>()
        .documentDownloadEnabled;
    final horizontal = MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 20.0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 122),
                children: [
                  _Header(onSettings: widget.onOpenSettings),
                  const SizedBox(height: 22),
                  _HeroCard(
                    isPicking: _isPicking,
                    editor: editor,
                    onPick: _pickVideo,
                    onPreview: editor.videoPath == null
                        ? null
                        : () => _openPreviewWithAd(
                            editor.processedVideoPath ?? editor.videoPath!,
                          ),
                  ),
                  const SizedBox(height: 20),
                  _ToolsGrid(onTool: _runTool),
                  const SizedBox(height: 28),
                  _CurrentVideoCard(
                    editor: editor,
                    isPicking: _isPicking,
                    onReplace: _replaceCurrentVideo,
                    onDelete: _removeCurrentVideo,
                    onShare: editor.processedVideoPath == null
                        ? null
                        : _shareCurrentVideo,
                    onPreview: editor.videoPath == null
                        ? null
                        : () => _openPreviewWithAd(
                            editor.processedVideoPath ?? editor.videoPath!,
                          ),
                  ),
                  const SizedBox(height: 22),
                  _ProjectStorageCard(onManage: widget.onOpenProjects),
                  if (showDownloads) ...[
                    const SizedBox(height: 14),
                    _DownloadCard(onTap: widget.onOpenDownloads),
                  ],
                ],
              ),
              if (editor.isProcessing)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.background.withValues(alpha: .88),
                    child: Center(
                      child: Container(
                        width: 290,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: editor.exportProgress > 0
                                  ? editor.exportProgress
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              editor.exportProgress > 0
                                  ? 'جاري التصدير ${(editor.exportProgress * 100).round()}%'
                                  : 'جاري تجهيز الفيديو…',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: editor.cancelProcessing,
                              child: const Text('إلغاء'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _replaceCurrentVideo() async {
    await _pickVideo();
  }

  Future<void> _removeCurrentVideo() async {
    final editor = context.read<VideoEditorProvider>();
    if (editor.videoPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الفيديو الحالي؟'),
        content: const Text(
          'ستتم إزالة الفيديو من مساحة التعديل فقط. لن يُحذف الملف من جهازك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      editor.reset();
      _showMessage('تمت إزالة الفيديو الحالي.');
    }
  }

  Future<void> _shareCurrentVideo() async {
    final path = context.read<VideoEditorProvider>().processedVideoPath;
    if (path == null) return;
    try {
      await shareExportedVideo(context, path);
    } catch (error) {
      if (mounted) _showMessage('تعذّرت المشاركة: $error', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.elevatedSurface,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'ستوديو المونتاج '),
                  TextSpan(
                    text: 'الذكي',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'أدوات احترافية لقص وتعديل الفيديوهات بسهولة',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      IconButton(
        tooltip: 'الإعدادات',
        onPressed: onSettings,
        style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.settings_outlined, size: 27),
      ),
    ],
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.isPicking,
    required this.editor,
    required this.onPick,
    required this.onPreview,
  });

  final bool isPicking;
  final VideoEditorProvider editor;
  final Future<bool> Function() onPick;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 2.22,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: .75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              AppColors.primary,
              BlendMode.hue,
            ),
            child: Image.asset(
              'assets/images/editor_hero.png',
              fit: BoxFit.cover,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0x0012ADB6),
                  Color(0xDDF1FBFC),
                  Color(0xFFF7FCFC),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: .55,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editor.videoPath == null
                          ? 'ابدأ مشروعك الإبداعي'
                          : 'مشروعك جاهز للتحرير',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      editor.videoPath == null
                          ? 'اختر فيديو من المعرض وابدأ في المونتاج الآن'
                          : 'شغّل المعاينة أو اختر أداة من الأسفل',
                      maxLines: 2,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 41,
                      child: FilledButton.icon(
                        onPressed: isPicking
                            ? null
                            : editor.videoPath == null
                            ? onPick
                            : onPreview,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: isPicking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                editor.videoPath == null
                                    ? Icons.add_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                        label: Text(
                          editor.videoPath == null
                              ? 'اختيار فيديو من المعرض'
                              : 'معاينة الفيديو',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({required this.onTool});
  final ValueChanged<String> onTool;

  static const tools = [
    (
      'quality',
      Icons.high_quality_rounded,
      'تحسين الجودة',
      'دقة أعلى ووضوح',
      AppColors.primary,
    ),
    (
      'speed',
      Icons.speed_rounded,
      'تغيير السرعة',
      'بطيء / سريع',
      AppColors.primary,
    ),
    (
      'crop',
      Icons.crop_rounded,
      'اقتصاص',
      'تغيير نسبة الأبعاد',
      AppColors.primary,
    ),
    (
      'trim',
      Icons.content_cut_rounded,
      'قص الفيديو',
      'اقتطاع وإزالة أجزاء',
      AppColors.primary,
    ),
    (
      'mute',
      Icons.volume_off_rounded,
      'كتم الصوت',
      'حذف صوت الفيديو',
      AppColors.primary,
    ),
    (
      'audio',
      Icons.music_note_rounded,
      'الصوت والموسيقى',
      'مستوى وصوت خلفي',
      AppColors.primary,
    ),
    (
      'merge',
      Icons.video_library_rounded,
      'دمج المقاطع',
      'جمع عدة فيديوهات',
      AppColors.primary,
    ),
    (
      'flip',
      Icons.flip_rounded,
      'قلب الفيديو',
      'أفقي أو رأسي',
      AppColors.primary,
    ),
    (
      'rotate',
      Icons.rotate_90_degrees_cw_rounded,
      'تدوير',
      '90° أو 180°',
      AppColors.primary,
    ),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: tools.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 9,
      mainAxisSpacing: 10,
      childAspectRatio: .9,
    ),
    itemBuilder: (context, index) {
      final tool = tools[index];
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => onTool(tool.$1),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF5FBFC)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool.$2, color: tool.$5, size: 29),
                const SizedBox(height: 6),
                Text(
                  tool.$3,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tool.$4,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 7.5,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CurrentVideoCard extends StatelessWidget {
  const _CurrentVideoCard({
    required this.editor,
    required this.isPicking,
    required this.onReplace,
    required this.onDelete,
    required this.onShare,
    required this.onPreview,
  });

  final VideoEditorProvider editor;
  final bool isPicking;
  final Future<void> Function() onReplace;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onShare;
  final VoidCallback? onPreview;

  String get _duration {
    final seconds = (editor.metadata?.duration ?? 0) ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final videoPath = editor.processedVideoPath ?? editor.videoPath;
    final hasVideo = videoPath != null;
    final name = hasVideo
        ? videoPath.split(Platform.pathSeparator).last
        : 'لم يتم اختيار فيديو بعد';
    final thumbnail = editor.thumbnailPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.movie_filter_outlined,
              color: AppColors.primary,
              size: 25,
            ),
            SizedBox(width: 7),
            Text(
              'الفيديو الحالي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Material(
                color: AppColors.elevatedSurface,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPreview,
                  child: SizedBox(
                    width: 112,
                    height: 78,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnail != null && File(thumbnail).existsSync())
                          Image.file(File(thumbnail), fit: BoxFit.cover)
                        else
                          const Icon(
                            Icons.video_library_outlined,
                            color: AppColors.textSecondary,
                          ),
                        if (hasVideo)
                          const Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasVideo ? 'المدة $_duration' : 'اختر فيديو لبدء التعديل',
                      textDirection: hasVideo ? TextDirection.ltr : null,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isPicking ? null : () => onReplace(),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                            ),
                            label: Text(hasVideo ? 'استبدال' : 'اختيار فيديو'),
                          ),
                        ),
                        if (hasVideo) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'إزالة الفيديو',
                            onPressed: () => onDelete(),
                            style: IconButton.styleFrom(
                              foregroundColor: AppColors.error,
                              backgroundColor: AppColors.error.withValues(
                                alpha: .12,
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ],
                    ),
                    if (onShare != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => onShare!(),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('مشاركة الفيديو المُصدَّر'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectStorageCard extends StatelessWidget {
  const _ProjectStorageCard({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>().projects;
    var bytes = 0;
    for (final project in projects) {
      try {
        bytes += File(project.videoPath).lengthSync();
      } catch (_) {}
    }
    final megabytes = bytes / (1024 * 1024);
    final progress = (megabytes / 1024).clamp(0.02, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.elevatedSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مساحة المشاريع',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${megabytes.toStringAsFixed(megabytes < 10 ? 1 : 0)} MB مستخدمة',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress, minHeight: 7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.folder_outlined),
            label: const Text('إدارة الملفات'),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: const BoxDecoration(
            color: AppColors.elevatedSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cloud_download_outlined,
            color: AppColors.primaryLight,
            size: 30,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تنزيل الملفات بسهولة',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'الصور، الفيديوهات، المستندات والملفات المدعومة',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.download_rounded),
          label: const Text('تنزيل ملف'),
        ),
      ],
    ),
  );
}
