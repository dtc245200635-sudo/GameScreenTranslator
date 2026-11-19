import CoreMedia
import CoreVideo
import Accelerate

/// Xử lý tối ưu hóa ảnh trước khi đưa vào Vision: Giảm độ phân giải để vượt qua giới hạn 50MB RAM của Apple
public final class ImageProcessor {
    
    /// Thu nhỏ CVPixelBuffer xuống chiều rộng mục tiêu (mặc định 720px) bằng phần cứng Accelerate
    public static func resize(pixelBuffer: CVPixelBuffer, targetWidth: Int = 720) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // Nếu kích thước đã nhỏ hơn hoặc bằng 720, không cần scale
        if width <= targetWidth {
            return pixelBuffer
        }

        let scale = Float(targetWidth) / Float(width)
        let targetHeight = Int(Float(height) * scale)

        var destinationPixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            targetWidth,
            targetHeight,
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            attributes as CFDictionary,
            &destinationPixelBuffer
        )

        guard status == kCVReturnSuccess, let destBuffer = destinationPixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(destBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(destBuffer, [])
        }

        guard let srcBase = CVPixelBufferGetBaseAddress(pixelBuffer),
              let destBase = CVPixelBufferGetBaseAddress(destBuffer) else {
            return nil
        }

        var srcBuffer = vImage_Buffer(
            data: srcBase,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )
        
        var dstBuffer = vImage_Buffer(
            data: destBase,
            height: vImagePixelCount(targetHeight),
            width: vImagePixelCount(targetWidth),
            rowBytes: CVPixelBufferGetBytesPerRow(destBuffer)
        )

        // Sử dụng vImageScale_ARGB8888 để resize tức thì mà không tạo nhiều con trỏ memory thừa
        let error = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, nil, vImage_Flags(kvImageHighQualityResampling))
        guard error == kvImageNoError else {
            return nil
        }

        return destBuffer
    }
}
