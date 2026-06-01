import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:panket/viewmodels/locket_viewmodel.dart';
import 'package:panket/models/post_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocketViewModel>(
      builder: (context, viewModel, child) {
        final isEditing = viewModel.imagePath != null;

        // Lấy theme nền theo user hiện tại
        final currentTheme = viewModel.userThemes[viewModel.currentUserId];
        final Color bgPrimary = currentTheme?['secondary'] ?? const Color(0xFFFFF0F2);
        final Color bgSecondary = Color.lerp(currentTheme?['primary'] ?? const Color(0xFFF48FB1), Colors.white, 0.88) ?? const Color(0xFFF6ECFC);

        return Container(
          // Nền chủ đạo đổi theo theme của người dùng hiện tại
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgPrimary, bgSecondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Để lộ lớp nền gradient
            appBar: AppBar(
              backgroundColor: Colors.white.withOpacity(0.4),
              elevation: 0,
              leading: isEditing
                  ? IconButton(
                      icon: Icon(CupertinoIcons.left_chevron, color: currentTheme?['textColor'] ?? const Color(0xFF880E4F)),
                      onPressed: viewModel.cancelPosting,
                    )
                  : null,
              title: isEditing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.waveform_path, color: currentTheme?['primary'] ?? const Color(0xFFE91E63), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'PANKET',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: currentTheme?['textColor'] ?? const Color(0xFF880E4F),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    )
                  : _buildFilterDropdown(context, viewModel),
              centerTitle: true,
              actions: [
                if (!isEditing)
                  IconButton(
                    icon: Icon(
                      viewModel.isListViewMode
                          ? CupertinoIcons.play_circle_fill
                          : CupertinoIcons.list_bullet,
                      color: currentTheme?['textColor'] ?? const Color(0xFF880E4F),
                    ),
                    tooltip: viewModel.isListViewMode ? 'Chuyển sang xem TikTok' : 'Chuyển sang xem danh sách',
                    onPressed: () => viewModel.setListViewMode(!viewModel.isListViewMode),
                  ),
                IconButton(
                  icon: Icon(CupertinoIcons.settings, color: currentTheme?['textColor'] ?? const Color(0xFF880E4F)),
                  onPressed: () => _showSettingsSheet(context, viewModel),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Switcher (Chỉ hiển thị khi đang ở màn hình chính)
                  if (!isEditing) _buildProfileSwitcher(viewModel),

                  if (viewModel.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Text(
                        viewModel.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  Expanded(
                    child: isEditing
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                            child: _PostEditor(viewModel: viewModel),
                          )
                        : (viewModel.isListViewMode
                            ? SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                child: _buildLocketCameraView(context, viewModel),
                              )
                            : _buildTikTokFeedView(context, viewModel)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// MÀN HÌNH CHÍNH: Camera, Bộ lọc và Timeline cuộn dọc
  Widget _buildLocketCameraView(BuildContext context, LocketViewModel viewModel) {
    // Lấy theme màu theo người dùng hiện tại
    final userTheme = viewModel.userThemes[viewModel.currentUserId];
    final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = userTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = userTheme?['textColor'] ?? const Color(0xFFC2185B);

    // Responsive sizes
    final screenW = MediaQuery.of(context).size.width;
    final cameraSize = (screenW * 0.55).clamp(220.0, 380.0);
    final captureSize = (screenW * 0.15).clamp(60.0, 90.0);
    final cameraIconSize = (cameraSize * 0.22).clamp(40.0, 80.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        
        // Vòng tròn Camera Viewfinder Placeholder (màu theo theme người dùng)
        Center(
          child: GestureDetector(
            onTap: () => viewModel.pickImage(ImageSource.camera),
            child: Container(
              width: cameraSize,
              height: cameraSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryColor.withOpacity(0.8),
                border: Border.all(color: themeColor.withOpacity(0.3), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    CupertinoIcons.camera_fill,
                    color: themeColor.withOpacity(0.4),
                    size: cameraIconSize,
                  ),
                  Positioned(
                    bottom: cameraSize * 0.14,
                    child: Text(
                      'BẤM ĐỂ CHỤP ẢNH',
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Hàng nút điều khiển camera
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 48), // Giữ cân bằng
            
            // Nút Chụp ảnh chính (Nút tròn theo theme người dùng)
            GestureDetector(
              onTap: () => viewModel.pickImage(ImageSource.camera),
              child: Container(
                width: captureSize,
                height: captureSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nút Chọn ảnh từ Gallery
            IconButton(
              onPressed: () => viewModel.pickImage(ImageSource.gallery),
              icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                foregroundColor: textColor,
                minimumSize: const Size(48, 48),
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Locket Feed của bạn bè & bản thân ( timeline cuộn dọc )
        if (viewModel.isListViewMode) ...[
          _buildShareHistoryFeed(viewModel),
          const SizedBox(height: 24),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  /// Bộ chuyển đổi tài khoản nhanh để kiểm thử
  Widget _buildProfileSwitcher(LocketViewModel viewModel) {
    return Container(
      color: Colors.white.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: Color(0xFF880E4F), size: 18),
          const SizedBox(width: 6),
          const Text(
            'Vai trò:',
            style: TextStyle(color: Color(0xFF880E4F), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: viewModel.users.map((user) {
                  final isSelected = user['id'] == viewModel.currentUserId;
                  final userTheme = viewModel.userThemes[user['id']];
                  final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);

                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(
                        user['name']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : const Color(0xFF880E4F),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: themeColor,
                      backgroundColor: Colors.white.withOpacity(0.6),
                      onSelected: (_) => viewModel.changeCurrentUser(user['id']!),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Locket Feed: Danh sách bài viết cuộn dọc
  Widget _buildShareHistoryFeed(LocketViewModel viewModel) {
    final posts = viewModel.filteredPosts;

    if (posts.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Chưa có bài đăng nào. Hãy chia sẻ khoảnh khắc đầu tiên! ✨',
            style: TextStyle(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: posts.map((post) {
        return _buildPolaroidPostCard(viewModel, post);
      }).toList(),
    );
  }

  /// Chip bộ lọc
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF880E4F),
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: Colors.white.withOpacity(0.6),
        onSelected: (_) => onTap(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
  Widget _buildFilterDropdown(BuildContext context, LocketViewModel viewModel) {
    final selectedUser = viewModel.selectedFilterUserId == null
        ? null
        : viewModel.users.firstWhere((u) => u['id'] == viewModel.selectedFilterUserId, orElse: () => {});
    final String currentFilterName = selectedUser != null ? (selectedUser['name'] ?? '') : 'Tất cả 🌸';

    final userTheme = viewModel.selectedFilterUserId == null
        ? null
        : viewModel.userThemes[viewModel.selectedFilterUserId];
    final Color textColor = userTheme?['textColor'] ?? const Color(0xFF880E4F);

    return PopupMenuButton<String?>(
      onSelected: (String? userId) {
        viewModel.setFilterUserId(userId);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black12),
      ),
      color: const Color(0xFFFFF8F9),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.waveform_path, color: Color(0xFFE91E63), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                currentFilterName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: textColor,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_down, color: textColor, size: 12),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: const [
                Icon(CupertinoIcons.globe, color: Color(0xFF880E4F), size: 18),
                SizedBox(width: 8),
                Text(
                  'Tất cả bài đăng 🌸',
                  style: TextStyle(fontSize: 12, color: Color(0xFF880E4F), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...viewModel.users.map((user) {
            final userTheme = viewModel.userThemes[user['id']];
            final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);
            final Color itemTextColor = userTheme?['textColor'] ?? const Color(0xFFC2185B);
            
            return PopupMenuItem<String?>(
              value: user['id'],
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user['name']!,
                    style: TextStyle(fontSize: 12, color: itemTextColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ];
      },
    );
  }

  Widget _buildTikTokFeedView(BuildContext context, LocketViewModel viewModel) {
    final posts = viewModel.filteredPosts;

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: posts.length + 1,
      onPageChanged: (index) {
        if (index == 0) {
          viewModel.stopAudio();
        } else {
          final post = posts[index - 1];
          viewModel.startAudioForPost(post);
        }
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          // Trang 0: Camera Viewfinder và các nút
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              children: [
                _buildLocketCameraView(context, viewModel),
                const SizedBox(height: 24),
                // Banner Bouncing / Hướng dẫn vuốt xuống
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(CupertinoIcons.chevron_compact_down, color: Color(0xFF880E4F), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'VUỐT XUỐNG ĐỂ XEM LOCKET BẠN BÈ',
                      style: TextStyle(
                        color: Color(0xFF880E4F),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(CupertinoIcons.chevron_compact_down, color: Color(0xFF880E4F), size: 24),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        } else {
          // Trang 1..N: Bài viết dạng TikTok (100vh)
          final post = posts[index - 1];
          return _buildTikTokPostPage(context, viewModel, post, index, posts.length);
        }
      },
    );
  }

  Widget _buildTikTokPostPage(
    BuildContext context,
    LocketViewModel viewModel,
    PostModel post,
    int index,
    int total,
  ) {
    final screenW = MediaQuery.of(context).size.width;
    final tikTokImgSize = (screenW * 0.6).clamp(200.0, 400.0);
    final tikTokTapeW = (tikTokImgSize * 0.29).clamp(50.0, 90.0);
    final tikTokTapeH = (tikTokImgSize * 0.075).clamp(14.0, 22.0);
    final senderTheme = viewModel.userThemes[post.senderId];
    final Color themeColor = senderTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = senderTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = senderTheme?['textColor'] ?? const Color(0xFFC2185B);
    final timeAgo = _formatTimestamp(post.timestamp);

    final isPlaying = viewModel.isPlaying && viewModel.audioPath == post.audioUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Nền mờ ảo ảnh (Blurred Background)
        Image.network(
          post.imageUrl,
          fit: BoxFit.cover,
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: secondaryColor.withOpacity(0.85),
            ),
          ),
        ),

        // 2. Nội dung chính
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Thẻ Polaroid phong cách TikTok lớn
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: themeColor.withOpacity(0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Polaroid: Tên, avatar, time
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: themeColor,
                            ),
                            child: Center(
                              child: Text(
                                post.senderName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.senderName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  timeAgo,
                                  style: const TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          
                          // Nút bật/tắt/phát lại âm thanh nhỏ gọn ở tiêu đề
                          if (post.audioUrl.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                if (isPlaying) {
                                  viewModel.stopAudio();
                                } else {
                                  viewModel.startAudioForPost(post);
                                }
                              },
                              icon: Icon(
                                isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                                color: themeColor,
                                size: 24,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),

                      // Ảnh Polaroid lớn đính băng keo dán chéo
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: tikTokImgSize,
                            height: tikTokImgSize,
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: themeColor.withOpacity(0.15), width: 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                post.imageUrl,
                                width: tikTokImgSize,
                                height: tikTokImgSize,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Băng keo trên
                          Positioned(
                            top: -8,
                            child: Transform.rotate(
                              angle: -0.08,
                              child: Container(
                                width: tikTokTapeW,
                                height: tikTokTapeH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8BBD0).withOpacity(0.85),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Băng keo dưới
                          Positioned(
                            bottom: -8,
                            child: Transform.rotate(
                              angle: 0.1,
                              child: Container(
                                width: tikTokTapeW,
                                height: tikTokTapeH,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB3E5FC).withOpacity(0.85),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Lời nhắn Polaroid viết tay
                      if (post.caption.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            post.caption,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: textColor,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Text cảm xúc nếu có
                      if (post.audioUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        
                        // Sóng nhạc micro-animation (ghim kích thước cố định để tránh đẩy/nảy khung hình)
                        SizedBox(
                          height: 36,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(15, (barIdx) {
                              final double pulseValue = isPlaying
                                  ? (10 + (25 * (0.3 + 0.7 * (1.0 - ((viewModel.playbackProgress + barIdx * 7) % 30) / 30.0))))
                                  : 6.0;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 5,
                                height: pulseValue,
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                        
                        const SizedBox(height: 12),

                        // Thanh tiến trình phát
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 200,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: isPlaying ? (viewModel.playbackProgress / 100) : 0.0,
                              backgroundColor: themeColor.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Bài viết chỉ đính kèm ảnh 📸',
                          style: TextStyle(color: Colors.black26, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  /// THẺ BÀI ĐĂNG POLAROID (Thiết kế gọn, đồng nhất với TikTok View)
  Widget _buildPolaroidPostCard(LocketViewModel viewModel, PostModel post) {
    final senderTheme = viewModel.userThemes[post.senderId];
    final Color themeColor = senderTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = senderTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = senderTheme?['textColor'] ?? const Color(0xFFC2185B);
    
    final isMyPost = post.senderId == viewModel.currentUserId;
    final timeAgo = _formatTimestamp(post.timestamp);
    final isPlaying = viewModel.isPlaying && viewModel.audioPath == post.audioUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeColor.withOpacity(0.15), width: 2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER: Avatar + Tên + Thời gian + Nút phát nhạc
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeColor,
                ),
                child: Center(
                  child: Text(
                    post.senderName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.senderName + (isMyPost ? ' (Bạn)' : ''),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Nút phát nhạc nhỏ gọn (giống TikTok view)
              if (post.audioUrl.isNotEmpty)
                IconButton(
                  onPressed: () {
                    if (isPlaying) {
                      viewModel.stopAudio();
                    } else {
                      viewModel.playPostAudio(post);
                    }
                  },
                  icon: Icon(
                    isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                    color: themeColor,
                    size: 28,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // CENTER: Ảnh vuông Polaroid đính băng keo
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeColor.withOpacity(0.15), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.imageUrl,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Băng keo trên
                Positioned(
                  top: -8,
                  child: Transform.rotate(
                    angle: -0.08,
                    child: Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Băng keo dưới
                Positioned(
                  bottom: -8,
                  child: Transform.rotate(
                    angle: 0.1,
                    child: Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Color.lerp(themeColor, Colors.white, 0.6)!.withOpacity(0.6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Lời nhắn viết tay
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                post.caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: textColor,
                  fontFamily: 'Outfit',
                ),
              ),
            ),

          // Sóng nhạc mini khi đang phát (đồng bộ với TikTok view)
          if (post.audioUrl.isNotEmpty && isPlaying) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(15, (barIdx) {
                  final double pulseValue = 6 + (16 * (0.3 + 0.7 * (1.0 - ((viewModel.playbackProgress + barIdx * 7) % 30) / 30.0)));
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: pulseValue,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }



  void _showSettingsSheet(BuildContext context, LocketViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF8F9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _SettingsSheetContent(viewModel: viewModel);
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return '${diff.inDays} ngày trước';
    }
  }
}

/// MÀN HÌNH ĐĂNG BÀI: Chọn nhạc, viết TTS, chọn cảm xúc, nghe thử và Đăng
class _PostEditor extends StatefulWidget {
  final LocketViewModel viewModel;
  const _PostEditor({required this.viewModel});

  @override
  State<_PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<_PostEditor> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.viewModel.textInput);
  }

  @override
  void didUpdateWidget(covariant _PostEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel.textInput.isEmpty && _textController.text.isNotEmpty) {
      _textController.text = '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final userTheme = viewModel.userThemes[viewModel.currentUserId];
    final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = userTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = userTheme?['textColor'] ?? const Color(0xFFC2185B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ảnh tròn xem trước lớn Polaroid
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: themeColor, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          viewModel.imagePath!,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(viewModel.imagePath!),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              // BĂNG KEO HỒNG SỌC (ở cạnh trên)
              Positioned(
                top: -8,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8BBD0).withOpacity(0.85),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // BĂNG KEO XANH PASTEL (ở cạnh dưới)
              Positioned(
                bottom: -8,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3E5FC).withOpacity(0.85),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // LỜI NHẮN (Caption) - Luôn hiển thị
        Text(
          'LỜI NHẮN (TỐI ĐA 100 KÝ TỰ)',
          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextField(
          maxLength: 100,
          maxLines: 2,
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'Nhập nội dung lời nhắn đi kèm ảnh...',
            hintStyle: const TextStyle(color: Colors.black26),
            filled: true,
            fillColor: Colors.white,
            counterStyle: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: themeColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: viewModel.setTextInput,
        ),

        const SizedBox(height: 16),

        // Bảng thiết lập Audio/TTS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: themeColor.withOpacity(0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Switch Bật/Tắt âm thanh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.volume_up, color: themeColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Đính kèm âm thanh',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  CupertinoSwitch(
                    activeColor: themeColor,
                    value: viewModel.isAudioOptionEnabled,
                    onChanged: viewModel.setAudioOptionEnabled,
                  ),
                ],
              ),

              if (viewModel.isAudioOptionEnabled) ...[
                const Divider(color: Colors.black12, height: 24),
                
                Text(
                  'NGUỒN ÂM THANH',
                  style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Giọng đọc AI 🎙️', style: TextStyle(fontSize: 11)),
                      selected: viewModel.audioType == 'TTS',
                      onSelected: (_) => viewModel.setAudioType('TTS'),
                      selectedColor: themeColor,
                      labelStyle: TextStyle(color: viewModel.audioType == 'TTS' ? Colors.white : textColor, fontWeight: FontWeight.bold),
                      backgroundColor: secondaryColor.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Nhạc nền mẫu 🎵', style: TextStyle(fontSize: 11)),
                      selected: viewModel.audioType == 'MUSIC',
                      onSelected: (_) => viewModel.setAudioType('MUSIC'),
                      selectedColor: themeColor,
                      labelStyle: TextStyle(color: viewModel.audioType == 'MUSIC' ? Colors.white : textColor, fontWeight: FontWeight.bold),
                      backgroundColor: secondaryColor.withOpacity(0.5),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (viewModel.audioType == 'TTS') ...[
                  Text(
                    'CẢM XÚC GIỌNG ĐỌC',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildEmotionChip('Normal', 'Tự nhiên'),
                      _buildEmotionChip('Happy', 'Vui 😄'),
                      _buildEmotionChip('Whisper', 'Thì thầm 🤫'),
                      _buildEmotionChip('Sad', 'Buồn 😔'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Nút Nghe thử TTS
                  ElevatedButton.icon(
                    onPressed: viewModel.isGenerating ? null : viewModel.generateVoice,
                    icon: viewModel.isGenerating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: themeColor),
                          )
                        : const Icon(CupertinoIcons.play_arrow_solid, size: 14),
                    label: Text(
                      viewModel.isGenerating ? 'ĐANG TẠO GIỌNG NÓI...' : 'NGHE THỬ GIỌNG NÓI',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: textColor,
                      disabledBackgroundColor: Colors.black12,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      side: BorderSide(color: themeColor.withOpacity(0.3)),
                    ),
                  ),
                ] else ...[
                  Text(
                    'CHỌN BÀI NHẠC NỀN',
                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(viewModel.sampleSongs.length, (idx) {
                        final song = viewModel.sampleSongs[idx];
                        final isSelected = viewModel.selectedMusicIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(song['name']!, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (_) => viewModel.setSelectedMusicIndex(idx),
                            selectedColor: themeColor,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            backgroundColor: secondaryColor.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Nút Nghe thử Nhạc
                  ElevatedButton.icon(
                    onPressed: viewModel.togglePlaySimulation,
                    icon: Icon(viewModel.isPlaying ? CupertinoIcons.pause : CupertinoIcons.play_arrow_solid, size: 14),
                    label: Text(
                      viewModel.isPlaying ? 'TẠM DỪNG NHẠC' : 'NGHE THỬ NHẠC NỀN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: textColor,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      side: BorderSide(color: themeColor.withOpacity(0.3)),
                    ),
                  ),
                ],

                // Phát âm thanh review (Hiển thị chung cho cả 2 loại)
                if (viewModel.isVoiceGenerated && viewModel.audioPath != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: viewModel.togglePlaySimulation,
                          icon: Icon(
                            viewModel.isPlaying
                                ? CupertinoIcons.pause_circle_fill
                                : CupertinoIcons.play_circle_fill,
                            size: 28,
                            color: themeColor,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: viewModel.playbackProgress / 100,
                              backgroundColor: Colors.white,
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sẵn sàng (Max 30s)',
                          style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: (viewModel.isGenerating)
              ? null
              : (viewModel.isAudioOptionEnabled && !viewModel.isVoiceGenerated
                  ? null
                  : viewModel.shareWithFriends),
          icon: const Icon(CupertinoIcons.paperplane_fill, size: 16),
          label: const Text('Xác nhận'),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black12,
            disabledForegroundColor: Colors.black26,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            elevation: 2,
          ),
        ),
        
        if (viewModel.isAudioOptionEnabled && !viewModel.isVoiceGenerated)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              viewModel.audioType == 'TTS'
                  ? '⚠️ Vui lòng nhấn "Nghe thử giọng nói" để tạo âm thanh trước khi đăng!'
                  : '⚠️ Vui lòng chọn bài nhạc nền trước khi đăng!',
              style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 10),

        OutlinedButton(
          onPressed: viewModel.cancelPosting,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black45,
            side: const BorderSide(color: Colors.black12),
            minimumSize: const Size.fromHeight(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Hủy chụp ảnh'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmotionChip(String value, String label) {
    final viewModel = widget.viewModel;
    final userTheme = viewModel.userThemes[viewModel.currentUserId];
    final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = userTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = userTheme?['textColor'] ?? const Color(0xFFC2185B);
    
    final isSelected = viewModel.selectedEmotion == value;
    return InkWell(
      onTap: () => viewModel.setSelectedEmotion(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : secondaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? themeColor : Colors.black12, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

/// Widget cho cấu hình ElevenLabs API Key & Voice ID
class _SettingsSheetContent extends StatefulWidget {
  final LocketViewModel viewModel;
  const _SettingsSheetContent({required this.viewModel});

  @override
  State<_SettingsSheetContent> createState() => _SettingsSheetContentState();
}

class _SettingsSheetContentState extends State<_SettingsSheetContent> {
  late TextEditingController _apiKeyController;
  late TextEditingController _voiceIdController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.viewModel.elevenLabsApiKey);
    _voiceIdController = TextEditingController(text: widget.viewModel.elevenLabsVoiceId);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _voiceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CẤU HÌNH API ELEVENLABS',
                style: TextStyle(
                  color: Color(0xFF880E4F),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.black26, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Mặc định là "mock" để chạy giả lập âm thanh offline. Nhập API Key và Voice ID của bạn để dùng giọng ElevenLabs thực tế.',
            style: TextStyle(color: Colors.black38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          // Trường nhập API Key
          const Text(
            'ELEVENLABS API KEY',
            style: TextStyle(color: Color(0xFF880E4F), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            obscureText: true,
            controller: _apiKeyController,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhập ElevenLabs API Key',
              hintStyle: const TextStyle(color: Colors.black26),
              prefixIcon: const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.black26),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: widget.viewModel.setApiKey,
          ),
          const SizedBox(height: 14),
          // Trường nhập Voice ID
          const Text(
            'ELEVENLABS VOICE ID (ID GIỌNG NÓI)',
            style: TextStyle(color: Color(0xFF880E4F), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _voiceIdController,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhập ElevenLabs Voice ID',
              hintStyle: const TextStyle(color: Colors.black26),
              prefixIcon: const Icon(CupertinoIcons.waveform, size: 16, color: Colors.black26),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: widget.viewModel.setVoiceId,
          ),
        ],
      ),
    );
  }
}
