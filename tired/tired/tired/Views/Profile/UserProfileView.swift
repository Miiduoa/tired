import SwiftUI
import FirebaseAuth

@available(iOS 17.0, *)
struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    
    init(userId: String) {
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if let profile = viewModel.userProfile {
                VStack(spacing: 20) {
                    // Header
                    ProfileHeaderView(profile: profile)


                    // Organizations
                    OrganizationsSectionView(memberships: viewModel.memberships)
                    
                    // More sections can be added here (e.g., recent activity)
                    
                    Spacer()
                }
            } else {
                ContentUnavailableView("無法載入使用者", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(viewModel.errorMessage ?? "發生未知錯誤。"))
            }
        }
        .navigationTitle(viewModel.userProfile?.name ?? "個人資料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchUserData()
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
    }
}

@available(iOS 17.0, *)
private struct ProfileHeaderView: View {
    let profile: UserProfile
    
    // State for programmatic navigation to chat
    @State private var isChatViewActive = false
    @State private var chatRoomId: String?
    @State private var isLoadingChat = false
    
    // State for follow functionality
    @State private var isFollowing = false
    @State private var isLoadingFollow = false
    
    private let userService = UserService()
    
    private var currentUserId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.secondary)
                )

            // Name and Email
            VStack {
                Text(profile.name)
                    .font(.system(size: 24, weight: .bold))
                Text(profile.email)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: startChat) {
                    if isLoadingChat {
                        ProgressView()
                    } else {
                        Label("訊息", systemImage: "message.fill")
                    }
                }
                .buttonStyle(GlassmorphicButtonStyle(cornerRadius: 12))
                .disabled(isLoadingChat)
                
                Button(action: toggleFollow) {
                    if isLoadingFollow {
                        ProgressView()
                    } else {
                        Label(isFollowing ? "已追蹤" : "追蹤", systemImage: isFollowing ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                    }
                }
                .buttonStyle(GlassmorphicButtonStyle(cornerRadius: 12))
                .disabled(isLoadingFollow || profile.id == currentUserId)
            }
        }
        .padding(.vertical, 24)
        .onAppear {
            checkFollowStatus()
        }
        .navigationDestination(isPresented: $isChatViewActive) {
            if let roomId = chatRoomId {
                ChatView(chatRoomId: roomId)
                    .navigationTitle(profile.name)
            }
        }
    }
    
    private func startChat() {
        guard let otherUserId = profile.id else { return }
        _Concurrency.Task {
            await MainActor.run { isLoadingChat = true }
            do {
                let roomId = try await ChatService.shared.getOrCreateDirectChatRoom(with: otherUserId)
                await MainActor.run {
                    self.chatRoomId = roomId
                    self.isChatViewActive = true
                }
            } catch {
                print("Error starting chat: \(error.localizedDescription)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "無法開啟聊天：\(error.localizedDescription)", type: .error)
                }
            }
            await MainActor.run { isLoadingChat = false }
        }
    }
    
    private func toggleFollow() {
        guard let otherUserId = profile.id,
              let currentUserId = currentUserId,
              otherUserId != currentUserId else {
            return
        }
        _Concurrency.Task {
            await MainActor.run { isLoadingFollow = true }
            do {
                if isFollowing {
                    try await userService.unfollowUser(followerId: currentUserId, followingId: otherUserId)
                    await MainActor.run {
                        isFollowing = false
                        ToastManager.shared.showToast(message: "已取消追蹤 \(profile.name)", type: .success)
                    }
                } else {
                    try await userService.followUser(followerId: currentUserId, followingId: otherUserId)
                    await MainActor.run {
                        isFollowing = true
                        ToastManager.shared.showToast(message: "已追蹤 \(profile.name)", type: .success)
                    }
                }
            } catch {
                print("Error toggling follow: \(error.localizedDescription)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "操作失敗：\(error.localizedDescription)", type: .error)
                }
            }
            await MainActor.run { isLoadingFollow = false }
        }
    }
    
    private func checkFollowStatus() {
        guard let otherUserId = profile.id,
              let currentUserId = currentUserId,
              otherUserId != currentUserId else {
            return
        }
        _Concurrency.Task {
            do {
                let following = try await userService.isFollowing(followerId: currentUserId, followingId: otherUserId)
                await MainActor.run { isFollowing = following }
            } catch {
                print("Error checking follow status: \(error.localizedDescription)")
            }
        }
    }
}

@available(iOS 17.0, *)
private struct OrganizationsSectionView: View {
    let memberships: [MembershipWithOrg]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("所屬組織")
                .font(.headline)
                .padding(.horizontal)
            
            if memberships.isEmpty {
                Text("尚未加入任何組織")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(memberships) { membership in
                            if let org = membership.organization {
                                UserProfileOrganizationCard(organization: org)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct UserProfileOrganizationCard: View {
    let organization: Organization
    
    var body: some View {
        VStack {
            // Placeholder for org avatar
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 60, height: 60)
            
            Text(organization.name)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(16)
    }
}
