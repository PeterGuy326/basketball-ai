import Foundation
import AVFoundation
import UIKit

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    override init() {
        super.init()
    }

    func configure() {
        sessionQueue.async {
            self.session.beginConfiguration()
            // 优先 4K（16:9），不支持则回落 1080p
            if self.session.canSetSessionPreset(.hd4K3840x2160) {
                self.session.sessionPreset = .hd4K3840x2160
            } else {
                self.session.sessionPreset = .hd1920x1080
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                return
            }
            self.session.addInput(input)

            // 将帧率稳定在 30 FPS，减少能耗与过热（推流仍按 5 FPS 发送）
            do {
                try device.lockForConfiguration()
                let ranges = device.activeFormat.videoSupportedFrameRateRanges
                if ranges.contains(where: { $0.maxFrameRate >= 30 }) {
                    device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                }
                device.unlockForConfiguration()
            } catch {
                // 忽略帧率设置失败
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let outputQueue = DispatchQueue(label: "camera.frame.queue")
            output.setSampleBufferDelegate(self, queue: outputQueue)
            if self.session.canAddOutput(output) { self.session.addOutput(output) }

            // 固定竖屏方向与镜像，不随设备旋转
            if let conn = output.connection(with: .video) {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
                if conn.isVideoMirroringSupported {
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = false
                }
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    // 获取当前界面方向（保留但不再用于锁定输出）
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            switch scene.interfaceOrientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            @unknown default: return .portrait
            }
        }
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 固定竖屏方向与镜像（不再根据设备方向更新）
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        // 由 StreamingService 接管帧处理
        NotificationCenter.default.post(name: .cameraFrame, object: sampleBuffer)
    }
}

extension Notification.Name {
    static let cameraFrame = Notification.Name("camera.frame")
}