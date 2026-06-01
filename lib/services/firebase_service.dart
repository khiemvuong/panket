import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:panket/models/post_model.dart';

class FirebaseService {
  // Đặt true để BẮT BUỘC sử dụng chế độ Giả lập (Simulation Mode).
  // Đặt false để tự động kết nối với Firebase thực tế.
  static const bool forceSimulationMode = true;

  static bool _isInitialized = false;
  static bool get isSimulationMode => forceSimulationMode || !_isInitialized;

  // Cấu trúc dữ liệu giả lập (Simulation Mode Cache)
  static final List<PostModel> _simulatedPosts = [
    PostModel(
      id: 'mock_post_1',
      senderId: 'user_2',
      senderName: 'John (B)',
      imageUrl: 'https://picsum.photos/id/101/400/400',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      caption: 'Nghe bài hát mới này chill quá mọi người ơi! 🎧',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    PostModel(
      id: 'mock_post_2',
      senderId: 'user_3',
      senderName: 'Sarah (C)',
      imageUrl: 'https://picsum.photos/id/102/400/400',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      caption: 'Hôm nay trời đẹp quá, đi dạo thôi! ☀️',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    PostModel(
      id: 'mock_post_3',
      senderId: 'user_4',
      senderName: 'Emily (D)',
      imageUrl: 'https://picsum.photos/id/103/400/400',
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      caption: 'Chill cuối tuần nhè nhẹ 🌸',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
  static final StreamController<List<PostModel>> _simulatedStreamController =
      StreamController<List<PostModel>>.broadcast();

  /// Khởi tạo và kiểm tra kết nối với Firebase thực tế
  static Future<void> initialize() async {
    if (forceSimulationMode) {
      _isInitialized = false;
      debugPrint('Forced Simulation Mode is active.');
      return;
    }
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isNotEmpty) {
        // Thực hiện một truy vấn nhẹ đến Firestore để kiểm tra kết nối mạng và quyền truy cập thực tế
        await FirebaseFirestore.instance
            .collection('posts')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));
        _isInitialized = true;
        debugPrint('Firebase Real Mode is active and connected.');
      } else {
        _isInitialized = false;
        debugPrint('Firebase is not initialized. Using Simulation Mode.');
      }
    } catch (e) {
      _isInitialized = false;
      debugPrint('Firebase check failed ($e). Using Simulation Mode.');
    }
  }

  /// Tải tệp tin phương tiện lên Firebase Storage (hoặc trả về URL giả lập)
  static Future<String> uploadMedia(String localPath, String fileName) async {
    await initialize();

    if (isSimulationMode) {
      // 1. Chế độ Giả lập: Trả về URL mẫu hỗ trợ hiển thị/phát nhạc
      if (fileName.contains('image')) {
        // Trả về URL ảnh ngẫu nhiên từ Picsum
        final randomId = DateTime.now().millisecondsSinceEpoch % 1000;
        return 'https://picsum.photos/id/$randomId/400/400';
      } else {
        // Trả về một tệp nhạc mẫu của SoundHelix
        final songs = [
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        ];
        final index = DateTime.now().millisecondsSinceEpoch % songs.length;
        return songs[index];
      }
    }

    // 2. Chế độ Thật: Tải lên Firebase Storage
    try {
      final ref = FirebaseStorage.instance.ref().child('posts/$fileName');
      
      if (kIsWeb) {
        // Trên Web: tải tệp thông qua bytes của Blob URL
        final response = await http.get(Uri.parse(localPath));
        if (response.statusCode == 200) {
          final uploadTask = ref.putData(
            response.bodyBytes,
            SettableMetadata(contentType: fileName.contains('image') ? 'image/jpeg' : 'audio/mpeg'),
          );
          final snapshot = await uploadTask;
          return await snapshot.ref.getDownloadURL();
        } else {
          throw Exception('Failed to load local file bytes on Web.');
        }
      } else {
        // Trên Mobile/Desktop: tải tệp từ đường dẫn File cục bộ
        final uploadTask = ref.putFile(File(localPath));
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading file to Firebase: $e');
      throw Exception('Tải file lên Cloud thất bại: $e');
    }
  }

  /// Gửi bài đăng mới
  static Future<void> createPost(PostModel post) async {
    await initialize();

    if (isSimulationMode) {
      // Chế độ Giả lập: Thêm vào bộ nhớ cache RAM và kích hoạt stream
      _simulatedPosts.insert(0, post);
      _simulatedStreamController.add(List.from(_simulatedPosts));
      debugPrint('Simulated post created: ${post.id}');
      return;
    }

    // Chế độ Thật: Ghi vào Firestore
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .set(post.toMap());
    } catch (e) {
      debugPrint('Error writing post to Firestore: $e');
      throw Exception('Gửi bài viết lên Cloud thất bại: $e');
    }
  }

  /// Lắng nghe luồng dữ liệu các bài đăng thời gian thực
  static Stream<List<PostModel>> listenToPosts() async* {
    // Đảm bảo đã thực hiện kiểm tra Firebase
    await initialize();

    if (isSimulationMode) {
      // Kích hoạt dữ liệu ban đầu cho listener mới qua Microtask
      scheduleMicrotask(() {
        if (!_simulatedStreamController.isClosed) {
          _simulatedStreamController.add(List.from(_simulatedPosts));
        }
      });
      yield* _simulatedStreamController.stream;
    } else {
      // Chế độ Thật: Lắng nghe snapshot từ Firestore, sắp xếp theo thời gian mới nhất
      yield* FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return PostModel.fromMap(doc.data());
        }).toList();
      });
    }
  }
}
