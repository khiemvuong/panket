# Locket Redesign Project: Summary & Progress Log

Tài liệu này ghi nhận toàn bộ lộ trình, các cải tiến công nghệ và các phase tiến độ giao diện **Panket** (ứng dụng phong cách Locket) đã được thực hiện xuất sắc trong cuộc trò chuyện này. Nó phục vụ như một file ghi nhớ (memory log) cốt lõi để tiếp tục phát triển ở các cuộc trò chuyện tiếp theo.

---

## 📌 PHẦN 1: TÓM TẮT TIẾN ĐỘ & CÁC CẢI TIẾN ĐÃ HOÀN THÀNH

### Phase 1: TikTok-style Vertical Feed & Auto-play Audio (Mặc định)
* **PageView cuộn dọc (100vh):** Triển khai cấu trúc cuộn dọc bằng `PageView.builder` làm trải nghiệm mặc định.
  - **Trang 0 (Màn hình chính):** Viewfinder camera, phím chụp/chọn ảnh, bảng điều khiển trạng thái widget và FCM Console kèm banner bouncing hướng dẫn *"VUỐT XUỐNG ĐỂ XEM LOCKET BẠN BÈ"*.
  - **Trang 1..N (Trang bài viết):** Thiết kế Polaroid chiếm trọn màn hình (100vh). Sử dụng chính bức ảnh làm nền mờ ảo dạng Glassmorphism (`BackdropFilter` blur 20px, phủ màu pastel đồng điệu theo theme người gửi).
* **Tự động phát & Đồng bộ sóng nhạc (Equalizer):**
  - Tự động kích hoạt giọng đọc AI (TTS ElevenLabs) hoặc nhạc nền khi cuộn đến trang bài đăng. Tự động tắt khi vuốt về Trang 0.
  - Tích hợp hàng sóng nhạc equalizer 15 cột nhấp nhô sống động, đồng bộ hóa thời gian thực với tiến trình phát nhạc từ thẻ `<audio>` Web/Mobile, giới hạn cứng thời lượng audio tối đa 30s.
  - Thay thế nút phát lại nhạc cồng kềnh bằng nút điều khiển icon nhỏ gọn `CupertinoIcons.play_circle_fill` đặt tinh tế trên thanh Header của thẻ Polaroid.

### Phase 2: Bộ lọc Dropdown trên AppBar
* **Giải phóng không gian:** Thay thế thanh ChoiceChips cuộn ngang cồng kềnh cũ bằng một menu **Dropdown dạng Popup** ngay giữa AppBar.
* **Đồng bộ theme:** Màu sắc viền và chữ tiêu đề dropdown (ví dụ: *"TẤT CẢ 🌸"*, *"JOHN (B)"*) tự động thay đổi mượt mà theo theme đặc trưng của người dùng đang được lọc.
* **Hỗ trợ danh sách dài:** Tích hợp cơ chế tự động cuộn (Scrollable) tránh tràn viền (overflow) khi danh sách bạn bè scale lên rất dài.

### Phase 3: Căn giữa theo chiều cao (Vertical Centering) & Responsive
* **Căn giữa tuyệt đối:** Sử dụng bộ ba kết hợp `LayoutBuilder`, `ConstrainedBox (minHeight: constraints.maxHeight)` và `IntrinsicHeight` cho:
  - Trang 0 (Camera & hướng dẫn vuốt).
  - Trình chụp ảnh của chế độ danh sách (List View).
  - Trình chỉnh sửa bài viết đang soạn thảo (`_PostEditor`).
  - Giao diện được căn giữa hoàn hảo theo chiều dọc trên các thiết bị màn hình dài (iPhone 12, iPad, v.v.), khắc phục hoàn toàn khoảng trắng trống ở dưới mà không bị lỗi pixel overflow.
* **Polaroid phóng to full-width:** Phóng to toàn bộ hình ảnh Polaroid (trên TikTok feed, Polaroid post card, và `_PostEditor`) ra gần hết chiều ngang màn hình (chỉ chừa padding nhẹ tinh tế) để tối đa trải nghiệm thị giác.

### Phase 4: Trình Camera hình vuông thực tế & Switching Lenses 0.5x
* **Camera vuông 1:1 trực tiếp:** Chuyển đổi camera giả lập tĩnh cũ thành luồng video trực tiếp từ camera phần cứng (`camera` package), tự động crop thành hình vuông 1:1 bằng `FittedBox` + `OverflowBox`.
* **Tự động đổi ống kính 0.5x hệ thống:** 
  - Hệ thống tự động lọc danh sách camera sau của thiết bị. Nếu thiết bị có camera siêu rộng vật lý (ultra-wide), khi kéo zoom dưới 1.0x (ví dụ 0.5x), hệ thống tự động lật (hot-switch) sang camera sau thứ 2 để lấy góc rộng quang học thực tế. Khi kéo lên từ 1.0x, tự động switch lại camera chính.
  - Trên trình duyệt máy tính/thiết bị chỉ có 1 camera, hệ thống kích hoạt chế độ **Virtual Wide-Angle/Digital Zoom** (`Transform.scale` từ 0.5x đến 2.5x kèm khung đệm pastel theo theme), đảm bảo hoạt động cực đẹp trên mọi thiết bị.
* **Đồng bộ ảnh chụp Zoom/Crop 100%:**
  - Tích hợp bộ vẽ đồ họa phần cứng **`dart:ui.Canvas`** để xử lý ảnh chụp trực tiếp từ luồng RAM của `XFile` gốc. 
  - Tự động crop 1:1 chính tâm và co giãn (zoom cận/góc rộng) khớp tuyệt đối so với những gì người dùng đang nhìn trên viewfinder trước khi lưu/đăng bài.
