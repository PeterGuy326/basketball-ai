import Foundation
import AVFoundation
import UIKit
import CryptoKit

final class StreamingService: NSObject, ObservableObject {
    private var endpoint: String = ""
    private var secret: String = ""
    private var useHMAC: Bool = true

    private var isRunning = false
    private var frameInterval: TimeInterval = 0.2 // 5 FPS
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
        guard isRunning, let sampleBuffer = note.object as? CMSampleBuffer else { return }
        let now = CACurrentMediaTime()
        if now - lastSent < frameInterval { return }
        lastSent = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        // 转 JPEG
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let ui = UIImage(cgImage: cg)
        guard let jpg = ui.jpegData(compressionQuality: 0.6) else { return }
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
}