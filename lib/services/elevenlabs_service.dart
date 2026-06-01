import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  static const String defaultVoiceId = 'OFHP1Qg30FPoNfkUFFlA'; // Giọng Adam
  static const String baseEndpoint = 'https://api.elevenlabs.io/v1/text-to-speech';
  
  /// Thuật toán tách chuỗi văn bản thành các đoạn <= maxChars ký tự.
  /// Ưu tiên ngắt ở dấu câu hoặc khoảng trắng để giữ tự nhiên cho câu nói.
  static List<String> splitText(String text, {int maxChars = 500}) {
    if (text.length <= maxChars) return [text];

    List<String> chunks = [];
    int start = 0;

    while (start < text.length) {
      int end = start + maxChars;
      if (end >= text.length) {
        String lastChunk = text.substring(start).trim();
        if (lastChunk.isNotEmpty) chunks.add(lastChunk);
        break;
      }

      // Tìm dấu ngắt câu hoặc khoảng trắng gần cuối giới hạn maxChars
      int cutIndex = -1;
      final separators = ['.', '!', '?', ';', ',', ' '];
      
      for (var separator in separators) {
        int idx = text.lastIndexOf(separator, end);
        if (idx > start) {
          // Đối với dấu câu, giữ dấu câu ở chunk hiện tại (cutIndex = idx + 1)
          // Đối với khoảng trắng, bỏ khoảng trắng ở chunk sau (cutIndex = idx)
          cutIndex = idx + (separator == ' ' ? 0 : 1);
          break;
        }
      }

      // Nếu không tìm thấy điểm ngắt hợp lệ, buộc phải cắt cứng tại maxChars
      if (cutIndex == -1 || cutIndex == start) {
        cutIndex = end;
      }

      String chunk = text.substring(start, cutIndex).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      start = cutIndex;
    }

    return chunks;
  }

  /// Gọi API ElevenLabs chuyển văn bản thành giọng nói
  /// Trả về danh sách đường dẫn các file âm thanh (.mp3) tạm thời được tạo ra
  static Future<List<String>> generateSpeech({
    required String text,
    required String apiKey,
    String voiceId = defaultVoiceId,
    String modelId = 'eleven_flash_v2_5', // eleven_flash_v2_5 tối ưu độ trễ, có thể nâng lên eleven_v3
  }) async {
    final chunks = splitText(text);
    final List<String> audioPaths = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunkText = chunks[i];
      final url = Uri.parse('$baseEndpoint/$voiceId');
      
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': chunkText,
          'model_id': modelId,
          'voice_settings': {
            'stability': 0.40,
            'similarity_boost': 0.75,
            'style': 0.50,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw HttpException(
          'ElevenLabs API error (status ${response.statusCode}): ${response.body}',
          uri: url,
        );
      }

      if (kIsWeb) {
        // Trên Web: chuyển đổi trực tiếp bytes thành Base64 data URL để phát hoặc giả lập
        final dataUrl = 'data:audio/mpeg;base64,${base64Encode(response.bodyBytes)}';
        audioPaths.add(dataUrl);
      } else {
        // Trên Mobile/Desktop: lưu file tạm
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/elevenlabs_chunk_${DateTime.now().millisecondsSinceEpoch}_$i.mp3');
        await file.writeAsBytes(response.bodyBytes);
        audioPaths.add(file.path);
      }
    }

    return audioPaths;
  }
}
