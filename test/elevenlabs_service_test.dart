import 'package:flutter_test/flutter_test.dart';
import 'package:panket/services/elevenlabs_service.dart';

void main() {
  group('ElevenLabsService.splitText Tests', () {
    test('Should return single chunk if text is shorter than maxChars', () {
      const text = 'Hello, this is a short text.';
      final chunks = ElevenLabsService.splitText(text, maxChars: 50);

      expect(chunks, hasLength(1));
      expect(chunks.first, equals(text));
    });

    test('Should split text longer than maxChars correctly', () {
      // Chuỗi dài 70 ký tự
      const text = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod.';
      // Tách với maxChars = 30
      final chunks = ElevenLabsService.splitText(text, maxChars: 30);

      expect(chunks.length, greaterThan(1));
      
      // Đảm bảo không có chunk nào vượt quá 30 ký tự
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(30));
      }

      // Đảm bảo khi ghép lại (sau khi trim và join với khoảng trắng) nội dung không bị mất mát thông tin quan trọng
      final combined = chunks.join(' ');
      expect(combined.contains('Lorem ipsum'), isTrue);
      expect(combined.contains('Sed do eiusmod.'), isTrue);
    });

    test('Should split at punctuation or spaces to maintain sentence structure', () {
      // Câu nói rõ ràng với dấu chấm ngắt ở vị trí ký tự ~35
      const text = 'This is a complete sentence. And this is the second sentence.';
      
      // Cắt với maxChars = 40. Dấu chấm nằm ở index 28. Khoảng trắng sau dấu chấm là index 29.
      // Thuật toán nên chọn ngắt sau dấu chấm đầu tiên.
      final chunks = ElevenLabsService.splitText(text, maxChars: 40);

      expect(chunks, hasLength(2));
      expect(chunks[0], equals('This is a complete sentence.'));
      expect(chunks[1], equals('And this is the second sentence.'));
    });

    test('Should handle fallback hard cut when no separator is found', () {
      // Chuỗi dài 20 ký tự không chứa bất cứ dấu cách hay dấu câu nào
      final text = 'A' * 20;
      final chunks = ElevenLabsService.splitText(text, maxChars: 5);

      expect(chunks, hasLength(4));
      for (final chunk in chunks) {
        expect(chunk, equals('AAAAA'));
      }
    });
  });
}
