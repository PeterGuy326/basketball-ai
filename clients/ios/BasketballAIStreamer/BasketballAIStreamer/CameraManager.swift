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
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                return
            }
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let outputQueue = DispatchQueue(label: "camera.frame.queue")
            output.setSampleBufferDelegate(self, queue: outputQueue)
            if self.session.canAddOutput(output) { self.session.addOutput(output) }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 由 StreamingService 接管帧处理
        NotificationCenter.default.post(name: .cameraFrame, object: sampleBuffer)
    }
}

extension Notification.Name {
    static let cameraFrame = Notification.Name("camera.frame")
}