import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var streamer = StreamingService()

    @State private var isStreaming = false
    @State private var statusText = ""
    @State private var liveAnimating = false

    // 默认配置：仅用于开始推流时使用
    private let defaultEndpoint: String = "http://192.168.55.15:8005/ingest"
    private let defaultSecret: String = ""
    private let defaultUseHMAC: Bool = true

    var body: some View {
        ZStack {
            // 全屏相机预览
            CameraPreviewView(session: camera.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()
                .onAppear { camera.configure() }

            // 顶部 LIVE 胶囊（直接放置，不用渐变背景）
            if isStreaming {
                VStack {
                    HStack {
                        LiveBadge(isAnimating: $liveAnimating)
                            .padding(.top, 10)
                            .padding(.leading, 14)
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
        // 底部仅悬浮按钮，无背景遮挡，预览完全铺满
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.9))
                }

                Button(action: toggle) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 5)
                            .frame(width: 86, height: 86)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 58, height: 58)
                            .scaleEffect(isStreaming && liveAnimating ? 0.88 : 1.0)
                            .opacity(isStreaming && liveAnimating ? 0.85 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: liveAnimating)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 24)
        }
        .onChange(of: isStreaming) { newValue in
            if newValue {
                // 开始直播时启动脉冲动画
                liveAnimating = true
            } else {
                // 停止时恢复静止并清空状态文字
                liveAnimating = false
                statusText = ""
            }
        }
        .navigationBarHidden(true)
        .supportedOrientations(.portrait)
        .orientationLock(.portrait)
    }

    private func toggle() {
        let h = UIImpactFeedbackGenerator(style: .soft)
        h.impactOccurred()
        if isStreaming { stop() } else { start() }
    }

    private func start() {
        streamer.configure(endpoint: defaultEndpoint, secret: defaultSecret, useHMAC: defaultUseHMAC)
        streamer.start(session: camera.session) { _ in
            isStreaming = true
        }
    }

    private func stop() {
        streamer.stop()
        isStreaming = false
        statusText = ""
    }
}

// 顶部左侧 LIVE 胶囊（红点闪烁）
private struct LiveBadge: View {
    @Binding var isAnimating: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 0.7 : 1.0)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isAnimating)

            Text("LIVE")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red)
        .clipShape(Capsule())
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // 固定竖屏，不需要动态调整
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .black
        videoPreviewLayer.frame = bounds
        
        // 固定竖屏方向，禁用镜像
        if let connection = videoPreviewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
    }
}

// MARK: - 方向锁定扩展
extension View {
    func supportedOrientations(_ orientation: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientation
        }
    }
    
    func orientationLock(_ orientation: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientation
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}