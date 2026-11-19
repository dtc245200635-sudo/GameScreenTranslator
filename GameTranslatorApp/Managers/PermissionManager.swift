import Foundation
import UserNotifications
import UIKit

@MainActor
final class PermissionManager: ObservableObject {
    @Published var isNotificationAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        checkNotificationStatus()
    }
    
    /// Kiểm tra trạng thái cấp quyền hiện tại
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isNotificationAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    /// Xin quyền hiển thị Banner & Sound thông báo
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isNotificationAuthorized = granted
                self?.checkNotificationStatus()
            }
        }
    }
    
    /// Mở Cài đặt hệ thống nếu người dùng đã bấm Từ Chối trước đó
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
