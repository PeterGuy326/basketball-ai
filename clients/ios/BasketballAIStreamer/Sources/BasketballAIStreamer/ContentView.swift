import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showStreamingSettings = false
    @State private var streamURL = ""
    @State private var streamKey = ""
    @State private var cameraPreviewKey = UUID()
    @State private var showConnectionDetails = false
    
    private let config = AppConfig.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 全屏相机预览
                CameraPreviewView(cameraManager: cameraManager)
                    .id(cameraPreviewKey)
                    .ignoresSafeArea(.all)
                    .clipped()
                
                // 顶部状态栏
                VStack {
                    HStack {
                        // 推流状态指示器
                        HStack(spacing: 8) {
                            Circle()
                                .fill(cameraManager.videoStreamService.isConnected ? 
                                      (cameraManager.isStreaming ? Color.green : Color.orange) : 
                                      Color.red)
                                .frame(width: 8, height: 8)
                            Text(cameraManager.videoStreamService.connectionStatus)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(15)
                        .onTapGesture {
                            showConnectionDetails.toggle()
                        }
                        
                        Spacer()
                        
                        // 录制状态指示器
                        if cameraManager.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("录制中")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                        }
                        
                        // 缩放级别显示
                        if cameraManager.zoomFactor > 1.0 {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Text(String(format: "%.1fx", cameraManager.zoomFactor))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                        }
                        
                        // 设置按钮
                        Button(action: {
                            showStreamingSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                
                // 底部控制栏
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // 录制/推流按钮 - 主要控制（点击直接开始推流）
                        Button(action: {
                            if cameraManager.isStreaming {
                                // 如果正在推流，停止推流和录制
                                cameraManager.stopStreaming()
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                }
                            } else {
                                // 如果没有推流，开始录制和推流
                                if !cameraManager.isRecording {
                                    cameraManager.startRecording()
                                }
                                cameraManager.startStreaming(url: streamURL, key: streamKey)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .fill(cameraManager.isStreaming ? Color.red : Color.white)
                                    .frame(width: cameraManager.isStreaming ? 30 : 70, height: cameraManager.isStreaming ? 30 : 70)
                                    .animation(.easeInOut(duration: 0.2), value: cameraManager.isStreaming)
                                
                                if cameraManager.isStreaming {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("ContentView appeared, 开始初始化相机")
            
            // 从配置文件初始化URL设置
            streamURL = config.server.fullURL
            streamKey = config.server.authToken
            
            // 启用设备方向变化监听
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            Task {
                await cameraManager.initializeCamera()
            }
        }
        .onDisappear {
            // 停止设备方向变化监听
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .sheet(isPresented: $showStreamingSettings) {
            StreamingSettingsView(
                streamURL: $streamURL,
                streamKey: $streamKey,
                isPresented: $showStreamingSettings
            )
        }
        .sheet(isPresented: $showConnectionDetails) {
            ConnectionDetailsView(
                videoStreamService: cameraManager.videoStreamService,
                isPresented: $showConnectionDetails
            )
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let previewView = PreviewView()
        previewView.cameraManager = cameraManager
        print("创建PreviewView")
        setupPreviewLayer(previewView)
        
        // 添加设备方向变化监听
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            previewView.updateOrientation()
        }
        
        return previewView
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.cameraManager = cameraManager
        print("更新PreviewView，会话状态: \(cameraManager.captureSession != nil)")
        setupPreviewLayer(uiView)
    }
    
    private func setupPreviewLayer(_ previewView: PreviewView) {
        if let session = cameraManager.captureSession {
            print("设置预览层会话，会话运行状态: \(session.isRunning)")
            DispatchQueue.main.async {
                previewView.videoPreviewLayer.session = session
                previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
                print("预览层会话设置完成")
            }
        } else {
            print("相机会话为空，无法设置预览层")
        }
    }
}

class PreviewView: UIView {
    var cameraManager: CameraManager?
    private var initialZoomFactor: CGFloat = 1.0
    private var currentRotation: CGFloat = 0.0
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        // 捏合缩放手势
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
        
        // 旋转手势
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        addGestureRecognizer(rotationGesture)
        
        // 允许多个手势同时识别
        pinchGesture.delegate = self
        rotationGesture.delegate = self
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let cameraManager = cameraManager else { return }
        
        switch gesture.state {
        case .began:
            initialZoomFactor = cameraManager.zoomFactor
        case .changed:
            let newZoomFactor = initialZoomFactor * gesture.scale
            cameraManager.setZoom(newZoomFactor)
        default:
            break
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            currentRotation = 0.0
        case .changed:
            let rotation = gesture.rotation - currentRotation
            currentRotation = gesture.rotation
            
            // 应用旋转变换到预览层
            let currentTransform = videoPreviewLayer.transform
            let rotationTransform = CATransform3DRotate(currentTransform, rotation, 0, 0, 1)
            videoPreviewLayer.transform = rotationTransform
        case .ended, .cancelled:
            // 可以选择在手势结束时重置旋转或保持当前状态
            break
        default:
            break
        }
    }
    
    func resetRotation() {
        videoPreviewLayer.transform = CATransform3DIdentity
        currentRotation = 0.0
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 确保预览层填满整个视图
        videoPreviewLayer.frame = bounds
        
        // 更新预览层的方向
        updateOrientation()
    }
    
    func updateOrientation() {
        if let connection = videoPreviewLayer.connection {
            if connection.isVideoOrientationSupported {
                let orientation = currentVideoOrientation()
                connection.videoOrientation = orientation
                print("预览层方向更新为: \(orientation)")
                
                // 同时更新录制输出的方向
                cameraManager?.updateVideoOrientation()
            }
        }
    }
    
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
}

// MARK: - PreviewView Gesture Delegate
extension PreviewView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许捏合和旋转手势同时识别
        return true
    }
}

// MARK: - Streaming Settings View
struct StreamingSettingsView: View {
    @Binding var streamURL: String
    @Binding var streamKey: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器设置")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("服务器地址")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(config.server.fullURL, text: $streamURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("认证令牌 (可选)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("authentication token", text: $streamKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section(header: Text("服务类型说明")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text("HTTP 服务")
                                    .font(.headline)
                                Text("如: http://server:8080/ingest")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "video")
                                .foregroundColor(.red)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text("RTMP 推流")
                                    .font(.headline)
                                Text("如: rtmp://server/live")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("服务器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Connection Details View
struct ConnectionDetailsView: View {
    @ObservedObject var videoStreamService: VideoStreamService
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("连接状态")) {
                    HStack {
                        Text("服务器地址")
                        Spacer()
                        Text(videoStreamService.serverURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("连接状态")
                        Spacer()
                        HStack {
                            Circle()
                                .fill(videoStreamService.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(videoStreamService.isConnected ? "已连接" : "未连接")
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("状态信息")
                        Spacer()
                        Text(videoStreamService.connectionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("传输统计")) {
                    HStack {
                        Text("已发送帧数")
                        Spacer()
                        Text("\(videoStreamService.framesSent)")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    if let error = videoStreamService.lastError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最近错误")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Button("测试连接") {
                            Task {
                                await videoStreamService.testConnection()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("重置统计") {
                            videoStreamService.resetStats()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
            .navigationTitle("连接详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}