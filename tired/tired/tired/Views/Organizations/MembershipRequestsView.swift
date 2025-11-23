import SwiftUI
import FirebaseFirestore

struct MembershipRequestsView: View {
    @StateObject private var viewModel: MembershipRequestsViewModel
    @Environment(\.dismiss) var dismiss
    private let organizationId: String

    init(organizationId: String) {
        self.organizationId = organizationId
        _viewModel = StateObject(wrappedValue: MembershipRequestsViewModel(organizationId: organizationId))
    }

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.pendingRequests.isEmpty {
                    Text("沒有待處理的申請")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(viewModel.pendingRequests) { request in
                        requestRow(for: request)
                    }
                }
            }
            .navigationTitle("成員申請")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func requestRow(for request: MembershipRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.userName)
                    .fontWeight(.bold)
                Text("申請加入於 \(formatDate(request.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    handleReject(request)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(action: {
                    handleApprove(request)
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func handleReject(_ request: MembershipRequest) {
        // Delegate to viewModel
        viewModel.handleReject(request)
    }
    
    private func handleApprove(_ request: MembershipRequest) {
        // Delegate to viewModel
        viewModel.handleApprove(request)
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        return date.formatted(date: .numeric, time: .shortened)
    }
}

struct MembershipRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        // Since the ViewModel requires a real organizationId,
        // a preview might be complex to set up here without a mock service.
        Text("MembershipRequestsView Preview")
    }
}
