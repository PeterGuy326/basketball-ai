import Foundation
import AVFoundation
import UIKit
import SwiftUI

@MainActor
class VideoStreamService: ObservableObject {
    @Published var serverURL = ""
    @Published var authToken = ""
    @Published var isConnected = false
    @Published var connectionStatus = "正在初始化..."
    @Published var framesSent = 0
    @Published var lastError: String?
    
    private var sendQueue = DispatchQueue(label: "video.send.queue", qos: .userInteractive)
    private let session = URLSession.shared
    private let config = AppConfig.shared
    
    init() {
        // 从配置文件加载设置
        loadConfigSettings()
    }
    
    private func loadConfigSettings() {
        serverURL = config.server.fullURL
        authToken = config.server.authToken
        connectionStatus = "配置已加载"
        
        config.log("服务器地址: \(serverURL)")
        if !authToken.isEmpty {
            config.log("认证令牌已配置")
        }
    }
    
    func updateServerURL(_ url: String) {
        serverURL = url
        connectionStatus = "服务器地址已更新"
    }
    
    func updateAuthToken(_ token: String) {
        authToken = token
    }
    
    func testConnection() async {
        connectionStatus = "正在测试连接..."
        
        do {
            let testResult = await sendTestFrame()
            if testResult {
                isConnected = true
                connectionStatus = "连接成功"
                lastError = nil
            } else {
                isConnected = false
                connectionStatus = "连接失败"
            }
        }
    }
    
    private func sendTestFrame() async -> Bool {
        let testPayload: [String: Any] = [
            "frame": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", // 1x1 透明PNG的base64
            "timestamp": Date().timeIntervalSince1970
        ]
        
        return await sendToServer(payload: testPayload)
    }
    
    func sendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: Double) {
        guard isConnected else { return }
        
        sendQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 将CVPixelBuffer转换为UIImage
            guard let image = self.convertPixelBufferToImage(pixelBuffer) else { 
                print("无法转换pixelBuffer为image")
                return 
            }
            
            // 压缩为JPEG数据 (使用配置的压缩质量)
            guard let imageData = image.jpegData(compressionQuality: config.video.compressionQuality) else { 
                print("无法转换image为JPEG数据")
                return 
            }
            
            // Base64编码
            let base64String = imageData.base64EncodedString()
            
            // 构建JSON payload
            let payload: [String: Any] = [
                "frame": base64String,
                "timestamp": timestamp
            ]
            
            // 异步发送到服务器
            Task { [weak self] in
                let success = await self?.sendToServer(payload: payload) ?? false
                
                await MainActor.run {
                    if success {
                        self?.framesSent += 1
                        if self?.framesSent == 1 || self?.framesSent % 30 == 0 { // 每30帧更新一次状态
                            self?.connectionStatus = "已发送 \(self?.framesSent ?? 0) 帧"
                        }
                    } else {
                        self?.connectionStatus = "发送失败"
                    }
                }
            }
        }
    }
    
    @discardableResult
    private func sendToServer(payload: [String: Any]) async -> Bool {
        guard let url = URL(string: serverURL) else {
            await MainActor.run {
                lastError = "无效的服务器URL"
            }
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.server.timeout
        
        // 添加认证头（如果配置了）
        if !authToken.isEmpty {
            request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
        }
        
        // 添加时间戳头
        request.setValue(String(Date().timeIntervalSince1970), forHTTPHeaderField: "X-Timestamp")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = jsonData
            
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                config.logNetwork("服务器响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    return true
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "无响应内容"
                    await MainActor.run {
                        lastError = "服务器错误 \(httpResponse.statusCode): \(responseString)"
                    }
                    return false
                }
            }
            return false
        } catch {
            print("发送视频帧失败: \(error)")
            await MainActor.run {
                lastError = "网络错误: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    private func convertPixelBufferToImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        // 设置较小的输出尺寸以减少数据传输量（使用配置的分辨率）
        let maxWidth = CGFloat(config.video.maxResolution.width)
        let maxHeight = CGFloat(config.video.maxResolution.height)
        let outputExtent = CGRect(x: 0, y: 0, width: maxWidth, height: maxHeight)
        
        // 如果原始图像更大，则缩放到指定尺寸
        let scaledImage: CIImage
        let originalExtent = ciImage.extent
        if originalExtent.width > outputExtent.width || originalExtent.height > outputExtent.height {
            let scaleX = outputExtent.width / originalExtent.width
            let scaleY = outputExtent.height / originalExtent.height
            let scale = min(scaleX, scaleY)
            
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            scaledImage = ciImage.transformed(by: transform)
        } else {
            scaledImage = ciImage
        }
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func resetStats() {
        framesSent = 0
        lastError = nil
        connectionStatus = isConnected ? "连接就绪" : "未连接"
    }
    
    func disconnect() {
        isConnected = false
        connectionStatus = "已断开连接"
        framesSent = 0
    }
}