* **Phím chức năng chuyên nghiệp:** Tích hợp đầy đủ Flash (Off / Auto / Always), nút chụp hiển thị loading spinner khi đang crop ảnh, lật camera trước/sau, zoom slider, pinch-to-zoom, và chọn ảnh từ thư viện. Tối ưu băng thông bằng `ResolutionPreset.medium`.

---

## 📅 PHẦN 2: ĐỊNH HƯỚNG PHASE TIẾP THEO (BACKLOG FOR NEXT AGENTS)

### Phase 5: Chuyển đổi Thiết kế sang Phong cách Nam tính (Masculine Neo-Noir Film / Brutalist Monochrome)
* **Ý tưởng thiết kế:** Thay thế phong cách pastel hồng/sáng hiện tại bằng một tùy chọn theme nam tính, cá tính và hiện đại.
* **Bảng màu gợi ý:** Nền đen nhám/than charcoal (`#121212`), xám bê tông mộc, giấy film cổ điển (`#F7F4EB`), kết hợp các điểm nhấn nổi bật bằng màu cam neon hổ phách (`#FFB300`), đồng kim loại hoặc trắng đen tối giản (monochrome).
* **Chi tiết Polaroid:** Miếng băng keo dán ảnh Polaroid chuyển sang dạng giả lập băng dính điện đen, băng keo giấy nhám xám, hoặc băng dính có vân kết cấu gai góc.

### Phase 6: Tính năng Tương tác nhanh & Phản hồi bài viết
* **Bày tỏ cảm xúc nhanh (Quick Reactions):** 
  - Thêm một thanh overlay nhỏ tinh tế ở góc dưới bài đăng Polaroid.
  - Cho phép người dùng chạm nhanh các emoji (🔥, 😎, 🖤, 😮) kèm theo hiệu ứng hạt bay lên (floating particles animation) tỏa ra trên màn hình rất sống động.
* **Hộp thoại phản hồi nhanh (Inline Response Input):**
  - Tích hợp một thanh nhập tin nhắn phản hồi mờ nhẹ (translucent glassmorphism input) ngay dưới thẻ Polaroid.
  - Nhấp vào sẽ mở ra ô nhập tin nhắn và đính kèm giọng nói nhanh cực kỳ tiện lợi mà không cần rời khỏi feed chính.

---

### Phase 7: Tính năng Đăng lại bài viết (Repost Moment)
* **Khung ảnh Polaroid Lồng kép (Double Polaroid Overlay):** Thiết kế thẻ bài đăng lại dưới dạng một tấm Polaroid nhỏ hơn nằm nghiêng đè lên trên tấm Polaroid gốc của tác giả cũ, tạo chiều sâu 3D chân thực.
* **Thông tin nguồn rõ ràng:** Thêm Header Badge tinh tế chỉ định rõ người đăng lại và tác giả gốc (ví dụ: *"Bạn đã repost khoảnh khắc của John (B)"*) với avatar lồng ghép vào nhau.
* **Bảo toàn âm thanh gốc:** Cho phép phát trực tiếp giọng nói/nhạc của bài gốc kèm theo ghi chú (caption) mới viết tay của người repost ở viền dưới.

### Phase 8: Khung Chat riêng tư & Chat nhóm phong cách Retro
* **Chat riêng tư (Dual Chat):** 
  - Khung nhắn tin dạng bong bóng mờ ảo (Glassmorphism), có màu sắc thay đổi động theo theme của người gửi (Hồng pastel cho nữ / Amber charcoal cho nam).
  - Tích hợp phím tắt chụp ảnh/gửi voice nhanh bằng hình tròn giống nút camera mini.
* **Chat nhóm (Group Chat):** 
  - Header của nhóm có avatar ghép xếp chồng (stacked avatars).
  - Tên thành viên trong nhóm hiển thị phía trên bong bóng chat bằng các màu sắc neon cá tính khác nhau để phân biệt.
  - Hỗ trợ phát nhạc nền chung của nhóm (Shared Group Soundtrack) ở góc trên.

---

## 🛠️ PHẦN 3: KIẾN TRÚC TỆP TIN ĐÃ CẬP NHẬT

* **[widgets/camera_viewfinder.dart](file:///d:/Panket/lib/views/widgets/camera_viewfinder.dart):** Widget camera phần cứng vuông 1:1, tự động switch lenses 0.5x vật lý, zoom mượt mà, điều khiển flash, và xử lý Canvas `dart:ui` đồng bộ hóa ảnh chụp.
* **[views/home_view.dart](file:///d:/Panket/lib/views/home_view.dart):** Giao diện chính chứa bộ căn giữa trục dọc, PageView TikTok-style, dropdown filter trên AppBar, responsive Polaroid cards, và trình soạn thảo lớn.
* **[viewmodels/locket_viewmodel.dart](file:///d:/Panket/lib/viewmodels/locket_viewmodel.dart):** Thêm setter `setImagePath` kết nối camera viewfinder trực tiếp vào form đăng bài.
* **[walkthrough.md](file:///C:/Users/User/.gemini/antigravity-ide/brain/dede55cb-09ad-41de-be06-602d69d34fa0/walkthrough.md):** Tài liệu phân tích và hướng dẫn vận hành chi tiết của ứng dụng.

