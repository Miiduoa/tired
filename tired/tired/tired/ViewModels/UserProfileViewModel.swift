import Foundation
import Combine

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var memberships: [MembershipWithOrg] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let userId: String
    private let userService = UserService()
    private let organizationService = OrganizationService()
    private var cancellables = Set<AnyCancellable>()

    init(userId: String) {
        self.userId = userId
    }

    func fetchUserData() {
        cancellables.removeAll()
        isLoading = true
        errorMessage = nil
        
        _Concurrency.Task { @MainActor in
            do {
                // 先載入個人資料
                self.userProfile = try await userService.fetchUserProfile(userId: userId)
            } catch {
                self.errorMessage = "無法載入使用者資料: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            // 監聽所屬組織（Publisher）
            organizationService.fetchUserOrganizations(userId: self.userId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = "無法載入組織資訊: \(error.localizedDescription)"
                            self?.isLoading = false
                        }
                    },
                    receiveValue: { [weak self] memberships in
                        self?.memberships = memberships
                        self?.isLoading = false
                    }
                )
                .store(in: &cancellables)
        }
    }
}
