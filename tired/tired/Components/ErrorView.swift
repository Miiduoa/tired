import SwiftUI

/// 錯誤顯示組件
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    
    init(error: Error, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("發生錯誤")
                .font(.title2.weight(.semibold))
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let retry = retry {
                Button(action: retry) {
                    Label("重試", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }
}

/// 空狀態顯示組件
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionLabel: String?
    
    init(
        icon: String = "tray",
        title: String = "暫無內容",
        message: String = "這裡還沒有任何內容",
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
        self.actionLabel = actionLabel
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2.weight(.semibold))
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }
}

/// 成功提示組件
struct SuccessView: View {
    let message: String
    let dismissAction: (() -> Void)?
    
    init(message: String = "操作成功", dismissAction: (() -> Void)? = nil) {
        self.message = message
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let action = dismissAction {
                Button("確定", action: action)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

/// 警告提示組件
struct WarningView: View {
    let title: String
    let message: String
    let confirmAction: (() -> Void)?
    let cancelAction: (() -> Void)?
    
    init(
        title: String = "警告",
        message: String,
        confirmAction: (() -> Void)? = nil,
        cancelAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmAction = confirmAction
        self.cancelAction = cancelAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            
            Text(title)
                .font(.title2.weight(.semibold))
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                if let cancelAction = cancelAction {
                    Button("取消", action: cancelAction)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                
                if let confirmAction = confirmAction {
                    Button("確認", action: confirmAction)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange, in: Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

// MARK: - Inline Error Banner

struct ErrorBanner: View {
    let message: String
    let dismissAction: (() -> Void)?
    
    init(message: String, dismissAction: (() -> Void)? = nil) {
        self.message = message
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let action = dismissAction {
                Button(action: action) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

/// Success Banner
struct SuccessBanner: View {
    let message: String
    let dismissAction: (() -> Void)?
    
    init(message: String, dismissAction: (() -> Void)? = nil) {
        self.message = message
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let action = dismissAction {
                Button(action: action) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Error") {
    ErrorView(
        error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "網絡連接失敗，請檢查您的網絡設置"]),
        retry: {}
    )
}

#Preview("Empty") {
    EmptyStateView(
        icon: "tray",
        title: "暫無訊息",
        message: "您目前沒有任何訊息",
        action: {},
        actionLabel: "重新整理"
    )
}

#Preview("Success") {
    SuccessView(message: "操作成功完成！")
}

#Preview("Warning") {
    WarningView(
        message: "此操作將無法撤銷，確定要繼續嗎？",
        confirmAction: {},
        cancelAction: {}
    )
}

#Preview("Error Banner") {
    VStack {
        ErrorBanner(message: "無法載入數據，請重試")
        Spacer()
    }
}

#Preview("Success Banner") {
    VStack {
        SuccessBanner(message: "保存成功")
        Spacer()
    }
}

