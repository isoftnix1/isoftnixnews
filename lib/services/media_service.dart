import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class MediaServiceResult {
  final bool success;
  final File? file;
  final String? errorMessage;
  final bool requiresAction;

  MediaServiceResult({
    required this.success,
    this.file,
    this.errorMessage,
    this.requiresAction = false,
  });
}

class MediaService {
  static const int _imageSoftLimit = 2 * 1024 * 1024; // 2 MB
  static const int _imageHardLimit = 5 * 1024 * 1024; // 5 MB

  static const int _videoSoftLimit = 10 * 1024 * 1024; // 10 MB
  static const int _videoHardLimit = 15 * 1024 * 1024; // 15 MB

  static Future<MediaServiceResult> processImage(File file) async {
    final int fileSize = await file.length();

    if (fileSize > _imageHardLimit) {
      return MediaServiceResult(
        success: false,
        errorMessage: 'Image exceeds the maximum supported size of 5 MB.\nPlease choose a smaller image.',
      );
    }

    if (fileSize <= _imageSoftLimit) {
      return MediaServiceResult(success: true, file: file);
    }

    // Between 2MB and 5MB -> Compress
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1920,
      minHeight: 1080,
    );

    if (result == null) {
      return MediaServiceResult(success: false, errorMessage: 'Failed to compress image.');
    }

    final compressedFile = File(result.path);
    return MediaServiceResult(success: true, file: compressedFile);
  }

  static Future<MediaServiceResult> processVideo(File file) async {
    final int fileSize = await file.length();

    if (fileSize > _videoHardLimit) {
      return MediaServiceResult(
        success: false,
        errorMessage: 'Maximum supported video size is 15 MB.',
      );
    }

    if (fileSize <= _videoSoftLimit) {
      return MediaServiceResult(success: true, file: file);
    }

    // Between 10MB and 15MB -> Compress
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    if (info == null || info.file == null) {
      return MediaServiceResult(success: false, errorMessage: 'Failed to compress video.');
    }

    final int newSize = await info.file!.length();

    if (newSize > _videoSoftLimit) {
      return MediaServiceResult(
        success: false,
        requiresAction: true,
        errorMessage: 'This video exceeds the upload limit.\n\nChoose one:\n• Select another video\n• Attach Google Drive link\n• Attach YouTube link',
      );
    }

    return MediaServiceResult(success: true, file: info.file);
  }

  static Future<void> cancelVideoCompression() async {
    await VideoCompress.cancelCompression();
  }
}
