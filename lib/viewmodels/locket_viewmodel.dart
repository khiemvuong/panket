import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'package:flutter/material.dart';
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

  String _elevenLabsApiKey = 'mock';
  String get elevenLabsApiKey => _elevenLabsApiKey;

  String? _selectedFilterUserId;
  String? get selectedFilterUserId => _selectedFilterUserId;

  final Map<String, Map<String, dynamic>> _userThemes = {
    'user_1': {
      'primary': const Color(0xFFF48FB1), // Soft Pink
      'secondary': const Color(0xFFFFF0F2),
      'textColor': const Color(0xFFC2185B),
      'name': 'Hồng phấn',
    },
    'user_2': {
      'primary': const Color(0xFF9FA8DA), // Lavender Blue
      'secondary': const Color(0xFFEEF0FA),
      'textColor': const Color(0xFF3F51B5),
      'name': 'Oải hương',
    },
    'user_3': {
      'primary': const Color(0xFF80CBC4), // Soft Mint
      'secondary': const Color(0xFFEBF7F6),
      'textColor': const Color(0xFF00796B),
      'name': 'Xanh bạc hà',
    },
    'user_4': {
      'primary': const Color(0xFFFFCC80), // Pastel Peach
      'secondary': const Color(0xFFFFF9F0),
      'textColor': const Color(0xFFE65100),
      'name': 'Cam đào',
    },
  };
  Map<String, Map<String, dynamic>> get userThemes => _userThemes;

  String _elevenLabsVoiceId = 'OFHP1Qg30FPoNfkUFFlA'; // Giọng Adam mặc định
  String get elevenLabsVoiceId => _elevenLabsVoiceId;

  bool _isAudioOptionEnabled = false;
  bool get isAudioOptionEnabled => _isAudioOptionEnabled;

  String _selectedEmotion = 'Normal';
  String get selectedEmotion => _selectedEmotion;

  bool _isVoiceGenerated = false;
  bool get isVoiceGenerated => _isVoiceGenerated;

  String? _currentWidgetImage;
  String? get currentWidgetImage => _currentWidgetImage;

  String? _currentWidgetAudio;
  String? get currentWidgetAudio => _currentWidgetAudio;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Timer? _playbackTimer;
  int _playbackProgress = 0;
  int get playbackProgress => _playbackProgress;

  bool _isListViewMode = false;
  bool get isListViewMode => _isListViewMode;

  void setListViewMode(bool value) {
    _isListViewMode = value;
    stopAudio(); // Stop audio when toggling view modes
    notifyListeners();
  }

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

  // Chọn nguồn nhạc: 'TTS' (Giọng đọc AI) hoặc 'MUSIC' (Nhạc nền mẫu)
  String _audioType = 'TTS';
  String get audioType => _audioType;

  int _selectedMusicIndex = 0;
  int get selectedMusicIndex => _selectedMusicIndex;

  final List<Map<String, String>> _sampleSongs = [
    {
      'name': 'Nhạc Chill 1 🌅',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
    },
    {
      'name': 'Nhạc Chill 2 🌌',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'
    },
    {
      'name': 'Nhạc Chill 3 🏝️',
      'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'
    },
  ];
  List<Map<String, String>> get sampleSongs => _sampleSongs;

  void setSelectedMusicIndex(int index) {
    _selectedMusicIndex = index;
    _audioPath = _sampleSongs[index]['url'];
    _isVoiceGenerated = true; // Nhạc nền sẵn có không cần ElevenLabs tạo
    stopAudio();
    notifyListeners();
  }

  void setAudioType(String type) {
    _audioType = type;
    stopAudio();
    if (type == 'MUSIC') {
      _audioPath = _sampleSongs[_selectedMusicIndex]['url'];
      _isVoiceGenerated = true;
    } else {
      _audioPath = null;
      _isVoiceGenerated = false;
    }
    notifyListeners();
  }

  LocketViewModel() {
    _loadCurrentWidgetData();
    _initFirebasePostsListener();
    _initWebAudioListener();
  }

  void _initWebAudioListener() {
    if (kIsWeb) {
      try {
        js.context['onAudioProgress'] = js.allowInterop((double progress, bool playing) {
          _playbackProgress = (progress * 100).toInt();
          _isPlaying = playing;
          notifyListeners();
        });
      } catch (e) {
        debugPrint('Error binding Web audio listener: $e');
      }
    }
  }

  void setTextInput(String text) {
    if (text.length > 100) {
      text = text.substring(0, 100);
    }
    _textInput = text;
    _isVoiceGenerated = false;
    notifyListeners();
  }

  void setAudioOptionEnabled(bool enabled) {
    _isAudioOptionEnabled = enabled;
    if (!enabled) {
      _audioPath = null;
      _isVoiceGenerated = false;
    }
    notifyListeners();
  }

  void setSelectedEmotion(String emotion) {
    _selectedEmotion = emotion;
    _isVoiceGenerated = false;
    notifyListeners();
  }

  void setApiKey(String key) {
    _elevenLabsApiKey = key;
    notifyListeners();
  }

  void setVoiceId(String id) {
    _elevenLabsVoiceId = id;
    _isVoiceGenerated = false; // Yêu cầu tạo lại âm thanh nếu đổi giọng
    notifyListeners();
  }

  void setSelectedRecipient(String recipientId) {
    _selectedRecipientId = recipientId;
    notifyListeners();
  }

  void setFilterUserId(String? userId) {
    _selectedFilterUserId = userId;
    notifyListeners();
  }

  List<PostModel> get filteredPosts {
    if (_selectedFilterUserId == null) {
      return _postsFeed;
    }
    return _postsFeed.where((post) => post.senderId == _selectedFilterUserId).toList();
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
      _errorMessage = 'Vui lòng nhập ElevenLabs API Key (hoặc nhập "mock" để dùng âm thanh giả lập).';
      notifyListeners();
      return;
    }

    _isGenerating = true;
    _errorMessage = null;
    _isVoiceGenerated = false;
    notifyListeners();

    try {
      // Nhúng thẻ cảm xúc vào trước văn bản trước khi gửi tới API ElevenLabs
      String textWithEmotion = _textInput;
      if (_selectedEmotion == 'Happy') {
        textWithEmotion = '[laughs] $_textInput';
      } else if (_selectedEmotion == 'Whisper') {
        textWithEmotion = '[whispers] $_textInput';
      } else if (_selectedEmotion == 'Sad') {
        textWithEmotion = '[sigh] $_textInput';
      }

      List<String> chunkPaths;
      if (_elevenLabsApiKey.trim().toLowerCase() == 'mock') {
        // Tải tệp âm thanh giả lập mẫu
        final mockUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
        final savedPath = await downloadAndSaveFile(mockUrl, 'mock_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
        if (savedPath == null) throw Exception('Không thể tải tệp âm thanh giả lập.');
        chunkPaths = [savedPath];
      } else {
        try {
          // 1. Sinh các tệp âm thanh nhỏ từ ElevenLabs (tự động phân đoạn bên trong)
          chunkPaths = await ElevenLabsService.generateSpeech(
            text: textWithEmotion,
            apiKey: _elevenLabsApiKey,
            voiceId: _elevenLabsVoiceId,
          );
        } catch (e) {
          debugPrint('ElevenLabs error: $e. Falling back to Mock Audio.');
          // Tự động chuyển sang tệp âm thanh giả lập để không chặn tiến trình kiểm thử
          final mockUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
          final savedPath = await downloadAndSaveFile(mockUrl, 'mock_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
          if (savedPath == null) throw Exception('Không thể tải tệp âm thanh giả lập sau khi ElevenLabs lỗi: $e');
          chunkPaths = [savedPath];
          _errorMessage = 'ElevenLabs lỗi ($e).\nĐã tự động chuyển sang âm thanh giả lập để bạn tiếp tục test.';
        }
      }

      // 2. Sử dụng FFmpeg ghép các chunk âm thanh lại thành tệp duy nhất
      final mergedPath = await FFmpegService.concatAudios(chunkPaths);
      _audioPath = mergedPath;
      _isVoiceGenerated = true;
      
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

      // Tự động phát thử giọng nói vừa tạo để người dùng nghe review
      _isPlaying = false;
      _playbackTimer?.cancel();
      togglePlaySimulation();

    } catch (e) {
      _errorMessage = 'Lỗi tạo giọng nói AI: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Hủy bỏ bài đăng đang chuẩn bị, reset toàn bộ form và quay về màn hình camera chính
  void cancelPosting() {
    _imagePath = null;
    _audioPath = null;
    _textInput = '';
    _selectedEmotion = 'Normal';
    _isVoiceGenerated = false;
    _isAudioOptionEnabled = false;
    _errorMessage = null;
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackProgress = 0;
    notifyListeners();
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

      // 2. Tải âm thanh lên Storage (nếu có và được chọn bật)
      String remoteAudioUrl = '';
      if (_isAudioOptionEnabled && _audioPath != null) {
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
        caption: _textInput,
        timestamp: timestamp,
      );

      await FirebaseService.createPost(newPost);

      // 4. Reset các form nhập liệu cục bộ
      _imagePath = null;
      _audioPath = null;
      _textInput = '';
      _selectedEmotion = 'Normal';
      _isVoiceGenerated = false;
      _isAudioOptionEnabled = false;
      _errorMessage = null;
      _isPlaying = false;
      _playbackTimer?.cancel();
      _playbackProgress = 0;

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

  void stopAudio() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackProgress = 0;
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          "if (window.myAudio) { window.myAudio.pause(); window.myAudio.currentTime = 0; }"
        ]);
      } catch (e) {
        debugPrint('Web audio pause error: $e');
      }
    }
    notifyListeners();
  }

  void startAudioForPost(PostModel post) {
    if (post.audioUrl.isEmpty) {
      stopAudio();
      return;
    }
    // Dừng âm thanh cũ nếu đang chạy
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackProgress = 0;

    _audioPath = post.audioUrl;
    _isPlaying = true;

    // Phát âm thanh thật trên Web qua JS với giới hạn 30s
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', [
          "if (!window.myAudio) window.myAudio = new Audio(); "
          "if (!window.myAudioListenersSet) { "
          "  window.myAudio.addEventListener('timeupdate', () => { "
          "    let maxDuration = 30; "
          "    let curTime = window.myAudio.currentTime; "
          "    let duration = Math.min(window.myAudio.duration || maxDuration, maxDuration); "
          "    if (curTime >= maxDuration) { "
          "      window.myAudio.pause(); "
          "      window.myAudio.currentTime = 0; "
          "      if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
          "    } else if (window.onAudioProgress) { "
          "      let progress = curTime / duration; "
          "      window.onAudioProgress(progress > 1.0 ? 1.0 : progress, !window.myAudio.paused); "
          "    } "
          "  }); "
          "  window.myAudio.addEventListener('ended', () => { "
          "    if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
          "  }); "
          "  window.myAudioListenersSet = true; "
          "} "
          "window.myAudio.src = '${post.audioUrl}'; "
          "window.myAudio.play().catch(e => console.log('Audio autoplay error:', e));"
        ]);
      } catch (e) {
        debugPrint('Web audio play error: $e');
      }
    }

    if (!kIsWeb) {
      // Mock timer chỉ dùng trên Mobile/Desktop để giả lập thanh tiến trình
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

  /// Phát âm thanh đi kèm của một bài đăng lịch sử
  void playPostAudio(PostModel post) {
    if (post.audioUrl.isEmpty) return;

    // Đặt đường dẫn âm thanh hiện tại thành URL và kích hoạt luồng phát nhạc
    _audioPath = post.audioUrl;
    notifyListeners();
    togglePlaySimulation();
  }

  /// Mô phỏng và phát nhạc thực tế trên Web
  void togglePlaySimulation() {
    if (_audioPath == null) return;
    
    if (_isPlaying) {
      _isPlaying = false;
      _playbackTimer?.cancel();
      _playbackProgress = 0;

      if (kIsWeb) {
        try {
          js.context.callMethod('eval', [
            "if (window.myAudio) window.myAudio.pause();"
          ]);
        } catch (e) {
          debugPrint('Web audio pause error: $e');
        }
      }
    } else {
      _isPlaying = true;
      _playbackProgress = 0;

      if (kIsWeb) {
        try {
          js.context.callMethod('eval', [
            "if (!window.myAudio) window.myAudio = new Audio(); "
            "if (!window.myAudioListenersSet) { "
            "  window.myAudio.addEventListener('timeupdate', () => { "
            "    let maxDuration = 30; "
            "    let curTime = window.myAudio.currentTime; "
            "    let duration = Math.min(window.myAudio.duration || maxDuration, maxDuration); "
            "    if (curTime >= maxDuration) { "
            "      window.myAudio.pause(); "
            "      window.myAudio.currentTime = 0; "
            "      if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
            "    } else if (window.onAudioProgress) { "
            "      let progress = curTime / duration; "
            "      window.onAudioProgress(progress > 1.0 ? 1.0 : progress, !window.myAudio.paused); "
            "    } "
            "  }); "
            "  window.myAudio.addEventListener('ended', () => { "
            "    if (window.onAudioProgress) window.onAudioProgress(0.0, false); "
            "  }); "
            "  window.myAudioListenersSet = true; "
            "} "
            "window.myAudio.src = '$_audioPath'; "
            "window.myAudio.play().catch(e => console.log('Audio play error:', e));"
          ]);
        } catch (e) {
          debugPrint('Web audio play error: $e');
        }
      }

      if (!kIsWeb) {
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
