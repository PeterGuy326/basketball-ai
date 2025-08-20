import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    @StateObject private var streamer = StreamingService()

    @State private var isStreaming = false
    @State private var statusText = "准备就绪"

    // 新增：可编辑的服务端地址与鉴权配置
    @State private var endpoint: String = "http://localhost:8005/ingest"
    @State private var secret: String = ""
    @State private var useHMAC: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            CameraPreviewView(session: camera.session)
                .frame(height: 360)
                .background(Color.black)
                .cornerRadius(8)
                .onAppear { camera.configure() }

            // 配置区域：Endpoint、Secret、HMAC 开关
            VStack(alignment: .leading, spacing: 8) {
                TextField("服务端 /ingest 地址", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                SecureField("鉴权密钥（留空=关闭鉴权）", text: $secret)
                    .textFieldStyle(.roundedBorder)
                Toggle("使用 HMAC（关闭则使用固定 Token）", isOn: $useHMAC)
            }

            HStack(spacing: 16) {
                Button(action: start) {
                    Text("开始推流")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStreaming)

                Button(action: stop) {
                    Text("停止")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!isStreaming)
            }

            Text(statusText)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func start() {
        streamer.configure(endpoint: endpoint, secret: secret, useHMAC: useHMAC)
        streamer.start(session: camera.session) { msg in
            statusText = msg
            isStreaming = true
        }
    }

    private func stop() {
        streamer.stop()
        isStreaming = false
        statusText = "已停止"
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

    func updateUIView(_ uiView: PreviewView, context: Context) { }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}