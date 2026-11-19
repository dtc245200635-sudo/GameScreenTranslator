# Ứng Dụng Dịch Màn Hình Game Cho iOS (Game Screen Translator)

Dự án iOS Native (Swift + SwiftUI + ReplayKit Broadcast Extension + Vision Framework + UserNotifications) cho phép quét và dịch trực tiếp phụ đề, nhiệm vụ trên màn hình khi đang chơi bất kỳ tựa game nào, hiển thị kết quả dịch xuống thông qua Banner Notification mà không làm gián đoạn game.

---

## 📁 Cấu Trúc Mã Nguồn

```text
GameScreenTranslator/
├── Shared/
│   ├── AppGroupConstants.swift            # Định danh App Group, Keys & hằng số
│   └── AppSettings.swift                  # Lưu cấu hình cài đặt (UserDefaults App Group)
│
├── GameTranslatorApp/                     # Target 1: Ứng dụng chính (SwiftUI)
│   ├── App/
│   │   └── GameTranslatorApp.swift        # App Lifecycle & Notification Delegate
│   ├── Views/
│   │   ├── ContentView.swift              # Màn hình cài đặt ngôn ngữ & điều khiển
│   │   └── BroadcastPickerView.swift      # Nút bấm kích hoạt ReplayKit Broadcast
│   ├── Managers/
│   │   └── PermissionManager.swift        # Xin quyền UserNotifications
│   ├── Assets.xcassets/                   # AppIcon & AccentColor
│   ├── Info.plist
│   └── GameTranslatorApp.entitlements     # Khai báo App Group
│
├── GameTranslatorExtension/               # Target 2: Broadcast Upload Extension
│   ├── SampleHandler.swift                # Tiếp nhận luồng frame CMSampleBuffer
│   ├── Services/
│   │   ├── FrameThrottler.swift           # Giới hạn FPS & phát hiện màn hình tĩnh
│   │   ├── ImageProcessor.swift           # Nén CVPixelBuffer về 720p (vImage)
│   │   ├── OCRService.swift               # Nhận diện chữ với Vision Framework (.fast)
│   │   ├── TranslationService.swift       # Dịch sang Tiếng Việt + In-memory Cache
│   │   └── NotificationService.swift      # Bắn Banner Notification lên đầu màn hình
│   ├── Info.plist
│   └── GameTranslatorExtension.entitlements # Cùng App Group với App chính
│
└── project.yml                            # File cấu hình tự động tạo Xcode Project qua XcodeGen
```

---

## 🚀 Hướng Dẫn Mở Dự Án Trong Xcode

### Cách 1: Sử dụng XcodeGen (Khuyên dùng - Nhanh nhất)
Nếu bạn mở code trên máy Mac:
1. Cài đặt XcodeGen (nếu chưa có):
   ```bash
   brew install xcodegen
   ```
2. Mở Terminal tại thư mục `GameScreenTranslator` và chạy:
   ```bash
   xcodegen generate
   ```
   Lệnh này sẽ tự động tạo ra file `GameScreenTranslator.xcodeproj` với đầy đủ Target, Scheme, Dependencies và Entitlements!
3. Nhấp đúp vào `GameScreenTranslator.xcodeproj` để mở trong Xcode.

---

### Cách 2: Mở thủ công trong Xcode
1. Mở Xcode -> **File** -> **New** -> **Project** -> Chọn **iOS App** -> Đặt tên `GameTranslatorApp`.
2. Trong Xcode, chọn **File** -> **New** -> **Target** -> Chọn **Broadcast Upload Extension** -> Đặt tên `GameTranslatorExtension`.
3. Kéo toàn bộ các file trong thư mục `Shared`, `GameTranslatorApp`, `GameTranslatorExtension` vào các nhóm tương ứng trong Xcode.
4. Cấu hình **App Groups**:
   - Chọn Target `GameTranslatorApp` -> Tab **Signing & Capabilities** -> Bấm **+ Capability** -> Chọn **App Groups** -> Thêm `group.com.yourcompany.gametranslator`.
   - Lặp lại bước trên cho Target `GameTranslatorExtension` (phải chung tên Group).

---

## 📱 Hướng Dẫn Chạy & Thử Nghiệm

> ⚠️ **Lưu ý quan trọng**: Tính năng ReplayKit Broadcast và Notification trên đầu màn hình hoạt động tốt và trực quan nhất trên **iPhone / iPad thật**. Trên máy ảo (Simulator), ReplayKit có thể bị hạn chế một số luồng khung hình.

1. Kết nối iPhone với máy Mac, chọn thiết bị đích là iPhone của bạn trong Xcode.
2. Cấu hình Development Team trong tab **Signing & Capabilities** cho cả 2 target.
3. Bấm **Run** để cài đặt ứng dụng lên iPhone.
4. Mở app **GameTranslator**:
   - Bấm **Cấp quyền** Thông báo (chọn "Cho phép").
   - Chọn ngôn ngữ game cần dịch (ví dụ: Tiếng Anh 🇺🇸 hoặc Tiếng Nhật 🇯🇵).
   - Chạm vào ô ReplayKit để bật pop-up -> Chọn **GameTranslator** -> Bấm **Bắt đầu truyền phát**.
5. Mở bất kỳ tựa game nào bạn thích (hoặc mở YouTube xem video gameplay).
6. Khi có hội thoại xuất hiện, bản dịch Tiếng Việt sẽ tự động rơi xuống dưới dạng Banner Notification từ cạnh trên màn hình!

---

## ⚡ Các Kỹ Thuật Tối Ưu Giới Hạn 50MB RAM
- **Hardware vImage Downscale**: Giảm frame gốc từ 2K/4K về 720p trước khi đưa vào Vision, tiết kiệm 75% RAM.
- **Vision Fast Recognition**: Sử dụng `VNRequestTextRecognitionLevel.fast` và tắt `usesLanguageCorrection`.
- **Pixel Change Hash**: Bỏ qua các frame tĩnh khi người chơi đứng yên.
- **Autoreleasepool**: Thu hồi bộ nhớ đệm CVPixelBuffer ngay lập tức sau mỗi lần quét.
- **Notification Dedup**: Tái sử dụng cùng một Notification Identifier để Banner cập nhật đè lên nhau mượt mà, không làm rối màn hình.
