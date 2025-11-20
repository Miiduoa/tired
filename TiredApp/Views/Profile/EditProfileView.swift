import SwiftUI
import PhotosUI

@available(iOS 17.0, *)
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    @State private var name: String
    @State private var email: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isUpdating = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(profile: UserProfile) {
        _name = State(initialValue: profile.name)
        _email = State(initialValue: profile.email)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    // 頭像
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let imageData = selectedImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let avatarUrl = authService.userProfile?.avatarUrl {
                                AsyncImage(url: URL(string: avatarUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    avatarPlaceholder
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                avatarPlaceholder
                            }

                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("更換頭像")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            .onChange(of: selectedItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        selectedImageData = data
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("基本信息") {
                    TextField("名稱", text: $name)

                    HStack {
                        Text("Email")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(email)
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("Email 無法修改")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("編輯資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isUpdating = true

        Task {
            do {
                var updates: [String: Any] = ["name": trimmedName]

                // 如果有選擇新頭像，上傳到 Firebase Storage 並更新 avatarUrl
                if let imageData = selectedImageData,
                   let image = UIImage(data: imageData),
                   let userId = FirebaseAuth.Auth.auth().currentUser?.uid {
                    let storageService = StorageService()

                    // 調整大小和壓縮
                    let resizedImage = storageService.resizeImage(image, maxDimension: 400)
                    guard let compressedData = storageService.compressImage(resizedImage, maxSizeKB: 200) else {
                        throw NSError(domain: "EditProfileView", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "圖片處理失敗"])
                    }

                    // 上傳
                    let avatarUrl = try await storageService.uploadAvatar(userId: userId, imageData: compressedData)
                    updates["avatarUrl"] = avatarUrl
                }

                try await authService.updateUserProfile(updates)

                await MainActor.run {
                    isUpdating = false
                    alertMessage = "資料已更新"
                    showAlert = true

                    // 延遲關閉
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    alertMessage = "更新失敗：\(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
