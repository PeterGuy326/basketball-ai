import Foundation
import AVFoundation
import UIKit
import CryptoKit

final class StreamingService: NSObject, ObservableObject {
    private var endpoint: String = ""
    private var secret: String = ""
    private var useHMAC: Bool = true

    private var isRunning = false
    private var frameInterval: TimeInterval = 0.2 // 5 FPS，稳定带宽
    private var lastSent: TimeInterval = 0

    func configure(endpoint: String, secret: String, useHMAC: Bool) {
        self.endpoint = endpoint
        self.secret = secret
        self.useHMAC = useHMAC
    }

    func start(session: AVCaptureSession, status: @escaping (String) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        NotificationCenter.default.addObserver(self, selector: #selector(onFrame(_:)), name: .cameraFrame, object: nil)
        status("推流中...")
    }

    func stop() {
        isRunning = false
        NotificationCenter.default.removeObserver(self, name: .cameraFrame, object: nil)
    }

    @objc private func onFrame(_ note: Notification) {
        guard isRunning, let obj = note.object else { return }
        let sampleBuffer = obj as! CMSampleBuffer
        let now = CACurrentMediaTime()
        if now - lastSent < frameInterval { return }
        lastSent = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        // 1) 裁剪为竖屏 9:16 比例
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let targetAspect: CGFloat = 9.0 / 16.0
        let filled = aspectFill(image: ciImage, targetAspect: targetAspect)

        // 2) 缩放到 1080x1920，兼顾清晰度与带宽（Lanczos 缩放）
        let targetWidth: CGFloat = 1080
        let targetHeight: CGFloat = 1920
        let scaled = resizeLanczos(image: filled, targetWidth: targetWidth, targetHeight: targetHeight)

        // 3) 转 JPEG（提高质量到 0.7）
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return }
        let ui = UIImage(cgImage: cg)
        guard let jpg = ui.jpegData(compressionQuality: 0.7) else { return }
        let b64 = jpg.base64EncodedString()

        let ts = Int(Date().timeIntervalSince1970)
        let bodyDict: [String: Any] = ["frame": b64, "timestamp": ts]
        guard let body = try? JSONSerialization.data(withJSONObject: bodyDict) else { return }

        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        if useHMAC {
            let payload = "\(ts)\n" + String(decoding: body, as: UTF8.self)
            let key = SymmetricKey(data: Data(secret.utf8))
            let sig = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
            let sigHex = sig.map { String(format: "%02x", $0) }.joined()
            req.setValue("\(ts)", forHTTPHeaderField: "X-Timestamp")
            req.setValue(sigHex, forHTTPHeaderField: "X-Signature")
        } else if !secret.isEmpty {
            req.setValue(secret, forHTTPHeaderField: "X-Auth-Token")
        }

        URLSession.shared.dataTask(with: req) { _, resp, error in
            if let error = error {
                print("POST error: \(error)")
                return
            }
            if let http = resp as? HTTPURLResponse {
                if http.statusCode != 200 {
                    print("Server status: \(http.statusCode)")
                }
            }
        }.resume()
    }

    // 等比裁剪为目标纵横比（以中心为基准），返回裁剪后的 CIImage
    private func aspectFill(image: CIImage, targetAspect: CGFloat) -> CIImage {
        let extent = image.extent
        let w = extent.width
        let h = extent.height
        let srcAspect = w / h

        var crop = extent
        if srcAspect > targetAspect {
            // 源更宽，裁掉左右
            let newW = h * targetAspect
            let x = extent.origin.x + (w - newW) / 2.0
            crop = CGRect(x: x, y: extent.origin.y, width: newW, height: h)
        } else if srcAspect < targetAspect {
            // 源更高，裁掉上下
            let newH = w / targetAspect
            let y = extent.origin.y + (h - newH) / 2.0
            crop = CGRect(x: extent.origin.x, y: y, width: w, height: newH)
        }
        return image.cropped(to: crop)
    }

    // 使用 Lanczos 缩放到指定尺寸（已与目标比例匹配）
    private func resizeLanczos(image: CIImage, targetWidth: CGFloat, targetHeight: CGFloat) -> CIImage {
        let extent = image.extent
        let sx = targetWidth / extent.width
        let sy = targetHeight / extent.height
        // 比例已匹配，sx≈sy，选用 sx
        let scale = sx
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        return filter.outputImage ?? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}