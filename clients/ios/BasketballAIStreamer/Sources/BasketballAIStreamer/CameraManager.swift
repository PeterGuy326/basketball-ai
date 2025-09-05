import Foundation
import AVFoundation
import SwiftUI

@MainActor
class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isStreaming = false
    @Published var streamingStatus: String = "正在初始化相机..."
    @Published var recordingStatus: String = "准备就绪"
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var zoomFactor: CGFloat = 1.0
    
    // MARK: - Camera Properties
    @Published var captureSession: AVCaptureSession?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Video Stream Service
    @Published var videoStreamService = VideoStreamService()
    private let videoQueue = DispatchQueue(label: "video.queue", qos: .userInteractive)
    
    // MARK: - Configuration
    var streamURL: String = ""
    var streamKey: String = ""
    
    override init() {
        super.init()
        // 不在init中调用setupCamera，而是在视图出现时调用
    }
    
    // MARK: - Public Methods
    func initializeCamera() async {
        await MainActor.run {
            setupCamera()
        }
    }
    

    
    // MARK: - Setup Methods
    private func setupCamera() {
        print("开始设置相机")
        streamingStatus = "检查相机权限..."
        
        // 检查相机权限状态
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("相机权限状态: \(videoStatus.rawValue)")
        
        switch videoStatus {
        case .authorized:
            print("相机权限已授权，开始配置会话")
            streamingStatus = "配置相机会话..."
            configureSession()
        case .notDetermined:
            print("请求相机权限")
            streamingStatus = "请求相机权限..."
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        print("相机权限已获得")
                        self?.streamingStatus = "配置相机会话..."
                        self?.configureSession()
                    } else {
                        print("相机权限被拒绝")
                        self?.streamingStatus = "需要相机权限"
                    }
                }
            }
        case .denied, .restricted:
            print("相机权限被拒绝或受限")
            streamingStatus = "相机权限被拒绝"
        @unknown default:
            print("相机权限状态未知")
            streamingStatus = "相机权限状态未知"
        }
        
        // 同时请求音频权限
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("音频权限请求结果: \(granted)")
            }
        }
    }
    
    private func configureSession() {
        print("开始配置相机会话")
        captureSession = AVCaptureSession()
        guard let session = captureSession else {
            print("无法创建 AVCaptureSession")
            DispatchQueue.main.async {
                self.streamingStatus = "会话创建失败"
            }
            return
        }
        
        session.beginConfiguration()
        print("会话配置开始")
        
        // 设置高质量预设
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
            print("设置预设: HD 1920x1080")
        } else if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
            print("设置预设: HD 1280x720")
        } else {
            print("无法设置高清预设，使用默认预设")
        }
        
        // 添加视频输入
        setupVideoInput()
        
        // 添加音频输入
        setupAudioInput()
        
        // 添加录制输出
        setupOutputs()
        
        // 添加视频数据输出用于流传输
        setupVideoDataOutput()
        
        session.commitConfiguration()
        print("会话配置完成")
        
        // 启动会话
        DispatchQueue.global(qos: .userInitiated).async {
            print("开始启动相机会话")
            session.startRunning()
            print("相机会话启动完成，运行状态: \(session.isRunning)")
            DispatchQueue.main.async { [weak self] in
                if session.isRunning {
                    self?.streamingStatus = "相机已就绪"
                    print("相机状态更新: 相机已就绪")
                } else {
                    self?.streamingStatus = "相机启动失败"
                    print("相机状态更新: 相机启动失败")
                }
            }
        }
    }
    
    private func setupVideoInput() {
        guard let session = captureSession else {
            print("CaptureSession 为空")
            DispatchQueue.main.async {
                self.streamingStatus = "会话初始化失败"
            }
            return
        }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            print("无法获取摄像头设备，位置: \(cameraPosition)")
            DispatchQueue.main.async {
                self.streamingStatus = "摄像头设备不可用"
            }
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
                print("视频输入添加成功")
            } else {
                print("无法添加视频输入到会话")
                DispatchQueue.main.async {
                    self.streamingStatus = "视频输入配置失败"
                }
            }
        } catch {
            print("无法创建视频输入: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.streamingStatus = "视频输入创建失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupAudioInput() {
        guard let session = captureSession else { return }
        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            return
        }
        
        do {
            let audioInput = try AVCaptureDeviceInput(device: microphone)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
                audioDeviceInput = audioInput
            }
        } catch {
            print("无法创建音频输入: \(error.localizedDescription)")
        }
    }
    
    private func setupOutputs() {
        guard let session = captureSession else { return }
        
        // Setup movie file output for recording
        movieFileOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieFileOutput, session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            
            // 初始设置视频连接的方向
            updateVideoOrientation()
        }
    }
    
    private func setupVideoDataOutput() {
        guard let session = captureSession else { return }
        
        videoDataOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoDataOutput else { return }
        
        // 设置像素格式为YUV420，便于处理
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        
        // 设置输出代理
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        // 丢弃延迟的帧以保持实时性
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            print("视频数据输出添加成功")
        } else {
            print("无法添加视频数据输出")
        }
    }
    
    // 更新视频输出方向
    func updateVideoOrientation() {
        guard let movieOutput = movieFileOutput else { return }
        
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                let orientation = currentVideoOrientation()
                connection.videoOrientation = orientation
                print("视频输出方向更新为: \(orientation)")
            }
        }
    }
    
    // 获取当前设备方向对应的视频方向
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait // 默认竖屏
        }
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        
        return previewLayer
    }
    
    func switchCamera() {
        guard let session = captureSession else { return }
        
        session.beginConfiguration()
        
        // 移除当前视频输入
        if let currentVideoInput = videoDeviceInput {
            session.removeInput(currentVideoInput)
        }
        
        // 切换摄像头位置
        cameraPosition = (cameraPosition == .back) ? .front : .back
        
        // 重新设置视频输入
        setupVideoInput()
        
        // 重置缩放因子
        zoomFactor = 1.0
        
        session.commitConfiguration()
        
        DispatchQueue.main.async {
            self.streamingStatus = "摄像头已切换"
        }
        
        print("摄像头已切换到: \(cameraPosition == .back ? "后置" : "前置")")
    }
    
    // MARK: - Zoom Control
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            // 限制缩放范围
            let clampedFactor = max(device.minAvailableVideoZoomFactor, 
                                  min(factor, device.maxAvailableVideoZoomFactor))
            
            device.videoZoomFactor = clampedFactor
            zoomFactor = clampedFactor
            
            device.unlockForConfiguration()
            
            print("缩放因子设置为: \(clampedFactor)")
        } catch {
            print("设置缩放失败: \(error.localizedDescription)")
        }
    }
    
    func getMaxZoomFactor() -> CGFloat {
        guard let device = videoDeviceInput?.device else { return 1.0 }
        return device.maxAvailableVideoZoomFactor
    }
    
    func getMinZoomFactor() -> CGFloat {
        guard let device = videoDeviceInput?.device else { return 1.0 }
        return device.minAvailableVideoZoomFactor
    }
    
    func resetZoom() {
        setZoom(1.0)
    }
    

    
    // MARK: - Public Methods
    
    func startStreaming(url: String, key: String) {
        streamURL = url
        streamKey = key
        
        // 如果url看起来像HTTP URL，则使用VideoStreamService
        if url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") {
            videoStreamService.updateServerURL(url)
            if !key.isEmpty {
                videoStreamService.updateAuthToken(key)
            }
            
            Task {
                await videoStreamService.testConnection()
                await MainActor.run {
                    if videoStreamService.isConnected {
                        self.isStreaming = true
                        self.streamingStatus = "HTTP推流中"
                    } else {
                        self.streamingStatus = "连接失败"
                    }
                }
            }
        } else {
            // RTMP推流逻辑
            DispatchQueue.main.async {
                self.isStreaming = true
                self.streamingStatus = "RTMP推流中"
            }
        }
    }
    
    func stopStreaming() {
        videoStreamService.disconnect()
        DispatchQueue.main.async {
            self.isStreaming = false
            self.streamingStatus = "已停止"
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        guard let movieOutput = movieFileOutput else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("basketball_\(Date().timeIntervalSince1970).mov")
        
        // 设置录制方向为横屏
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
            }
        }
        
        movieOutput.startRecording(to: videoPath, recordingDelegate: self)
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingStatus = "录制中"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        guard let movieOutput = movieFileOutput else { return }
        
        movieOutput.stopRecording()
    }
}



// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingStatus = "准备就绪"
        }
        
        if let error = error {
            print("录制错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.recordingStatus = "录制失败"
            }
        } else {
            print("录制完成: \(outputFileURL.path)")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        
        // 只在HTTP流式传输时处理视频帧
        guard isStreaming && videoStreamService.isConnected else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let timestamp = Date().timeIntervalSince1970
        
        // 发送到VideoStreamService（已经在后台队列中）
        videoStreamService.sendVideoFrame(pixelBuffer, timestamp: timestamp)
    }
}