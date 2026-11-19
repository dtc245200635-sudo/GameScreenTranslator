import Foundation

/// Quản lý cài đặt cấu hình thông qua App Group UserDefaults
public final class AppSettings {
    private static var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: AppGroupConstants.suiteName)
    }
    
    /// Ngôn ngữ nguồn cần nhận diện từ màn hình (mặc định: Tiếng Anh)
    public static var sourceLanguage: String {
        get {
            return userDefaults?.string(forKey: AppGroupConstants.sourceLanguageKey) ?? "en-US"
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.sourceLanguageKey)
        }
    }
    
    /// Ngôn ngữ đích dịch ra (mặc định: Tiếng Việt)
    public static var targetLanguage: String {
        get {
            return userDefaults?.string(forKey: AppGroupConstants.targetLanguageKey) ?? "vi"
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.targetLanguageKey)
        }
    }
    
    /// Vùng màn hình được chọn để dịch câu thoại ("bottom": Nửa dưới phụ đề, "top": Nhiệm vụ trên, "all": Toàn màn hình)
    public static var scanRegion: String {
        get {
            return userDefaults?.string(forKey: AppGroupConstants.scanRegionKey) ?? "bottom"
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.scanRegionKey)
        }
    }
    
    /// Chế độ kích hoạt dịch: "auto" (liên tục theo chu kỳ) hoặc "onDemand" (khi có thoại mới)
    public static var triggerMode: String {
        get {
            return userDefaults?.string(forKey: AppGroupConstants.triggerModeKey) ?? "auto"
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.triggerModeKey)
        }
    }
    
    /// Khoảng thời gian giữa 2 lần quét màn hình (giây) - chống nóng máy & lag game
    public static var scanInterval: Double {
        get {
            let val = userDefaults?.double(forKey: AppGroupConstants.scanIntervalKey) ?? 0
            return val > 0 ? val : 2.0
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.scanIntervalKey)
        }
    }
    
    /// Độ dài tối thiểu của chuỗi ký tự nhận diện để bắt đầu dịch
    public static var minimumTextLength: Int {
        get {
            let val = userDefaults?.integer(forKey: AppGroupConstants.textFilterLengthKey) ?? 0
            return val > 0 ? val : 3
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.textFilterLengthKey)
        }
    }
    
    /// Trạng thái bật/tắt dịch
    public static var isServiceEnabled: Bool {
        get {
            return userDefaults?.bool(forKey: AppGroupConstants.isServiceEnabledKey) ?? true
        }
        set {
            userDefaults?.set(newValue, forKey: AppGroupConstants.isServiceEnabledKey)
        }
    }
}
