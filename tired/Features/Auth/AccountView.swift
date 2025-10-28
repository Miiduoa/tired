import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        List {
            if let user = authService.currentUser {
                Section(header: Text("帳號資訊")) {
                    HStack {
                        Text("姓名")
                        Spacer()
                        Text(user.displayName).foregroundColor(.secondary)
                    }
                    HStack {
                        Text("電子郵件")
                        Spacer()
                        Text(user.email).foregroundColor(.secondary)
                    }
                    if let phone = user.phoneNumber {
                        HStack {
                            Text("手機號碼")
                            Spacer()
                            Text(phone).foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("驗證狀態")
                        Spacer()
                        Label(user.verificationStatus.title, systemImage: user.verificationStatus.icon)
                            .foregroundStyle(user.verificationStatus.color)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) { authService.signOut() } label: {
                    Text("登出")
                }
            }
        }
        .navigationTitle("帳號")
        .alert(item: $authService.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("確定")) {
                authService.activeAlert = nil
            })
        }
    }
}
