import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/video_project.dart';
import '../providers/projects_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/video_editor_provider.dart';
import '../utils/app_colors.dart';
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
    _showMessage(
      result == null
          ? editor.errorMessage ?? 'تعذّر كتم الصوت'
          : 'تم إنشاء الفيديو بدون صوت وحفظه في المعرض',
      error: result == null,
    );
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
                        : () => _open(
                            PlayerScreen(
                              videoPath:
                                  editor.processedVideoPath ??
                                  editor.videoPath!,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _ToolsGrid(onTool: _runTool),
                  const SizedBox(height: 28),
                  _RecentProjects(
                    onOpenProject: _openProject,
                    onRename: _renameProject,
                    onDelete: _deleteProject,
                    onViewAll: widget.onOpenProjects,
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

  Future<void> _openProject(VideoProject project) async {
    if (!await context.read<ProjectsProvider>().sourceExists(project)) {
      if (mounted) _showMessage('ملف المشروع غير موجود', error: true);
      return;
    }
    if (!mounted) return;
    try {
      await context.read<VideoEditorProvider>().loadVideo(project.videoPath);
      if (!mounted) return;
      _open(PlayerScreen(videoPath: project.videoPath));
    } catch (error) {
      if (mounted) _showMessage('تعذّر فتح المشروع: $error', error: true);
    }
  }

  Future<void> _renameProject(VideoProject project) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تسمية المشروع'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && mounted) {
      await context.read<ProjectsProvider>().rename(project.id, name);
    }
  }

  Future<void> _deleteProject(VideoProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المشروع؟'),
        content: const Text('سيُحذف من القائمة فقط ولن نحذف الفيديو الأصلي.'),
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
      await context.read<ProjectsProvider>().delete(project.id);
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
                    style: TextStyle(color: AppColors.primaryLight),
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
          Image.asset('assets/images/editor_hero.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0x160B0D12),
                  Color(0xC5120D24),
                  Color(0xF20B0D12),
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
                        color: Colors.white,
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
                        color: Color(0xFFC7C3D2),
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
      Color(0xFFB75CFF),
    ),
    (
      'speed',
      Icons.speed_rounded,
      'تغيير السرعة',
      'بطيء / سريع',
      Color(0xFF49E1C0),
    ),
    (
      'crop',
      Icons.crop_rounded,
      'اقتصاص',
      'تغيير نسبة الأبعاد',
      Color(0xFF45CFF2),
    ),
    (
      'trim',
      Icons.content_cut_rounded,
      'قص الفيديو',
      'اقتطاع وإزالة أجزاء',
      Color(0xFFFF963D),
    ),
    (
      'mute',
      Icons.volume_off_rounded,
      'كتم الصوت',
      'حذف صوت الفيديو',
      Color(0xFFFF5FA2),
    ),
    (
      'merge',
      Icons.video_library_rounded,
      'دمج المقاطع',
      'جمع عدة فيديوهات',
      Color(0xFF7D62FF),
    ),
    (
      'flip',
      Icons.flip_rounded,
      'قلب الفيديو',
      'أفقي أو رأسي',
      Color(0xFFEA5DCC),
    ),
    (
      'rotate',
      Icons.rotate_90_degrees_cw_rounded,
      'تدوير',
      '90° أو 180°',
      Color(0xFFB96CFF),
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
                colors: [Color(0xFF18202B), Color(0xFF111720)],
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

class _RecentProjects extends StatelessWidget {
  const _RecentProjects({
    required this.onOpenProject,
    required this.onRename,
    required this.onDelete,
    required this.onViewAll,
  });

  final ValueChanged<VideoProject> onOpenProject;
  final ValueChanged<VideoProject> onRename;
  final ValueChanged<VideoProject> onDelete;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectsProvider>();
    final projects = provider.projects.take(4).toList();
    return Column(
      children: [
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: AppColors.primary,
              size: 25,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'مشاريعي الأخيرة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (provider.isLoading)
          const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (projects.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'ابدأ أول مشروع وسيظهر هنا',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 166,
            child: Row(
              children: projects
                  .map(
                    (project) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ProjectTile(
                          project: project,
                          onOpen: () => onOpenProject(project),
                          onRename: () => onRename(project),
                          onDelete: () => onDelete(project),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final VideoProject project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  String get duration {
    final seconds = project.durationMs ~/ 1000;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = project.thumbnailPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Material(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnail != null && File(thumbnail).existsSync())
                    Image.file(File(thumbnail), fit: BoxFit.cover)
                  else
                    const Icon(
                      Icons.movie_outlined,
                      color: AppColors.textSecondary,
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: -4,
                    top: -5,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconColor: Colors.white,
                      onSelected: (value) {
                        if (value == 'rename') onRename();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('إعادة التسمية'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    start: 7,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        duration,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          project.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        Text(
          '${project.updatedAt.year}/${project.updatedAt.month.toString().padLeft(2, '0')}/${project.updatedAt.day.toString().padLeft(2, '0')}',
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 8.5, color: AppColors.textSecondary),
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
