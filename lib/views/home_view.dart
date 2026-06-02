// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui' show ImageFilter, PointMode;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:panket/viewmodels/locket_viewmodel.dart';
import 'package:panket/models/post_model.dart';
import 'package:panket/views/widgets/camera_viewfinder.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocketViewModel>(
      builder: (context, viewModel, child) {
        final isEditing = viewModel.imagePath != null;
        final isNam = viewModel.themeMode == 'NAM';

        // Lấy theme nền theo user hiện tại
        final currentTheme = viewModel.userThemes[viewModel.currentUserId];
        
        final Color bgPrimary = isNam
            ? const Color(0xFF141313)
            : (currentTheme?['secondary'] ?? const Color(0xFFFFF0F2));
        final Color bgSecondary = isNam
            ? const Color(0xFF0E0E0E)
            : (Color.lerp(currentTheme?['primary'] ?? const Color(0xFFF48FB1), Colors.white, 0.88) ?? const Color(0xFFF6ECFC));

        final Color appBarIconColor = isNam
            ? const Color(0xFFFFB300)
            : (currentTheme?['textColor'] ?? const Color(0xFF880E4F));

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
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
                  backgroundColor: isNam ? const Color(0xFF141313).withOpacity(0.9) : Colors.white.withOpacity(0.4),
                  elevation: 0,
                  leading: isEditing
                      ? IconButton(
                          icon: Icon(CupertinoIcons.left_chevron, color: appBarIconColor),
                          onPressed: viewModel.cancelPosting,
                        )
                      : null,
                  title: isEditing
                      ? (isNam
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'REC',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white60, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                                SizedBox(width: 4),
                                _BlinkingDot(),
                                SizedBox(width: 14),
                                Text(
                                  'PANKET',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            )
                          : Row(
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
                            ))
                      : _buildFilterDropdown(context, viewModel),
                  centerTitle: true,
                  actions: [
                    // Nút chuyển đổi giao diện nhanh (🌸 / ⚡)
                    IconButton(
                      icon: Text(
                        isNam ? '⚡' : '🌸',
                        style: const TextStyle(fontSize: 18),
                      ),
                      tooltip: isNam ? 'Chuyển sang phong cách Nữ (Pastel)' : 'Chuyển sang phong cách Nam (Retro Noir)',
                      onPressed: viewModel.toggleThemeMode,
                    ),
                    if (!isEditing)
                      IconButton(
                        icon: Icon(
                          viewModel.isListViewMode
                              ? CupertinoIcons.play_circle_fill
                              : CupertinoIcons.list_bullet,
                          color: appBarIconColor,
                        ),
                        tooltip: viewModel.isListViewMode ? 'Chuyển sang xem Feed' : 'Chuyển sang xem danh sách',
                        onPressed: () => viewModel.setListViewMode(!viewModel.isListViewMode),
                      ),
                    IconButton(
                      icon: Icon(CupertinoIcons.settings, color: appBarIconColor),
                      onPressed: () => _showSettingsSheet(context, viewModel),
                    ),
                  ],
                ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Profile Switcher (Chỉ hiển thị khi đang ở màn hình chính) - Tạm ẩn theo yêu cầu thiết kế
                  // if (!isEditing) _buildProfileSwitcher(viewModel),

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
                        ? LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _PostEditor(viewModel: viewModel),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : (viewModel.isListViewMode
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildLocketCameraView(context, viewModel),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _buildTikTokFeedView(context, viewModel)),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isNam) const NoiseOverlay(),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        
        CameraViewfinder(
          themeColor: themeColor,
          textColor: textColor,
          secondaryColor: secondaryColor,
          themeMode: viewModel.themeMode,
          onImageCaptured: (rawPath, zoom, cameras, selectedCameraIndex) {
            viewModel.startAsynchronousImageProcessing(
              rawPath: rawPath,
              themeMode: viewModel.themeMode,
              secondaryColor: secondaryColor,
              displayZoom: zoom,
              cameras: cameras,
              selectedCameraIndex: selectedCameraIndex,
            );
          },
          onGalleryPicked: () => viewModel.pickImage(ImageSource.gallery),
        ),

        const SizedBox(height: 24),

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
  // ignore: unused_element
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

  Widget _buildFilterDropdown(BuildContext context, LocketViewModel viewModel) {
    final isNam = viewModel.themeMode == 'NAM';
    final selectedUser = viewModel.selectedFilterUserId == null
        ? null
        : viewModel.users.firstWhere((u) => u['id'] == viewModel.selectedFilterUserId, orElse: () => {});
    final String currentFilterName = selectedUser != null ? (selectedUser['name'] ?? '') : (isNam ? 'Tất cả ⚡' : 'Tất cả 🌸');

    final userTheme = viewModel.selectedFilterUserId == null
        ? null
        : viewModel.userThemes[viewModel.selectedFilterUserId];
    
    final Color textColor = isNam
        ? const Color(0xFFFFB300)
        : (userTheme?['textColor'] ?? const Color(0xFF880E4F));

    return PopupMenuButton<String?>(
      onSelected: (String? userId) {
        viewModel.setFilterUserId(userId);
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isNam ? 0 : 16),
        side: BorderSide(color: isNam ? const Color(0xFF353434) : Colors.black12, width: isNam ? 1.5 : 1.0),
      ),
      color: isNam ? const Color(0xFF141313) : const Color(0xFFFFF8F9),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isNam ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(isNam ? 4 : 20),
          border: Border.all(color: textColor.withOpacity(isNam ? 0.4 : 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isNam ? CupertinoIcons.square_list_fill : CupertinoIcons.waveform_path, color: isNam ? const Color(0xFFFFB300) : const Color(0xFFE91E63), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                currentFilterName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isNam ? Colors.white : textColor,
                  fontSize: 12,
                  fontFamily: isNam ? 'monospace' : 'Outfit',
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
              children: [
                Icon(CupertinoIcons.globe, color: isNam ? const Color(0xFFFFB300) : const Color(0xFF880E4F), size: 18),
                const SizedBox(width: 8),
                Text(
                  isNam ? 'Tất cả bài đăng ⚡' : 'Tất cả bài đăng 🌸',
                  style: TextStyle(
                    fontSize: 12,
                    color: isNam ? Colors.white70 : const Color(0xFF880E4F),
                    fontWeight: FontWeight.bold,
                    fontFamily: isNam ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
          ...viewModel.users.map((user) {
            final userTheme = viewModel.userThemes[user['id']];
            final Color themeColor = userTheme?['primary'] ?? const Color(0xFFF48FB1);
            final Color itemTextColor = isNam ? Colors.white70 : (userTheme?['textColor'] ?? const Color(0xFFC2185B));
            
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
                    style: TextStyle(
                      fontSize: 12,
                      color: itemTextColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: isNam ? 'monospace' : null,
                    ),
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
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      allowImplicitScrolling: true,
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
          // Trang 0: Camera Viewfinder và các nút (Căn giữa theo chiều cao)
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                    ),
                  ),
                ),
              );
            },
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
    final isNam = viewModel.themeMode == 'NAM';
    final screenW = MediaQuery.of(context).size.width;
    final tikTokImgSize = (screenW - 80).clamp(220.0, 420.0);
    final tikTokTapeW = (tikTokImgSize * 0.29).clamp(50.0, 90.0);
    final tikTokTapeH = (tikTokImgSize * 0.075).clamp(14.0, 22.0);
    final senderTheme = viewModel.userThemes[post.senderId];
    final Color themeColor = senderTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = senderTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = senderTheme?['textColor'] ?? const Color(0xFFC2185B);
    final timeAgo = _formatTimestamp(post.timestamp);

    final isPlaying = viewModel.isPlaying && viewModel.audioPath == post.audioUrl;

    // Tapes decorations
    final Decoration tapeDecTop = isNam
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0E0E), Color(0xFF2C2A2A), Color(0xFF0F0E0E), Color(0xFF1E1D1D)],
              stops: [0.0, 0.3, 0.7, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3, offset: const Offset(0, 1.5)),
            ],
          )
        : BoxDecoration(
            color: themeColor.withOpacity(0.4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

    final Decoration tapeDecBottom = isNam
        ? tapeDecTop
        : BoxDecoration(
            color: const Color(0xFFB3E5FC).withOpacity(0.85),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

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
              color: isNam ? const Color(0xFF141313).withOpacity(0.7) : secondaryColor.withOpacity(0.85),
            ),
          ),
        ),

        // 2. Nội dung chính
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

              // Thẻ Polaroid phong cách TikTok lớn
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isNam ? const Color(0xFFF7F4EB) : Colors.white,
                    borderRadius: BorderRadius.circular(isNam ? 0 : 24),
                    border: isNam
                        ? Border.all(color: const Color(0xFF1C1B1B).withOpacity(0.12), width: 1.5)
                        : Border.all(color: themeColor.withOpacity(0.3), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: isNam ? Colors.black.withOpacity(0.5) : themeColor.withOpacity(0.15),
                        blurRadius: isNam ? 35 : 25,
                        offset: Offset(0, isNam ? 15 : 12),
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
                              color: isNam ? const Color(0xFF353434) : themeColor,
                            ),
                            child: Center(
                              child: Text(
                                post.senderName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
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
                                    color: isNam ? Colors.black87 : textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: isNam ? 'monospace' : 'Outfit',
                                  ),
                                ),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: isNam ? Colors.black38 : Colors.black26,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: isNam ? 'monospace' : null,
                                  ),
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
                                color: isNam ? const Color(0xFFFFB300) : themeColor,
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
                              color: isNam ? const Color(0xFFE5E2DA) : secondaryColor,
                              borderRadius: BorderRadius.circular(isNam ? 0 : 16),
                              border: Border.all(color: isNam ? Colors.black.withOpacity(0.06) : themeColor.withOpacity(0.15), width: isNam ? 1 : 3),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(isNam ? 0 : 12),
                              child: isNam
                                  ? ColorFiltered(
                                      colorFilter: const ColorFilter.matrix(<double>[
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0,      0,      0,      1, 0,
                                      ]),
                                      child: Image.network(
                                        post.imageUrl,
                                        width: tikTokImgSize,
                                        height: tikTokImgSize,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.network(
                                      post.imageUrl,
                                      width: tikTokImgSize,
                                      height: tikTokImgSize,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          
                          // Equalizer overlay inside image for NAM mode
                          if (isNam && post.audioUrl.isNotEmpty)
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    height: 30, // FIXED height to prevent container visual shaking when bars bounce
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                                    ),
                                    child: _BrutalistEqualizer(
                                      isPlaying: isPlaying,
                                      maxHeight: 20.0,
                                      barWidth: 2.5,
                                      spacing: 1.2,
                                      color: const Color(0xFFFFB300),
                                    ),
                                  ),
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
                                decoration: tapeDecTop,
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
                                decoration: tapeDecBottom,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Lời nhắn Polaroid
                      if (post.caption.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            post.caption,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: isNam ? Colors.black87 : textColor,
                              fontFamily: isNam ? 'monospace' : 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Specs & Timestamp Row for NAM mode vs Standard Audio Tray for NỮ mode
                      if (isNam) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'EST. 1984',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black38, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                timeAgo.toUpperCase(),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black38, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // NỮ mode: Audio wave progress bars
                        if (post.audioUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          
                          // Sóng nhạc micro-animation
                          SizedBox(
                            height: 36,
                            child: Center(
                              child: _BrutalistEqualizer(
                                isPlaying: isPlaying,
                                maxHeight: 30.0,
                                barWidth: 5.0,
                                spacing: 2.5,
                                color: themeColor,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 112),
            ],
          ),
        ),
      ),
    ),

        // 3. Side Reactions Panel & Floating Response Box (Unified for both themes, styled dynamically)
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            children: ['🔥', '😎', '🖤', '😮'].map((emoji) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Bày tỏ cảm xúc: $emoji",
                          style: TextStyle(
                            fontFamily: isNam ? 'monospace' : 'Outfit',
                            color: isNam ? const Color(0xFFFFB300) : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: isNam ? const Color(0xFF141313) : textColor,
                        duration: const Duration(milliseconds: 600),
                        width: 200,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isNam ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.75),
                      border: Border.all(
                        color: isNam ? Colors.white10 : themeColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isNam ? const Color(0xFFFFB300) : themeColor).withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Translucent Bottom Chat Input Tray (Unified for both themes, styled dynamically)
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isNam ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isNam ? Colors.white.withOpacity(0.08) : themeColor.withOpacity(0.2),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: TextStyle(
                          fontFamily: isNam ? 'monospace' : 'Outfit',
                          color: isNam ? Colors.white : textColor,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: isNam ? 'Type a whisper...' : 'Gửi lời thì thầm...',
                          hintStyle: TextStyle(
                            fontFamily: isNam ? 'monospace' : 'Outfit',
                            color: isNam ? Colors.white30 : textColor.withOpacity(0.45),
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.paperplane_fill,
                        color: isNam ? const Color(0xFFFFB300) : themeColor,
                        size: 18,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isNam ? "Đã gửi phản hồi nhanh!" : "Đã gửi lời nhắn thành công! 💖",
                              style: TextStyle(
                                fontFamily: isNam ? 'monospace' : 'Outfit',
                                color: isNam ? const Color(0xFFFFB300) : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: isNam ? const Color(0xFF141313) : textColor,
                            duration: const Duration(milliseconds: 800),
                            width: isNam ? 220 : 250,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// THẺ BÀI ĐĂNG POLAROID (Thiết kế gọn, đồng nhất với TikTok View)
  Widget _buildPolaroidPostCard(LocketViewModel viewModel, PostModel post) {
    final isNam = viewModel.themeMode == 'NAM';
    final senderTheme = viewModel.userThemes[post.senderId];
    final Color themeColor = senderTheme?['primary'] ?? const Color(0xFFF48FB1);
    final Color secondaryColor = senderTheme?['secondary'] ?? const Color(0xFFFFF0F2);
    final Color textColor = senderTheme?['textColor'] ?? const Color(0xFFC2185B);
    
    final isMyPost = post.senderId == viewModel.currentUserId;
    final timeAgo = _formatTimestamp(post.timestamp);
    final isPlaying = viewModel.isPlaying && viewModel.audioPath == post.audioUrl;

    // Tapes decorations
    final Decoration tapeDecTop = isNam
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0E0E), Color(0xFF2C2A2A), Color(0xFF0F0E0E), Color(0xFF1E1D1D)],
              stops: [0.0, 0.3, 0.7, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3, offset: const Offset(0, 1.5)),
            ],
          )
        : BoxDecoration(
            color: themeColor.withOpacity(0.3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

    final Decoration tapeDecBottom = isNam
        ? tapeDecTop
        : BoxDecoration(
            color: Color.lerp(themeColor, Colors.white, 0.6)!.withOpacity(0.6),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

    // Responsive: dùng LayoutBuilder để lấy constraints thực tế
    return LayoutBuilder(builder: (context, constraints) {
    final cardImgSize = (constraints.maxWidth - 32).clamp(220.0, 420.0);
    final cardTapeW = (cardImgSize * 0.27).clamp(40.0, 80.0);
    final cardTapeH = (cardImgSize * 0.07).clamp(12.0, 20.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNam ? const Color(0xFFF7F4EB) : Colors.white,
        borderRadius: BorderRadius.circular(isNam ? 0 : 20),
        border: Border.all(color: isNam ? const Color(0xFF1C1B1B).withOpacity(0.12) : themeColor.withOpacity(0.15), width: isNam ? 1.5 : 2),
        boxShadow: [
          BoxShadow(
            color: isNam ? Colors.black.withOpacity(0.35) : themeColor.withOpacity(0.08),
            blurRadius: isNam ? 24 : 16,
            offset: Offset(0, isNam ? 10 : 6),
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
                  color: isNam ? const Color(0xFF353434) : themeColor,
                ),
                child: Center(
                  child: Text(
                    post.senderName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
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
                        color: isNam ? Colors.black87 : textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: isNam ? 'monospace' : 'Outfit',
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: isNam ? Colors.black38 : Colors.black26,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: isNam ? 'monospace' : null,
                      ),
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
                    color: isNam ? const Color(0xFFFFB300) : themeColor,
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
                  width: cardImgSize,
                  height: cardImgSize,
                  decoration: BoxDecoration(
                    color: isNam ? const Color(0xFFE5E2DA) : secondaryColor,
                    borderRadius: BorderRadius.circular(isNam ? 0 : 16),
                    border: Border.all(color: isNam ? Colors.black.withOpacity(0.06) : themeColor.withOpacity(0.15), width: isNam ? 1 : 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isNam ? 0 : 12),
                    child: isNam
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      1, 0,
                            ]),
                            child: Image.network(
                              post.imageUrl,
                              width: cardImgSize,
                              height: cardImgSize,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.network(
                            post.imageUrl,
                            width: cardImgSize,
                            height: cardImgSize,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                
                // Equalizer overlay inside image for NAM mode
                if (isNam && post.audioUrl.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          height: 28, // FIXED height to prevent container visual shaking when bars bounce
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                          ),
                          child: _BrutalistEqualizer(
                            isPlaying: isPlaying,
                            maxHeight: 18.0,
                            barWidth: 2.2,
                            spacing: 1.0,
                            color: const Color(0xFFFFB300),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Băng keo trên
                Positioned(
                  top: -8,
                  child: Transform.rotate(
                    angle: -0.08,
                    child: Container(
                      width: cardTapeW,
                      height: cardTapeH,
                      decoration: tapeDecTop,
                    ),
                  ),
                ),
                // Băng keo dưới
                Positioned(
                  bottom: -8,
                  child: Transform.rotate(
                    angle: 0.1,
                    child: Container(
                      width: cardTapeW,
                      height: cardTapeH,
                      decoration: tapeDecBottom,
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
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: isNam ? Colors.black87 : textColor,
                  fontFamily: isNam ? 'monospace' : 'Outfit',
                ),
              ),
            ),

          // Technical Timestamp specs row for NAM mode
          if (isNam) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EST. 1984',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black38, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    timeAgo.toUpperCase(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black38, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Sóng nhạc mini khi đang phát (đồng bộ với TikTok view) - NỮ mode
            if (post.audioUrl.isNotEmpty && isPlaying) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 24,
                child: Center(
                  child: _BrutalistEqualizer(
                    isPlaying: isPlaying,
                    maxHeight: 20.0,
                    barWidth: 3.0,
                    spacing: 1.5,
                    color: themeColor.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
    }); // close LayoutBuilder
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
    final isNam = viewModel.themeMode == 'NAM';
    final userTheme = viewModel.userThemes[viewModel.currentUserId];
    
    final Color themeColor = isNam ? const Color(0xFFFFB300) : (userTheme?['primary'] ?? const Color(0xFFF48FB1));
    final Color secondaryColor = isNam ? const Color(0xFF201F1F) : (userTheme?['secondary'] ?? const Color(0xFFFFF0F2));
    final Color textColor = isNam ? const Color(0xFFFFB300) : (userTheme?['textColor'] ?? const Color(0xFFC2185B));

    final screenW = MediaQuery.of(context).size.width;
    final editorImgSize = (screenW - 48).clamp(220.0, 420.0);
    final editorTapeW = (editorImgSize * 0.27).clamp(40.0, 80.0);
    final editorTapeH = (editorImgSize * 0.07).clamp(12.0, 20.0);

    // Tapes decorations
    final Decoration tapeDecTop = isNam
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0E0E), Color(0xFF2C2A2A), Color(0xFF0F0E0E), Color(0xFF1E1D1D)],
              stops: [0.0, 0.3, 0.7, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 3, offset: const Offset(0, 1.5)),
            ],
          )
        : BoxDecoration(
            color: themeColor.withOpacity(0.4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

    final Decoration tapeDecBottom = isNam
        ? tapeDecTop
        : BoxDecoration(
            color: const Color(0xFFB3E5FC).withOpacity(0.85),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          );

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
                width: editorImgSize,
                height: editorImgSize,
                decoration: BoxDecoration(
                  color: isNam ? const Color(0xFFF7F4EB) : Colors.white,
                  borderRadius: BorderRadius.circular(isNam ? 0 : 16),
                  border: Border.all(color: isNam ? const Color(0xFF1C1B1B).withOpacity(0.12) : themeColor, width: isNam ? 1.5 : 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: isNam ? Colors.black.withOpacity(0.4) : themeColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isNam ? 0 : 12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      isNam
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ]),
                              child: kIsWeb
                                  ? Image.network(
                                      viewModel.imagePath!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(viewModel.imagePath!),
                                      fit: BoxFit.cover,
                                    ),
                            )
                          : (kIsWeb
                              ? Image.network(
                                  viewModel.imagePath!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(viewModel.imagePath!),
                                  fit: BoxFit.cover,
                                )),
                      if (viewModel.isProcessingImage)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.55),
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isNam ? const Color(0xFFFFB300) : themeColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'ĐANG XỬ LÝ ẢNH HD...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          fontFamily: isNam ? 'monospace' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // BĂNG KEO TRÊN
              Positioned(
                top: -8,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: editorTapeW,
                    height: editorTapeH,
                    decoration: tapeDecTop,
                  ),
                ),
              ),
              // BĂNG KEO DƯỚI
              Positioned(
                bottom: -8,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    width: editorTapeW,
                    height: editorTapeH,
                    decoration: tapeDecBottom,
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
          style: TextStyle(
            color: isNam ? Colors.white60 : textColor.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontFamily: isNam ? 'monospace' : null,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          maxLength: 100,
          maxLines: 2,
          style: TextStyle(
            color: isNam ? Colors.white : Colors.black87,
            fontSize: 13,
            fontFamily: isNam ? 'monospace' : null,
          ),
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'Nhập nội dung lời nhắn đi kèm ảnh...',
            hintStyle: TextStyle(color: isNam ? Colors.white30 : Colors.black26, fontSize: 12),
            filled: true,
            fillColor: isNam ? const Color(0xFF201F1F) : Colors.white,
            counterStyle: TextStyle(
              color: isNam ? Colors.white38 : textColor.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: isNam ? 'monospace' : null,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isNam ? 4 : 12),
              borderSide: BorderSide(color: isNam ? const Color(0xFF353434) : Colors.black12, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isNam ? 4 : 12),
              borderSide: BorderSide(color: isNam ? const Color(0xFF353434) : Colors.black12, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isNam ? 4 : 12),
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
            color: isNam ? const Color(0xFF141313) : Colors.white,
            borderRadius: BorderRadius.circular(isNam ? 0 : 24),
            border: Border.all(color: isNam ? const Color(0xFF353434) : themeColor.withOpacity(0.15), width: 1.5),
            boxShadow: isNam ? null : [
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
                          color: isNam ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: isNam ? 'monospace' : null,
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
                Divider(color: isNam ? const Color(0xFF353434) : Colors.black12, height: 24),
                
                Text(
                  'NGUỒN ÂM THANH',
                  style: TextStyle(
                    color: isNam ? Colors.white38 : textColor.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: isNam ? 'monospace' : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Giọng đọc AI 🎙️', style: TextStyle(fontSize: 11, fontFamily: isNam ? 'monospace' : null)),
                      selected: viewModel.audioType == 'TTS',
                      onSelected: (_) => viewModel.setAudioType('TTS'),
                      selectedColor: themeColor,
                      labelStyle: TextStyle(
                        color: viewModel.audioType == 'TTS'
                            ? (isNam ? Colors.black : Colors.white)
                            : (isNam ? Colors.white70 : textColor),
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: secondaryColor.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Nhạc nền mẫu 🎵', style: TextStyle(fontSize: 11, fontFamily: isNam ? 'monospace' : null)),
                      selected: viewModel.audioType == 'MUSIC',
                      onSelected: (_) => viewModel.setAudioType('MUSIC'),
                      selectedColor: themeColor,
                      labelStyle: TextStyle(
                        color: viewModel.audioType == 'MUSIC'
                            ? (isNam ? Colors.black : Colors.white)
                            : (isNam ? Colors.white70 : textColor),
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: secondaryColor.withOpacity(0.5),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (viewModel.audioType == 'TTS') ...[
                  Text(
                    'CẢM XÚC GIỌNG ĐỌC',
                    style: TextStyle(
                      color: isNam ? Colors.white38 : textColor.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: isNam ? 'monospace' : null,
                    ),
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
                        : Icon(CupertinoIcons.play_arrow_solid, size: 14, color: isNam ? Colors.black : textColor),
                    label: Text(
                      viewModel.isGenerating ? 'ĐANG TẠO GIỌNG NÓI...' : 'NGHE THỬ GIỌNG NÓI',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: isNam ? 'monospace' : null),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNam ? const Color(0xFFFFB300) : secondaryColor,
                      foregroundColor: isNam ? Colors.black : textColor,
                      disabledBackgroundColor: Colors.black12,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNam ? 0 : 12)),
                      elevation: 0,
                      side: isNam ? null : BorderSide(color: themeColor.withOpacity(0.3)),
                    ),
                  ),
                ] else ...[
                  Text(
                    'CHỌN BÀI NHẠC NỀN',
                    style: TextStyle(
                      color: isNam ? Colors.white38 : textColor.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: isNam ? 'monospace' : null,
                    ),
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
                            label: Text(song['name']!, style: TextStyle(fontSize: 11, fontFamily: isNam ? 'monospace' : null)),
                            selected: isSelected,
                            onSelected: (_) => viewModel.setSelectedMusicIndex(idx),
                            selectedColor: themeColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (isNam ? Colors.black : Colors.white)
                                  : (isNam ? Colors.white70 : textColor),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
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
                    icon: Icon(viewModel.isPlaying ? CupertinoIcons.pause : CupertinoIcons.play_arrow_solid, size: 14, color: isNam ? Colors.black : textColor),
                    label: Text(
                      viewModel.isPlaying ? 'TẠM DỪNG NHẠC' : 'NGHE THỬ NHẠC NỀN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: isNam ? 'monospace' : null),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNam ? const Color(0xFFFFB300) : secondaryColor,
                      foregroundColor: isNam ? Colors.black : textColor,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNam ? 0 : 12)),
                      elevation: 0,
                      side: isNam ? null : BorderSide(color: themeColor.withOpacity(0.3)),
                    ),
                  ),
                ],

                // Phát âm thanh review (Hiển thị chung cho cả 2 loại)
                if (viewModel.isVoiceGenerated && viewModel.audioPath != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNam ? const Color(0xFF201F1F) : secondaryColor,
                      borderRadius: BorderRadius.circular(isNam ? 0 : 12),
                      border: Border.all(color: isNam ? const Color(0xFF353434) : themeColor.withOpacity(0.2)),
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
                              backgroundColor: isNam ? Colors.black : Colors.white,
                              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sẵn sàng (Max 30s)',
                          style: TextStyle(color: isNam ? Colors.white70 : textColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: isNam ? 'monospace' : null),
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
          icon: viewModel.isGenerating
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isNam ? Colors.black : Colors.white,
                  ),
                )
              : Icon(CupertinoIcons.paperplane_fill, size: 16, color: isNam ? Colors.black : Colors.white),
          label: Text(
            viewModel.isGenerating
                ? (viewModel.isProcessingImage ? 'ĐANG HOÀN THIỆN ẢNH HD...' : 'ĐANG GỬI LOCKET...')
                : 'Xác nhận',
            style: TextStyle(fontFamily: isNam ? 'monospace' : null),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: isNam ? Colors.black : Colors.white,
            disabledBackgroundColor: Colors.black12,
            disabledForegroundColor: Colors.black26,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isNam ? 0 : 16),
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
              style: TextStyle(color: isNam ? const Color(0xFFFFB300) : textColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: isNam ? 'monospace' : null),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 10),

        OutlinedButton(
          onPressed: viewModel.cancelPosting,
          style: OutlinedButton.styleFrom(
            foregroundColor: isNam ? Colors.white60 : Colors.black45,
            side: BorderSide(color: isNam ? const Color(0xFF353434) : Colors.black12),
            minimumSize: const Size.fromHeight(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isNam ? 0 : 12),
            ),
          ),
          child: Text('Hủy chụp ảnh', style: TextStyle(fontFamily: isNam ? 'monospace' : null)),
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

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _NoisePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.012)
      ..strokeWidth = 1.0;

    final r = math.Random(42); 
    for (double x = 0; x < size.width; x += 4) {
      for (double y = 0; y < size.height; y += 4) {
        if (r.nextDouble() < 0.15) {
          canvas.drawPoints(
            PointMode.points,
            [Offset(x + r.nextDouble() * 3, y + r.nextDouble() * 3)],
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrutalistEqualizer extends StatefulWidget {
  final bool isPlaying;
  final double maxHeight;
  final double barWidth;
  final double spacing;
  final Color color;

  const _BrutalistEqualizer({
    required this.isPlaying,
    required this.maxHeight,
    required this.barWidth,
    required this.spacing,
    required this.color,
  });

  @override
  State<_BrutalistEqualizer> createState() => _BrutalistEqualizerState();
}

class _BrutalistEqualizerState extends State<_BrutalistEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const List<double> _baseMultipliers = [
    0.9, 0.3, 0.15, 0.7, 0.8, 0.8, 0.15, 0.35, 1.0, 0.6, 0.25, 0.85, 0.5, 0.15, 0.4
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _BrutalistEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_baseMultipliers.length, (idx) {
            double multiplier = _baseMultipliers[idx];

            if (widget.isPlaying) {
              final double wave = math.sin((_controller.value * 2 * math.pi) + (idx * 0.8));
              multiplier = (multiplier * 0.25) + (multiplier * 0.75 * (0.5 + 0.5 * wave));
            }

            final double height = (widget.maxHeight * multiplier).clamp(2.0, widget.maxHeight);

            return Container(
              width: widget.barWidth,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.barWidth / 2),
              ),
            );
          }),
        );
      },
    );
  }
}
