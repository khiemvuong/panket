import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panket/models/post_model.dart';
import 'package:panket/services/elevenlabs_service.dart';
import 'package:panket/services/ffmpeg_service.dart';
import 'package:panket/services/widget_service.dart';
import 'package:panket/services/background_handler.dart';
import 'package:panket/services/firebase_service.dart';

class LocketViewModel extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  String? _imagePath;
  String? get imagePath => _imagePath;

  String? _audioPath;
  String? get audioPath => _audioPath;

  String _textInput = '';
  String get textInput => _textInput;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  String _elevenLabsApiKey = '';
  String get elevenLabsApiKey => _elevenLabsApiKey;

  String? _currentWidgetImage;
  String? get currentWidgetImage => _currentWidgetImage;

  String? _currentWidgetAudio;
  String? get currentWidgetAudio => _currentWidgetAudio;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _playbackTimer;
  int _playbackProgress = 0;
  int get playbackProgress => _playbackProgress;

  // Profile Switcher & Bạn bè (Hỗ trợ mô phỏng realtime nhiều tài khoản)
  final List<Map<String, String>> _users = [
    {'id': 'user_1', 'name': 'Bạn (A)'},
    {'id': 'user_2', 'name': 'John (B)'},
    {'id': 'user_3', 'name': 'Sarah (C)'},
    {'id': 'user_4', 'name': 'Emily (D)'},
  ];
  List<Map<String, String>> get users => _users;

  String _currentUserId = 'user_1';
  String get currentUserId => _currentUserId;
  String get currentUserName => _users.firstWhere((u) => u['id'] == _currentUserId)['name']!;

  // Bạn bè được chọn làm người nhận bài đăng
  String _selectedRecipientId = 'user_2';
  String get selectedRecipientId => _selectedRecipientId;

  // Feed lịch sử bài đăng
  List<PostModel> _postsFeed = [];
  List<PostModel> get postsFeed => _postsFeed;

  StreamSubscription<List<PostModel>>? _postsSubscription;

  LocketViewModel() {
    _loadCurrentWidgetData();
    _initFirebasePostsListener();
  }

  void setTextInput(String text) {
    _textInput = text;
    notifyListeners();
  }

  void setApiKey(String key) {
    _elevenLabsApiKey = key;
    notifyListeners();
  }

  void setSelectedRecipient(String recipientId) {
    _selectedRecipientId = recipientId;
    notifyListeners();
  }

  /// Thay đổi người dùng hiện tại (Profile Switcher) để test gửi/nhận
  void changeCurrentUser(String userId) {
    _currentUserId = userId;
    
    // Tự chọn người nhận mặc định là tài khoản đầu tiên khác mình
    final firstFriend = _users.firstWhere((u) => u['id'] != userId);
    _selectedRecipientId = firstFriend['id']!;

    notifyListeners();
    // Khởi tạo lại listener để lọc/nhận bài đăng từ góc nhìn của user mới
    _initFirebasePostsListener();
  }

  /// Đăng ký lắng nghe các bài đăng từ Firebase (hoặc Mock Cache)
  void _initFirebasePostsListener() {
    _postsSubscription?.cancel();
    _postsSubscription = FirebaseService.listenToPosts().listen((posts) async {
      _postsFeed = posts;
      notifyListeners();

      // Tự động đồng bộ sang Locket Widget cục bộ của mình nếu có bài đăng mới nhất từ NGƯỜI KHÁC gửi lên
      if (posts.isNotEmpty) {
        final latestPost = posts.first;
        if (latestPost.senderId != _currentUserId) {
          debugPrint('Nhận bài đăng mới từ: ${latestPost.senderName}. Tiến hành cập nhật Widget...');
          await _syncPostToWidget(latestPost);
        }
      }
    });
  }

  /// Đồng bộ bài đăng sang Widget (Tải ảnh/nhạc và ghi vào Shared UserDefaults)
  Future<void> _syncPostToWidget(PostModel post) async {
    try {
      final imagePath = await downloadAndSaveFile(post.imageUrl, 'widget_image_${post.id}.jpg');
      final audioPath = post.audioUrl.isNotEmpty
          ? await downloadAndSaveFile(post.audioUrl, 'widget_audio_${post.id}.mp3')
          : null;

      if (imagePath != null) {
        await WidgetService.updateWidgetMedia(
          imagePath: imagePath,
          audioPath: audioPath,
        );
        await _loadCurrentWidgetData();
      }
    } catch (e) {
      debugPrint('Lỗi tự động đồng bộ bài đăng sang Widget: $e');
    }
  }

  /// Tải dữ liệu Widget hiện tại từ UserDefaults
  Future<void> _loadCurrentWidgetData() async {
    _currentWidgetImage = await WidgetService.getWidgetData<String>('imagePath');
    _currentWidgetAudio = await WidgetService.getWidgetData<String>('audioPath');
    notifyListeners();
  }

  /// Chọn hình ảnh từ Camera hoặc Gallery
  Future<void> pickImage(ImageSource source) async {
    _errorMessage = null;
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file != null) {
        _imagePath = file.path;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Lỗi chọn ảnh: $e';
      notifyListeners();
    }
  }

  /// Gọi ElevenLabs sinh giọng nói AI từ văn bản đầu vào.
  Future<void> generateVoice() async {
    if (_textInput.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập văn bản để tạo giọng nói AI.';
      notifyListeners();
      return;
    }
    if (_elevenLabsApiKey.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập ElevenLabs API Key.';
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Sinh các tệp âm thanh nhỏ từ ElevenLabs (tự động phân đoạn bên trong)
      final chunkPaths = await ElevenLabsService.generateSpeech(
        text: _textInput,
        apiKey: _elevenLabsApiKey,
      );

      // 2. Sử dụng FFmpeg ghép các chunk âm thanh lại thành tệp duy nhất
      final mergedPath = await FFmpegService.concatAudios(chunkPaths);
      _audioPath = mergedPath;
      
      // Dọn dẹp các tệp chunk nháp (chỉ chạy trên Mobile/Desktop)
      if (!kIsWeb) {
        for (final path in chunkPaths) {
          if (path != mergedPath) {
            try {
              final f = File(path);
              if (await f.exists()) {
                await f.delete();
              }
            } catch (_) {}
          }
        }
      }

    } catch (e) {
      _errorMessage = 'Lỗi tạo giọng nói AI: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Upload hình ảnh và âm thanh lên Firebase, tạo tài liệu Post và chia sẻ
  Future<void> shareWithFriends() async {
    if (_imagePath == null) {
      _errorMessage = 'Vui lòng chọn hoặc chụp ảnh trước khi chia sẻ.';
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final timestamp = DateTime.now();
      final postId = 'post_${timestamp.millisecondsSinceEpoch}';

      // 1. Tải ảnh lên Storage
      final remoteImageUrl = await FirebaseService.uploadMedia(
        _imagePath!,
        'image_$postId.jpg',
      );

      // 2. Tải âm thanh lên Storage (nếu có)
      String remoteAudioUrl = '';
      if (_audioPath != null) {
        remoteAudioUrl = await FirebaseService.uploadMedia(
          _audioPath!,
          'audio_$postId.mp3',
        );
      }

      // 3. Tạo bản ghi bài đăng mới gửi lên Cloud/Mock
      final newPost = PostModel(
        id: postId,
        senderId: _currentUserId,
        senderName: currentUserName,
        imageUrl: remoteImageUrl,
        audioUrl: remoteAudioUrl,
        timestamp: timestamp,
      );

      await FirebaseService.createPost(newPost);

      // 4. Reset các form nhập liệu cục bộ
      _imagePath = null;
      _audioPath = null;
      _textInput = '';
      _errorMessage = null;

      // Cập nhật Widget cục bộ của chính mình làm phản hồi trực quan lập tức
      await WidgetService.updateWidgetMedia(
        imagePath: remoteImageUrl,
        audioPath: remoteAudioUrl.isNotEmpty ? remoteAudioUrl : null,
      );
      await _loadCurrentWidgetData();

    } catch (e) {
      _errorMessage = 'Lỗi chia sẻ: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Cập nhật ảnh và âm thanh đã sinh cục bộ vào Shared Widget Container (không gửi lên mạng)
  Future<void> updateWidget() async {
    if (_imagePath == null) {
      _errorMessage = 'Vui lòng chọn ảnh trước khi cập nhật Widget.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    try {
      await WidgetService.updateWidgetMedia(
        imagePath: _imagePath!,
        audioPath: _audioPath,
      );
      await _loadCurrentWidgetData();
    } catch (e) {
      _errorMessage = 'Lỗi cập nhật Widget: $e';
      notifyListeners();
    }
  }

  /// Mô phỏng chạy FCM Silent Push nhận dữ liệu trực tiếp trong môi trường thử nghiệm.
  Future<void> simulateFCMReceived(String imageUrl, String audioUrl) async {
    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final imagePath = await downloadAndSaveFile(imageUrl, 'simulated_image.jpg');
      final audioPath = await downloadAndSaveFile(audioUrl, 'simulated_audio.mp3');

      if (imagePath != null && audioPath != null) {
        await WidgetService.updateWidgetMedia(
          imagePath: imagePath,
          audioPath: audioPath,
        );
        await _loadCurrentWidgetData();
      } else {
        _errorMessage = 'Tải dữ liệu mô phỏng FCM thất bại.';
      }
    } catch (e) {
      _errorMessage = 'Lỗi mô phỏng FCM: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Phát âm thanh đi kèm của một bài đăng lịch sử
  void playPostAudio(PostModel post) {
    if (post.audioUrl.isEmpty) return;

    // Đặt đường dẫn âm thanh hiện tại thành URL và kích hoạt luồng phát nhạc
    _audioPath = post.audioUrl;
    notifyListeners();
    togglePlaySimulation();
  }

  /// Mô phỏng phát nhạc cục bộ để kiểm tra trạng thái giao diện UI
  void togglePlaySimulation() {
    if (_audioPath == null) return;
    
    if (_isPlaying) {
      _isPlaying = false;
      _playbackTimer?.cancel();
      _playbackProgress = 0;
    } else {
      _isPlaying = true;
      _playbackProgress = 0;
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        _playbackProgress += 5;
        if (_playbackProgress >= 100) {
          _isPlaying = false;
          _playbackProgress = 0;
          timer.cancel();
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }
}
