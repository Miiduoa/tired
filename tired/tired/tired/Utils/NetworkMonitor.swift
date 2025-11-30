import Foundation
import Network
import Combine
import SwiftUI

enum ConnectionType: String {
    case wifi = "Wi-Fi"
    case cellular = "行動網路"
    case ethernet = "乙太網路"
    case unknown = "未知"
}

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive: Bool = false // 是否為付費網路（如行動數據）
    @Published var isConstrained: Bool = false // 是否受限（如低數據模式）
    @Published var wasDisconnected: Bool = false // 追蹤是否曾斷線（用於顯示重連提示）
    
    private var lastConnectionState: Bool = true

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let newConnectionState = path.status == .satisfied
                
                // 檢測是否從斷線恢復連線
                if !self.lastConnectionState && newConnectionState {
                    self.wasDisconnected = true
                    // 3秒後自動隱藏重連提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.wasDisconnected = false
                    }
                }
                
                self.lastConnectionState = newConnectionState
                self.isConnected = newConnectionState
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                
                // 判斷連線類型
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// 獲取離線提示訊息
    var offlineMessage: String {
        "目前處於離線狀態，部分功能可能受限"
    }
    
    /// 獲取連線狀態的顏色
    var statusColor: Color {
        if !isConnected {
            return .red
        } else if isConstrained {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - 離線橫幅視圖
@available(iOS 17.0, *)
struct OfflineBannerView: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if networkMonitor.wasDisconnected {
                reconnectedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if networkMonitor.isConstrained {
                constrainedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.3), value: networkMonitor.wasDisconnected)
    }
    
    private var offlineBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("離線模式")
                    .font(.system(size: 14, weight: .semibold))
                Text("數據將在恢復連線後自動同步")
                    .font(.system(size: 12))
                    .opacity(0.9)
            }
            
            Spacer()
            
            // 重試按鈕
            Button {
                // 觸發重新檢查連線
                networkMonitor.startMonitoring()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var reconnectedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .font(.system(size: 16, weight: .semibold))
            
            Text("已恢復連線")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            Text(networkMonitor.connectionType.rawValue)
                .font(.system(size: 12))
                .opacity(0.9)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green)
    }
    
    private var constrainedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .semibold))
            
            Text("低數據模式：部分功能受限")
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.9))
    }
}

// MARK: - 離線狀態包裝器
@available(iOS 17.0, *)
struct OfflineAwareView<Content: View>: View {
    @EnvironmentObject var networkMonitor: NetworkMonitor
    let content: Content
    let offlineContent: AnyView?
    
    init(@ViewBuilder content: () -> Content, offlineContent: AnyView? = nil) {
        self.content = content()
        self.offlineContent = offlineContent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            OfflineBannerView()
            
            if networkMonitor.isConnected {
                content
            } else if let offlineView = offlineContent {
                offlineView
            } else {
                content
                    .overlay(
                        Color.black.opacity(0.05)
                            .allowsHitTesting(false)
                    )
            }
        }
    }
}
