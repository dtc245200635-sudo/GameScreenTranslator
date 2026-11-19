import Foundation

/// Chứa các hằng số cấu hình dùng chung giữa Main App và Broadcast Extension
public enum AppGroupConstants {
    /// Định danh App Group chung
    public static let suiteName = "group.com.yourcompany.gametranslator"
    
    // Các Keys lưu trong UserDefaults
    public static let sourceLanguageKey = "sourceLanguage"
    public static let targetLanguageKey = "targetLanguage"
    public static let scanIntervalKey = "scanInterval"
    public static let isServiceEnabledKey = "isServiceEnabled"
    public static let translateApiKey = "translateApiKey"
    public static let textFilterLengthKey = "textFilterLength"
    public static let scanRegionKey = "scanRegion"           // Vùng chọn dịch: "bottom", "top", "all"
    public static let triggerModeKey = "triggerMode"         // "auto" hoặc "onDemand"
    
    // Notification ID
    public static let notificationIdentifier = "GAME_SCREEN_TRANSLATION_BANNER"
    
    // Extension Bundle ID
    public static let extensionBundleId = "com.yourcompany.gametranslator.extension"
}
