import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_config_provider.dart';
import '../providers/projects_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import 'document_download_screen.dart';
import 'home_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ImagePicker _picker = ImagePicker();
  int _currentIndex = 0;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeNotifications());
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (error, stackTrace) {
      debugPrint('Notification startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _createProject() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      final editor = context.read<VideoEditorProvider>();
      await editor.loadVideo(file.path);
      if (!mounted || editor.metadata == null) return;
      await context.read<ProjectsProvider>().saveCurrent(
        videoPath: file.path,
        thumbnailPath: editor.thumbnailPath,
        durationMs: editor.metadata!.duration,
      );
      if (mounted) setState(() => _currentIndex = 0);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر فتح الفيديو: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _openDownloads() async {
    final config = context.read<AppConfigProvider>();
    await config.refreshDocumentDownloadAvailability();
    if (!mounted || !config.documentDownloadEnabled) return;
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    // Remote configuration is deliberately not allowed to block the first
    // frame. Default configuration is usable while Firebase loads in the
    // background.
    final downloadEnabled = context
        .watch<AppConfigProvider>()
        .documentDownloadEnabled;
    final effectiveIndex = !downloadEnabled && _currentIndex == 1
        ? 0
        : _currentIndex;
    if (effectiveIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentIndex == 1) setState(() => _currentIndex = 0);
      });
    }

    final screens = [
      HomeScreen(
        onOpenSettings: () => setState(() => _currentIndex = 3),
        onOpenDownloads: () => unawaited(_openDownloads()),
        onOpenProjects: () => setState(() => _currentIndex = 2),
      ),
      downloadEnabled
          ? DocumentDownloadScreen(activateAds: effectiveIndex == 1)
          : const SizedBox.shrink(),
      ProjectsScreen(onBackHome: () => setState(() => _currentIndex = 0)),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(index: effectiveIndex, children: screens),
      bottomNavigationBar: _StudioNavigationBar(
        selectedIndex: effectiveIndex,
        downloadEnabled: downloadEnabled,
        busy: _isPicking,
        onSelected: (index) {
          if (index == 1) {
            unawaited(_openDownloads());
          } else {
            setState(() => _currentIndex = index);
          }
        },
        onCreate: _createProject,
      ),
    );
  }
}

class _StudioNavigationBar extends StatelessWidget {
  const _StudioNavigationBar({
    required this.selectedIndex,
    required this.downloadEnabled,
    required this.busy,
    required this.onSelected,
    required this.onCreate,
  });

  final int selectedIndex;
  final bool downloadEnabled;
  final bool busy;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
    child: Container(
      height: 66,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F49676E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            _item(0, 'الرئيسية', Icons.home_rounded),
            if (downloadEnabled)
              _item(1, 'الملفات', Icons.cloud_download_outlined),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: IconButton(
                    tooltip: 'مشروع جديد',
                    onPressed: busy ? null : onCreate,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(58, 58),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0xFFBDEFF1), width: 1.5),
                      ),
                      shadowColor: AppColors.primary,
                      elevation: 12,
                    ),
                    icon: busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.add_rounded, size: 34),
                  ),
                ),
              ),
            ),
            _item(2, 'المشاريع', Icons.folder_outlined),
            _item(3, 'الإعدادات', Icons.person_outline_rounded),
          ],
        ),
      ),
    ),
  );

  Widget _item(int index, String label, IconData icon) {
    final selected = selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(index),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: .14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.textSecondary,
                  fontSize: 8,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
