import SwiftUI

@main
struct BasketballAIStreamerApp: App {
    // 通过 AppDelegate 控制全局方向锁定
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}