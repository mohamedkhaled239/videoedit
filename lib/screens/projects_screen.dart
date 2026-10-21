import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../models/video_project.dart';
import '../providers/projects_provider.dart';
import '../providers/video_editor_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_colors.dart';
import '../utils/native_ad_factory.dart';
import 'player_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.onBackHome});
  final VoidCallback onBackHome;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  NativeAd? _nativeAd;
  bool _nativeAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  Future<void> _loadNativeAd() async {
    await AdService.initialize();
    if (!mounted || !AdService.canLoadAds || _nativeAd != null) return;

    late final NativeAd ad;
    ad = NativeAdHelper.createNativeAd(
      adUnitId: AdService.nativeAdUnitId,
      onAdLoaded: (_) {
        if (!mounted) {
          ad.dispose();
          return;
        }
        setState(() => _nativeAdReady = true);
      },
      onAdFailedToLoad: (_, error) {
        debugPrint('Projects native ad failed: ${error.message}');
        ad.dispose();
        if (identical(_nativeAd, ad)) _nativeAd = null;
      },
    );
    _nativeAd = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectsProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 112),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBackHome,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'مشاريعي',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${provider.projects.length} مشروع',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (_nativeAdReady && _nativeAd != null) ...[
                  const SizedBox(height: 12),
                  NativeAdWidget(nativeAd: _nativeAd!, height: 105),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: provider.projects.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 58,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد مشاريع بعد',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          itemCount: provider.projects.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: .93,
                              ),
                          itemBuilder: (context, index) {
                            final project = provider.projects[index];
                            return _ProjectCard(project: project);
                          },
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final VideoProject project;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () async {
        if (!await File(project.videoPath).exists()) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ملف المشروع غير موجود')),
          );
          return;
        }
        if (!context.mounted) return;
        await context.read<VideoEditorProvider>().loadVideo(project.videoPath);
        if (!context.mounted) return;
        AdService.showInterstitialAd(
          onAdDismissed: () {
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(videoPath: project.videoPath),
              ),
            );
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child:
                project.thumbnailPath != null &&
                    File(project.thumbnailPath!).existsSync()
                ? Image.file(File(project.thumbnailPath!), fit: BoxFit.cover)
                : const Icon(
                    Icons.movie_outlined,
                    size: 44,
                    color: AppColors.textSecondary,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      context.read<ProjectsProvider>().delete(project.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف من القائمة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
