import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_project.dart';

class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider() {
    _load();
  }

  static const _storageKey = 'video_projects_v1';
  final List<VideoProject> _projects = [];
  bool _isLoading = true;

  List<VideoProject> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final values = preferences.getStringList(_storageKey) ?? const [];
      _projects
        ..clear()
        ..addAll(
          values.map((value) {
            final map = jsonDecode(value) as Map<String, dynamic>;
            return VideoProject.fromJson(map);
          }),
        );
      _projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (error) {
      debugPrint('Unable to restore projects: $error');
      _projects.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveCurrent({
    required String videoPath,
    required String? thumbnailPath,
    required int durationMs,
  }) async {
    final existingIndex = _projects.indexWhere(
      (project) => project.videoPath == videoPath,
    );
    if (existingIndex >= 0) {
      final existing = _projects.removeAt(existingIndex);
      _projects.insert(
        0,
        existing.copyWith(videoPath: videoPath, thumbnailPath: thumbnailPath),
      );
    } else {
      final now = DateTime.now();
      _projects.insert(
        0,
        VideoProject(
          id: now.microsecondsSinceEpoch.toString(),
          name: 'مشروع ${_projects.length + 1}',
          videoPath: videoPath,
          thumbnailPath: thumbnailPath,
          durationMs: durationMs,
          updatedAt: now,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    final index = _projects.indexWhere((project) => project.id == id);
    final trimmed = name.trim();
    if (index < 0 || trimmed.isEmpty) return;
    _projects[index] = _projects[index].copyWith(name: trimmed);
    _projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _projects.removeWhere((project) => project.id == id);
    await _persist();
    notifyListeners();
  }

  Future<bool> sourceExists(VideoProject project) =>
      File(project.videoPath).exists();

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      _projects.map((project) => jsonEncode(project.toJson())).toList(),
    );
  }
}
