import Foundation
import UserNotifications

/// Quản lý bắn Local Notification biểu ngữ (Banner) lên màn hình game
public final class NotificationService {
    public static let shared = NotificationService()
    
    private var lastSentTranslatedText: String = ""
    private var lastSentTime: CFAbsoluteTime = 0
    
    private init() {}

    /// Bắn thông báo biểu ngữ không phát âm thanh
    public func showTranslationBanner(original: String, translated: String) {
        let trimmedTranslated = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = CFAbsoluteTimeGetCurrent()
        
        // Không gửi lại nếu nội dung giống hệt và vừa mới gửi trong vòng 5 giây
        if trimmedTranslated == lastSentTranslatedText && (now - lastSentTime < 5.0) {
            return
        }
        
        lastSentTranslatedText = trimmedTranslated
        lastSentTime = now

        let content = UNMutableNotificationContent()
        content.title = "🌐 Dịch Game"
        
        // Cắt gọn bản gốc nếu quá dài để không chiếm diện tích banner
        let cleanOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        content.subtitle = cleanOriginal.count > 50 ? String(cleanOriginal.prefix(47)) + "..." : cleanOriginal
        content.body = trimmedTranslated
        content.sound = nil // Tắt âm thanh để không làm phiền trải nghiệm âm thanh của game

        // Kích hoạt ngay lập tức
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Dùng cùng identifier để thông báo mới lập tức ghi đè lên vị trí banner cũ
        let request = UNNotificationRequest(
            identifier: AppGroupConstants.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Lỗi gửi thông báo: \(error.localizedDescription)")
            }
        }
    }
}
