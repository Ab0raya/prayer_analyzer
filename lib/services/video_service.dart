import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';

class VideoService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickVideo() async {
    return await _picker.pickVideo(source: ImageSource.gallery);
  }

  Future<Duration?> getVideoDuration(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration;
    } catch (e) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  Stream<Uint8List> streamFrames(
    String videoPath, {
    int intervalMs = 200,
  }) async* {
    final duration = await getVideoDuration(videoPath);
    if (duration == null) return;

    int currentTime = 0;
    final int totalDurationMs = duration.inMilliseconds;

    while (currentTime <= totalDurationMs) {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 50,
        timeMs: currentTime,
      );

      if (uint8list != null) {
        yield uint8list;
      }

      currentTime += intervalMs;
    }
  }
}
