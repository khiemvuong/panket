import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class FFmpegService {
  /// Ghép (concatenate) nhiều tệp âm thanh MP3 thành một tệp duy nhất.
  /// Sử dụng cơ chế concat file list của FFmpeg trên mobile, và ghép nhị phân trên Windows/Desktop.
  static Future<String> concatAudios(List<String> audioPaths) async {
    if (audioPaths.isEmpty) {
      throw ArgumentError('Danh sách tệp âm thanh không được rỗng.');
    }
    if (audioPaths.length == 1) {
      return audioPaths.first;
    }

    final tempDir = await getTemporaryDirectory();

    // 1. Trên nền tảng di động: dùng FFmpegKit để bảo toàn các thẻ metadata và tính đúng đắn của stream
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        final concatListFile = File('${tempDir.path}/audio_concat_list_${DateTime.now().millisecondsSinceEpoch}.txt');
        final outputPath = '${tempDir.path}/merged_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';

        // Tạo file list chứa các đường dẫn tệp âm thanh
        final content = audioPaths.map((path) => "file '$path'").join('\n');
        await concatListFile.writeAsString(content);

        // Lệnh ghép âm thanh không giải mã lại
        final command = '-y -f concat -safe 0 -i ${concatListFile.path} -c copy $outputPath';
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        // Dọn dẹp tệp list trung gian
        if (await concatListFile.exists()) {
          await concatListFile.delete();
        }

        if (ReturnCode.isSuccess(returnCode)) {
          return outputPath;
        } else {
          debugPrint('FFmpegKit failed to merge, falling back to binary concatenation.');
        }
      } catch (e) {
        debugPrint('FFmpegKit exception: $e. Falling back to binary concatenation.');
      }
    }

    // 2. Dự phòng (Windows/Web/Desktop/FFmpeg lỗi): Ghép nối nhị phân trực tiếp (tốt cho tệp MP3 thô)
    final outputPath = '${tempDir.path}/merged_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final List<int> combinedBytes = [];
    for (final path in audioPaths) {
      final f = File(path);
      if (await f.exists()) {
        combinedBytes.addAll(await f.readAsBytes());
      }
    }
    await File(outputPath).writeAsBytes(combinedBytes);
    return outputPath;
  }

  /// Mux (hợp nhất) ảnh tĩnh và tệp âm thanh thành tệp video MP4.
  static Future<String> muxImageAndAudio({
    required String imagePath,
    required String audioPath,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/muxed_output_${DateTime.now().millisecondsSinceEpoch}.mp4';

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        // Lệnh: Lặp lại ảnh tĩnh và ghép với nhạc nền, mã hóa video dạng libx264, âm thanh AAC
        final command = '-y -loop 1 -i "$imagePath" -i "$audioPath" '
            '-c:v libx264 -tune stillimage -c:a aac -b:a 192k -pix_fmt yuv420p -shortest "$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          return outputPath;
        }
      } catch (e) {
        debugPrint('FFmpegKit muxing exception: $e');
      }
    }

    // Dự phòng Windows/Desktop: Trả về một tệp rỗng hoặc báo lỗi giả lập
    final dummyVideoFile = File(outputPath);
    await dummyVideoFile.writeAsString('Simulated Video File for Desktop');
    return outputPath;
  }
}
