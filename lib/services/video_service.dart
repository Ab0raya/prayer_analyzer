import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickVideo() async {
    return await _picker.pickVideo(source: ImageSource.gallery);
  }

  /// Extracts frames from video at [fps] (frames per second).
  /// Returns a list of absolute paths to the extracted images.
  Future<List<String>> extractFrames(String videoPath, {int fps = 5}) async {
    final tempDir = await getTemporaryDirectory();
    final String framesDir = path.join(tempDir.path, 'frames_${DateTime.now().millisecondsSinceEpoch}');
    await Directory(framesDir).create();

    // Output pattern: frame_0001.jpg, frame_0002.jpg, ...
    final String startNumber = '00001';
    final String outPath = path.join(framesDir, 'frame_%05d.jpg');

    // FFmpeg command: -i video -vf fps=5 out_dir/frame_%05d.jpg
    // -fps_mode vfr ensures variable frame rate handling if needed
    final String command = '-i "$videoPath" -vf fps=$fps -start_number 1 "$outPath"';

    print('FFmpeg Start: $command');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('FFmpeg Success');
      // List and sort files to ensure order
      final dir = Directory(framesDir);
      final List<FileSystemEntity> entities = dir.listSync();
      final List<String> framePaths = entities
          .whereType<File>()
          .map((e) => e.path)
          .where((p) => p.endsWith('.jpg'))
          .toList();

      framePaths.sort(); // Ensure alphanumeric sort (00001, 00002...)
      return framePaths;
    } else {
      print('FFmpeg Failed');
      final logs = await session.getLogs();
      for (var log in logs) {
        print(log.getMessage());
      }
      return [];
    }
  }

  // Cleanup frames after analysis
  Future<void> cleanupFrames(List<String> framePaths) async {
    if (framePaths.isEmpty) return;
    try {
      final dir = Directory(path.dirname(framePaths.first));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning up frames: $e');
    }
  }
}
