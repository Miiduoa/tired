import Foundation
import Combine
import FirebaseFirestore

class MembershipRequestsViewModel: ObservableObject {
    @Published var pendingRequests: [MembershipRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let organizationId: String
    private let organizationService = OrganizationService()
    private var listener: ListenerRegistration?

    init(organizationId: String) {
        self.organizationId = organizationId
        fetchPendingRequests()
    }

    deinit {
        listener?.remove()
    }

    /// 獲取並監聽待處理的申請
    func fetchPendingRequests() {
        isLoading = true
        errorMessage = nil

        listener = FirebaseManager.shared.db.collection("membershipRequests")
            .whereField("organizationId", isEqualTo: organizationId)
            .whereField("status", isEqualTo: MembershipRequest.RequestStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = "讀取申請列表失敗: \(error.localizedDescription)"
                        print("❌ Error fetching membership requests: \(error)")
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.pendingRequests = []
                        return
                    }

                    self.pendingRequests = documents.compactMap { doc -> MembershipRequest? in
                        try? doc.data(as: MembershipRequest.self)
                    }
                }
            }
    }

    /// 批准申請
    func approveRequest(_ request: MembershipRequest) async {
        do {
            try await organizationService.approveMembershipRequest(request: request)
        } catch {
            await MainActor.run {
                errorMessage = "批准申請失敗: \(error.localizedDescription)"
            }
        }
    }

    /// 拒絕申請
    func rejectRequest(_ request: MembershipRequest) async {
        do {
            try await organizationService.rejectMembershipRequest(request: request)
        } catch {
            await MainActor.run {
                errorMessage = "拒絕申請失敗: \(error.localizedDescription)"
            }
        }
    }

    /// 非同步版本（回傳成功/失敗）供 UI 使用
    func approveRequestAsync(_ request: MembershipRequest) async -> Bool {
        do {
            try await organizationService.approveMembershipRequest(request: request)
            await MainActor.run { AlertHelper.shared.showSuccess("已批准申請") }
            return true
        } catch {
            print("❌ approveRequestAsync error: \(error)")
            await MainActor.run { AlertHelper.shared.showError("批准申請失敗：\(error.localizedDescription)") }
            return false
        }
    }

    func rejectRequestAsync(_ request: MembershipRequest) async -> Bool {
        do {
            try await organizationService.rejectMembershipRequest(request: request)
            await MainActor.run { AlertHelper.shared.showSuccess("已拒絕申請") }
            return true
        } catch {
            print("❌ rejectRequestAsync error: \(error)")
            await MainActor.run { AlertHelper.shared.showError("拒絕申請失敗：\(error.localizedDescription)") }
            return false
        }
    }

    /// 包裝給 View 使用的同步方法
    func handleReject(_ request: MembershipRequest) {
        _Concurrency.Task {
            await self.rejectRequest(request)
        }
    }

    func handleApprove(_ request: MembershipRequest) {
        _Concurrency.Task {
            await self.approveRequest(request)
        }
    }
}
