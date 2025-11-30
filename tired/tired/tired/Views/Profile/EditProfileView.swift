import SwiftUI
import FirebaseAuth

@available(iOS 17.0, *)
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var name: String = ""
    @State private var avatarUrl: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    private let userService = UserService.shared
    
    var body: some View {
        Form {
            Section(header: Text("個人資訊")) {
                TextField("顯示名稱", text: $name)
                    .autocorrectionDisabled()
                
                // In a real app, this would be an image uploader. 
                // For now, we allow editing the URL directly or clearing it.
                TextField("頭像 URL (選填)", text: $avatarUrl)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                
                if !avatarUrl.isEmpty {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding(.vertical, 4)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("編輯個人資料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveProfile()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("儲存")
                    }
                }
                .disabled(name.isEmpty || isLoading)
            }
        }
        .onAppear {
            if let profile = authService.userProfile {
                name = profile.name
                avatarUrl = profile.avatarUrl ?? ""
            }
        }
    }
    
    private func saveProfile() {
        guard let userId = authService.currentUser?.uid else { return }
        
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task {
            do {
                let finalAvatarUrl = avatarUrl.isEmpty ? nil : avatarUrl
                try await userService.updateUserProfile(
                    userId: userId,
                    name: name,
                    avatarUrl: finalAvatarUrl
                )
                
                // Refresh local profile in AuthService
                await MainActor.run {
                    authService.fetchUserProfile(uid: userId) // Corrected: Added uid parameter
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "更新失敗：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

