import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:panket/viewmodels/locket_viewmodel.dart';
import 'package:panket/services/firebase_service.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Sleek, modern dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161A),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(CupertinoIcons.waveform_path, color: Color(0xFFFFD54F), size: 24),
            SizedBox(width: 8),
            Text(
              'PANKET',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.white,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Consumer<LocketViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Profile Switcher (Chuyển đổi tài khoản mô phỏng)
                _buildProfileSwitcher(viewModel),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (viewModel.errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              viewModel.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // 2. Khung hiển thị Locket Preview
                        _buildLocketPreviewCard(viewModel),

                        const SizedBox(height: 20),

                        // 3. Tạo giọng nói AI ElevenLabs
                        _buildAudioConfigPanel(context, viewModel),

                        const SizedBox(height: 20),

                        // 4. Lịch sử bài đăng nhóm bạn bè (Feed)
                        _buildShareHistoryFeed(viewModel),

                        const SizedBox(height: 20),

                        // 5. Trạng thái Widget hiện tại
                        _buildWidgetStatusPanel(viewModel),

                        const SizedBox(height: 20),

                        // 6. Trình giả lập Silent Push (FCM Debug Console)
                        _buildFCMDebugConsole(viewModel),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Bộ chuyển đổi tài khoản nhanh để kiểm thử realtime
  Widget _buildProfileSwitcher(LocketViewModel viewModel) {
    return Container(
      color: const Color(0xFF16161A),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: Colors.white60, size: 18),
          const SizedBox(width: 6),
          const Text(
            'Vai trò:',
            style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: viewModel.users.map((user) {
                  final isSelected = user['id'] == viewModel.currentUserId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(
                        user['name']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFFD54F),
                      backgroundColor: const Color(0xFF282830),
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

  Widget _buildLocketPreviewCard(LocketViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Locket Circular Frame
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF222228),
              border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: ClipOval(
              child: viewModel.imagePath != null
                  ? (kIsWeb
                      ? Image.network(
                          viewModel.imagePath!,
                          fit: BoxFit.cover,
                          width: 180,
                          height: 180,
                        )
                      : Image.file(
                          File(viewModel.imagePath!),
                          fit: BoxFit.cover,
                          width: 180,
                          height: 180,
                        ))
                  : const Center(
                      child: Icon(
                        CupertinoIcons.camera_fill,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Camera & Gallery
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => viewModel.pickImage(ImageSource.camera),
                icon: const Icon(CupertinoIcons.camera, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF282830),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () => viewModel.pickImage(ImageSource.gallery),
                icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF282830),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
              ),
            ],
          ),

          if (viewModel.audioPath != null) ...[
            const SizedBox(height: 12),
            // Simulated player
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF222228),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: viewModel.togglePlaySimulation,
                    icon: Icon(
                      viewModel.isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                      size: 32,
                      color: const Color(0xFFFFD54F),
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
                        backgroundColor: const Color(0xFF2E2E38),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Giọng nói sẵn sàng', style: TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary Actions: Share or Update Locally
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: viewModel.imagePath != null ? viewModel.shareWithFriends : null,
                icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
                label: const Text('CHIA SẺ LÊN LOCKET CLOUD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white24,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: viewModel.imagePath != null ? viewModel.updateWidget : null,
                icon: const Icon(CupertinoIcons.device_phone_portrait, size: 16),
                label: const Text('Cập nhật widget cục bộ (Offline)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white10),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioConfigPanel(BuildContext context, LocketViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TẠO GIỌNG NÓI AI (ELEVENLABS)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // ElevenLabs API Key
          TextField(
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhập ElevenLabs API Key',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(CupertinoIcons.lock_fill, size: 16, color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF222228),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: viewModel.setApiKey,
          ),

          const SizedBox(height: 10),

          // Text to Speak Input
          TextField(
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Nhập nội dung AI phát âm (nhúng tag [laughs], [sigh]...).',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: const Color(0xFF222228),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: viewModel.setTextInput,
          ),

          const SizedBox(height: 12),

          // Generate AI Voice Button
          ElevatedButton(
            onPressed: viewModel.isGenerating ? null : viewModel.generateVoice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF282830),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white10,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: viewModel.isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SINH GIỌNG NÓI AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// Section hiển thị Lịch sử chia sẻ nhóm Locket
  Widget _buildShareHistoryFeed(LocketViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BÀI ĐĂNG CỦA BẠN BÈ (LOCKET FEED)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FirebaseService.isSimulationMode
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  FirebaseService.isSimulationMode ? 'GIẢ LẬP' : 'FIREBASE CLOUD',
                  style: TextStyle(
                    color: FirebaseService.isSimulationMode ? Colors.orangeAccent : Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (viewModel.postsFeed.isEmpty)
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF222228),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Chưa có bài đăng nào. Hãy chụp ảnh và chia sẻ đầu tiên!',
                  style: TextStyle(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: viewModel.postsFeed.length,
                itemBuilder: (context, index) {
                  final post = viewModel.postsFeed[index];
                  final isMyPost = post.senderId == viewModel.currentUserId;
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222228),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMyPost ? const Color(0xFFFFD54F).withValues(alpha: 0.3) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => viewModel.playPostAudio(post),
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              post.imageUrl,
                              width: 100,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Overlay Gradient
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Content Info
                          Positioned(
                            bottom: 6,
                            left: 6,
                            right: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.senderName,
                                  style: TextStyle(
                                    color: isMyPost ? const Color(0xFFFFD54F) : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                if (post.audioUrl.isNotEmpty)
                                  const Row(
                                    children: [
                                      Icon(CupertinoIcons.volume_up, color: Color(0xFFFFD54F), size: 10),
                                      SizedBox(width: 2),
                                      Text(
                                        'Play AI',
                                        style: TextStyle(color: Colors.white70, fontSize: 8),
                                      )
                                    ],
                                  )
                                else
                                  const Text('Chỉ ảnh', style: TextStyle(color: Colors.white30, fontSize: 8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWidgetStatusPanel(LocketViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'TRẠNG THÁI LOCKET WIDGET HIỆN TẠI',
            style: TextStyle(
              color: Color(0xFFFFD54F),
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Ảnh Widget:', viewModel.currentWidgetImage ?? 'Trống'),
          const Divider(color: Colors.white10),
          _buildInfoRow('Nhạc Widget:', viewModel.currentWidgetAudio ?? 'Trống'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFCMDebugConsole(LocketViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.play_rectangle_fill, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'MÔ PHỎNG PUSH NHẬN ĐA PHƯƠNG TIỆN NGẦM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Giả lập Silent Push cập nhật ngầm widget của tài khoản hiện tại từ dữ liệu bạn bè.',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: viewModel.isGenerating
                ? null
                : () => viewModel.simulateFCMReceived(
                      'https://picsum.photos/400/400', // Link ảnh ngẫu nhiên
                      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Link file nhạc mẫu
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
              foregroundColor: Colors.redAccent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
            ),
            child: const Text('GIẢ LẬP NHẬN SILENT PUSH'),
          ),
        ],
      ),
    );
  }
}
