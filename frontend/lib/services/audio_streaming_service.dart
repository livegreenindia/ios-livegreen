import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

/// Audio Streaming Service - Downloads and caches audio files from Firebase Storage
class AudioStreamingService {
  static final AudioStreamingService _instance = AudioStreamingService._internal();
  factory AudioStreamingService() => _instance;
  AudioStreamingService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, String> _cachedPaths = {};

  /// Audio files configuration - maps local asset names to Firebase Storage paths
  static const Map<String, String> audioFiles = {
    'sounds/Breeze.mp3': 'assets/sounds/Breeze.mp3',
    'sounds/Forest_sound.mp3': 'assets/sounds/Forest_sound.mp3',
    'sounds/Rain sound.mp3': 'assets/sounds/Rain sound.mp3',
    'sounds/Guided Body Scan Meditation.mp3': 'assets/sounds/Guided Body Scan Meditation.mp3',
  };

  /// Get local file path for an audio asset
  /// Downloads from Firebase Storage if not already cached
  Future<String?> getAudioPath(String assetPath) async {
    // Check if already cached in memory
    if (_cachedPaths.containsKey(assetPath)) {
      final path = _cachedPaths[assetPath]!;
      if (await File(path).exists()) {
        return path;
      }
    }

    // Get Firebase Storage path
    final storagePath = audioFiles[assetPath];
    if (storagePath == null) {
      debugPrint('Audio file not found in mapping: $assetPath');
      return null;
    }

    try {
      // Get local cache directory
      final cacheDir = await getApplicationCacheDirectory();
      final fileName = storagePath.split('/').last;
      final localFile = File('${cacheDir.path}/audio/$fileName');

      // Check if file exists locally
      if (await localFile.exists()) {
        debugPrint('Audio already cached: $fileName');
        _cachedPaths[assetPath] = localFile.path;
        return localFile.path;
      }

      // Download from Firebase Storage
      debugPrint('Downloading audio from Firebase: $storagePath');
      final ref = _storage.ref(storagePath);
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      
      // Create directory if needed
      await localFile.parent.create(recursive: true);
      
      // Download file
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        debugPrint('Audio downloaded successfully: $fileName');
        _cachedPaths[assetPath] = localFile.path;
        return localFile.path;
      } else {
        debugPrint('Failed to download audio: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting audio file: $e');
      return null;
    }
  }

  /// Pre-download audio files in the background
  Future<void> preloadAudio(List<String> assetPaths, {
    void Function(String fileName, double progress)? onProgress,
  }) async {
    for (final assetPath in assetPaths) {
      final storagePath = audioFiles[assetPath];
      if (storagePath == null) continue;

      final fileName = storagePath.split('/').last;
      onProgress?.call(fileName, 0.0);

      await getAudioPath(assetPath);
      
      onProgress?.call(fileName, 1.0);
    }
  }

  /// Clear cached audio files
  Future<void> clearCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final audioDir = Directory('${cacheDir.path}/audio');
      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        _cachedPaths.clear();
        debugPrint('Audio cache cleared');
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Get total size of cached audio files
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final audioDir = Directory('${cacheDir.path}/audio');
      if (!await audioDir.exists()) return 0;

      int totalSize = 0;
      await for (final file in audioDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }
}
