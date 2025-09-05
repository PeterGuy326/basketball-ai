import Foundation

// MARK: - Configuration Models
struct AppConfig: Codable {
    let server: ServerConfig
    let video: VideoConfig
    let debug: DebugConfig
    
    static let shared = AppConfigManager.loadConfig()
}

struct ServerConfig: Codable {
    let baseURL: String
    let endpoint: String
    let authToken: String
    let timeout: TimeInterval
    
    var fullURL: String {
        return baseURL + endpoint
    }
}

struct VideoConfig: Codable {
    let compressionQuality: Double
    let maxResolution: Resolution
}

struct Resolution: Codable {
    let width: Int
    let height: Int
}

struct DebugConfig: Codable {
    let enableLogging: Bool
    let logNetworkRequests: Bool
}

// MARK: - Configuration Manager
class AppConfigManager {
    private static let configFileName = "config"
    private static let defaultConfig = AppConfig(
        server: ServerConfig(
            baseURL: "http://localhost:8080",
            endpoint: "/ingest",
            authToken: "",
            timeout: 5.0
        ),
        video: VideoConfig(
            compressionQuality: 0.6,
            maxResolution: Resolution(width: 640, height: 480)
        ),
        debug: DebugConfig(
            enableLogging: true,
            logNetworkRequests: true
        )
    )
    
    static func loadConfig() -> AppConfig {
        // 尝试从bundle中读取配置文件
        if let configPath = Bundle.main.path(forResource: configFileName, ofType: "json"),
           let configData = FileManager.default.contents(atPath: configPath) {
            
            do {
                let config = try JSONDecoder().decode(AppConfig.self, from: configData)
                if AppConfig.shared.debug.enableLogging {
                    print("✅ 配置加载成功: \(config.server.fullURL)")
                }
                return config
            } catch {
                print("❌ 配置文件解析失败: \(error.localizedDescription)")
                print("使用默认配置")
            }
        } else {
            print("⚠️ 未找到config.json文件，使用默认配置")
        }
        
        return defaultConfig
    }
    
    // 创建配置文件的方法（开发时使用）
    static func createSampleConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let configData = try encoder.encode(defaultConfig)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let configURL = documentsPath.appendingPathComponent("config.json")
            try configData.write(to: configURL)
            print("示例配置文件已创建: \(configURL.path)")
        } catch {
            print("创建配置文件失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Configuration Extensions
extension AppConfig {
    func log(_ message: String) {
        if debug.enableLogging {
            print("🔧 [Config] \(message)")
        }
    }
    
    func logNetwork(_ message: String) {
        if debug.logNetworkRequests {
            print("🌐 [Network] \(message)")
        }
    }
}