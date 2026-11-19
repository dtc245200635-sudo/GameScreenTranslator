import Foundation
import CoreMedia
import CoreVideo

/// Bộ điều tiết khung hình: Ngăn chặn xử lý quá mức gây nóng máy và tràn RAM
public final class FrameThrottler {
    private var lastProcessedTime: CFAbsoluteTime = 0
    private var previousHash: Int = 0

    public init() {}

    /// Kiểm tra xem đã đến thời điểm xử lý frame tiếp theo hay chưa
    public func shouldProcess(currentTime: CFAbsoluteTime, interval: Double) -> Bool {
        if currentTime - lastProcessedTime >= interval {
            lastProcessedTime = currentTime
            return true
        }
        return false
    }

    /// Lấy mẫu pixel nhanh để kiểm tra xem màn hình có biến động đáng kể so với frame trước không
    public func hasMeaningfulChange(pixelBuffer: CVPixelBuffer) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return true }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard height > 10 else { return true }
        
        // Lấy 4 điểm pixel mẫu đại diện ở 4 vùng màn hình khác nhau
        let sample1 = baseAddress.load(fromByteOffset: 0, as: UInt32.self)
        let sample2 = baseAddress.load(fromByteOffset: (height / 4) * bytesPerRow, as: UInt32.self)
        let sample3 = baseAddress.load(fromByteOffset: (height / 2) * bytesPerRow, as: UInt32.self)
        let sample4 = baseAddress.load(fromByteOffset: (3 * height / 4) * bytesPerRow, as: UInt32.self)
        
        var hasher = Hasher()
        hasher.combine(sample1)
        hasher.combine(sample2)
        hasher.combine(sample3)
        hasher.combine(sample4)
        let currentHash = hasher.finalize()

        // Nếu hash giống hệt lần trước -> Màn hình đứng yên, không cần tốn công OCR
        if currentHash == previousHash {
            return false
        }
        
        previousHash = currentHash
        return true
    }
    
    /// Reset bộ đếm khi kết thúc hoặc khởi động lại
    public func reset() {
        lastProcessedTime = 0
        previousHash = 0
    }
}
