import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../providers/video_editor_provider.dart';
import '../services/audio_mixing_service.dart';
import '../utils/app_colors.dart';
import '../utils/export_sharing.dart';
import '../widgets/custom_app_bar.dart';

class AudioMixScreen extends StatefulWidget {
  const AudioMixScreen({super.key});

  @override
  State<AudioMixScreen> createState() => _AudioMixScreenState();
}

class _AudioMixScreenState extends State<AudioMixScreen> {
  String? _musicPath;
  double _originalVolume = 1;
  double _musicVolume = .55;
  bool _pickingMusic = false;

  Future<void> _pickMusic() async {
    if (_pickingMusic) return;
    setState(() => _pickingMusic = true);
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      final path = selection?.files.single.path;
      if (path == null || !mounted) return;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('ملف الموسيقى غير صالح.');
      }
      setState(() => _musicPath = path);
    } catch (error) {
      if (mounted) _message('تعذّر اختيار الموسيقى: $error', error: true);
    } finally {
      if (mounted) setState(() => _pickingMusic = false);
    }
  }

  Future<void> _export() async {
    final provider = context.read<VideoEditorProvider>();
    final result = await provider.mixAudio(
      originalVolume: _originalVolume,
      musicPath: _musicPath,
      musicVolume: _musicVolume,
    );
    if (!mounted) return;
    if (result == null) {
      _message(provider.errorMessage ?? 'تعذّر تصدير الصوت.', error: true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      exportedVideoSnackBar(
        context,
        result,
        message: 'تم تطبيق الصوت وحفظ الفيديو في المعرض.',
      ),
    );
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.elevatedSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoEditorProvider>();
    final isSupported = AudioMixingService.isSupported;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const CustomAppBar(isBack: true, title: 'الصوت والموسيقى'),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                    children: [
                      if (!isSupported)
                        _UnsupportedCard()
                      else ...[
                        _InfoCard(),
                        const SizedBox(height: 14),
                        _VolumeCard(
                          title: 'صوت الفيديو',
                          subtitle: 'تحكم في مستوى الصوت الأصلي عند التصدير',
                          icon: Icons.volume_up_rounded,
                          value: _originalVolume,
                          onChanged: (value) =>
                              setState(() => _originalVolume = value),
                        ),
                        const SizedBox(height: 14),
                        _MusicCard(
                          path: _musicPath,
                          isPicking: _pickingMusic,
                          volume: _musicVolume,
                          onPick: _pickMusic,
                          onRemove: _musicPath == null
                              ? null
                              : () => setState(() => _musicPath = null),
                          onVolumeChanged: (value) =>
                              setState(() => _musicVolume = value),
                        ),
                      ],
                    ],
                  ),
                  if (isSupported)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: FilledButton.icon(
                        onPressed: provider.isProcessing ? null : _export,
                        icon: const Icon(Icons.music_note_rounded),
                        label: const Text('تطبيق الصوت وتصدير الفيديو'),
                      ),
                    ),
                  if (provider.isProcessing)
                    const Positioned.fill(child: _AudioExportOverlay()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.primary.withValues(alpha: .45)),
    ),
    child: const Row(
      children: [
        Icon(Icons.tune_rounded, color: AppColors.primaryLight),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'تُكرر الموسيقى تلقائيًا حتى نهاية الفيديو، وتُدمج المستويات المختارة في الملف المُصدَّر.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _VolumeCard extends StatelessWidget {
  const _VolumeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.path,
    required this.isPicking,
    required this.volume,
    required this.onPick,
    required this.onRemove,
    required this.onVolumeChanged,
  });

  final String? path;
  final bool isPicking;
  final double volume;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'موسيقى خلفية',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          path == null ? 'لا توجد موسيقى مختارة' : p.basename(path!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isPicking ? null : onPick,
          icon: isPicking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.library_music_rounded),
          label: Text(
            path == null ? 'اختيار موسيقى من الجهاز' : 'تغيير الموسيقى',
          ),
        ),
        if (path != null) ...[
          const SizedBox(height: 7),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            label: const Text('إزالة الموسيقى'),
          ),
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                size: 20,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              const Text('مستوى الموسيقى'),
              const Spacer(),
              Text(
                '${(volume * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Slider(value: volume, onChanged: onVolumeChanged),
          ),
        ],
      ],
    ),
  );
}

class _UnsupportedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: const [
        Icon(Icons.phonelink_erase_rounded, color: AppColors.warning, size: 46),
        SizedBox(height: 16),
        Text(
          'خلط الصوت متاح حاليًا على iPhone وiPad فقط.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        SizedBox(height: 8),
        Text(
          'لن نعرض إعدادات لا يمكن تصديرها على هذا الجهاز.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _AudioExportOverlay extends StatelessWidget {
  const _AudioExportOverlay();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Color(0xE60B0D12),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'جاري دمج الصوت وتصدير الفيديو…',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}
