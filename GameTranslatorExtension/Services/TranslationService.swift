import Foundation

/// Dịch vụ dịch thuật văn bản sang tiếng Việt kèm bộ đệm (In-memory LRU Cache)
public final class TranslationService {
    // Cache lưu kết quả dịch nhằm tránh gọi mạng liên tục cho các đoạn text lặp lại
    private let cache = NSCache<NSString, NSString>()
    private let session: URLSession

    public init() {
        // Giới hạn số lượng câu trong cache để tiết kiệm RAM tối đa cho Extension
        cache.countLimit = 60
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4.0 // Timeout nhanh để không dồn ứ hàng đợi
        config.timeoutIntervalForResource = 6.0
        self.session = URLSession(configuration: config)
    }

    /// Dịch đoạn text sang ngôn ngữ đích
    public func translate(
        text: String,
        from source: String,
        to target: String,
        completion: @escaping (String?) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completion(nil)
            return
        }

        let cacheKey = NSString(string: "\(source)_\(target)_\(trimmed)")
        if let cachedResult = cache.object(forKey: cacheKey) {
            completion(cachedResult as String)
            return
        }

        // Tách mã ngôn ngữ chuẩn (VD: en-US -> en, id-ID -> id, zh-Hans -> zh-CN)
        let sourceCode: String
        switch source {
        case "zh-Hans":
            sourceCode = "zh-CN"
        case "zh-Hant":
            sourceCode = "zh-TW"
        default:
            sourceCode = source.split(separator: "-").first.map(String.init) ?? "auto"
        }
        let targetCode = target.split(separator: "-").first.map(String.init) ?? "vi"

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sourceCode)&tl=\(targetCode)&dt=t&q=\(encoded)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                // Parse kết quả mảng lồng nhau từ Google Translate gtx
                // Cấu trúc: [[["Bản dịch tiếng Việt", "Bản gốc tiếng Anh", ...], ...]]
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                   let sentences = json.first as? [Any] {
                    
                    var fullTranslated = ""
                    for item in sentences {
                        if let sentenceParts = item as? [Any],
                           let translatedPart = sentenceParts.first as? String {
                            fullTranslated += translatedPart
                        }
                    }
                    
                    if !fullTranslated.isEmpty {
                        self?.cache.setObject(NSString(string: fullTranslated), forKey: cacheKey)
                        completion(fullTranslated)
                        return
                    }
                }
            } catch {
                print("[TranslationService] Parse JSON thất bại: \(error)")
            }

            completion(nil)
        }
        task.resume()
    }
}
