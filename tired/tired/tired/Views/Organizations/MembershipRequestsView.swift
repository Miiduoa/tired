import SwiftUI
import FirebaseFirestore

@available(iOS 17.0, *)
struct MembershipRequestsView: View {
    @StateObject private var viewModel: MembershipRequestsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedRequests: Set<String> = []
    @State private var isSelecting = false
    private let organizationId: String

    init(organizationId: String) {
        self.organizationId = organizationId
        _viewModel = StateObject(wrappedValue: MembershipRequestsViewModel(organizationId: organizationId))
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                Group {
                    if viewModel.isLoading {
                        ProgressView("載入申請中...")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    } else if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.red)
                            .padding()
                            .glassmorphicCard()
                    } else if viewModel.pendingRequests.isEmpty {
                        Text("沒有待處理的申請")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                            .padding()
                            .glassmorphicCard()
                    } else {
                        List(viewModel.pendingRequests) { request in
                            MembershipRequestRowView(
                                viewModel: viewModel,
                                request: request,
                                isSelecting: isSelecting,
                                isSelected: selectedRequests.contains(request.id ?? ""),
                                onToggleSelection: {
                                    if let id = request.id {
                                        if selectedRequests.contains(id) {
                                            selectedRequests.remove(id)
                                        } else {
                                            selectedRequests.insert(id)
                                        }
                                    }
                                }
                            )
                            .listRowBackground(Color.clear) // Make list row transparent
                        }
                        .listStyle(.plain) // Use plain list style for custom backgrounds
                    }
                }
                .navigationTitle("成員申請")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("關閉") {
                            dismiss()
                        }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                    }
                    
                    if !viewModel.pendingRequests.isEmpty {
                        ToolbarItem(placement: .primaryAction) {
                            Button(isSelecting ? "完成" : "選擇") {
                                withAnimation {
                                    isSelecting.toggle()
                                    if !isSelecting {
                                        selectedRequests.removeAll()
                                    }
                                }
                            }
                        }
                        
                        if isSelecting && !selectedRequests.isEmpty {
                            ToolbarItem(placement: .primaryAction) {
                                Menu {
                                    Button {
                                        batchApprove()
                                    } label: {
                                        Label("批量批准 (\(selectedRequests.count))", systemImage: "checkmark.circle.fill")
                                    }
                                    
                                    Button(role: .destructive) {
                                        batchReject()
                                    } label: {
                                        Label("批量拒絕 (\(selectedRequests.count))", systemImage: "xmark.circle.fill")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                }
                .background(Color.clear) // Make NavigationView's background clear
            }
        }
    }

    private func batchApprove() {
        let requestsToApprove = viewModel.pendingRequests.filter { request in
            guard let id = request.id else { return false }
            return selectedRequests.contains(id)
        }
        
        _Concurrency.Task {
            for request in requestsToApprove {
                _ = await viewModel.approveRequestAsync(request)
            }
            await MainActor.run {
                selectedRequests.removeAll()
                isSelecting = false
            }
        }
    }
    
    private func batchReject() {
        let requestsToReject = viewModel.pendingRequests.filter { request in
            guard let id = request.id else { return false }
            return selectedRequests.contains(id)
        }
        
        _Concurrency.Task {
            for request in requestsToReject {
                _ = await viewModel.rejectRequestAsync(request)
            }
            await MainActor.run {
                selectedRequests.removeAll()
                isSelecting = false
            }
        }
    }
    
    private struct MembershipRequestRowView: View {
        @ObservedObject var viewModel: MembershipRequestsViewModel
        let request: MembershipRequest
        let isSelecting: Bool
        let isSelected: Bool
        let onToggleSelection: () -> Void
        @State private var isProcessingApprove = false
        @State private var isProcessingReject = false

        var body: some View {
            HStack {
                if isSelecting {
                    Button {
                        onToggleSelection()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? AppDesignSystem.accentColor : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                    Text(request.userName)
                        .font(AppDesignSystem.bodyFont.weight(.bold))
                        .foregroundColor(.primary)
                    Text("申請加入於 \(formatDate(request.createdAt))")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !isSelecting {
                    HStack(spacing: AppDesignSystem.paddingMedium) {
                        Button(action: {
                            _Concurrency.Task {
                                guard !isProcessingReject else { return }
                                isProcessingReject = true
                                let success = await viewModel.rejectRequestAsync(request)
                                isProcessingReject = false
                                if success { AlertHelper.shared.showSuccess("已拒絕申請") }
                            }
                        }) {
                            if isProcessingReject {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            _Concurrency.Task {
                                guard !isProcessingApprove else { return }
                                isProcessingApprove = true
                                let success = await viewModel.approveRequestAsync(request)
                                isProcessingApprove = false
                                if success { AlertHelper.shared.showSuccess("已批准申請") }
                            }
                        }) {
                            if isProcessingApprove {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(AppDesignSystem.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
        }

        private func formatDate(_ timestamp: Timestamp) -> String {
            let date = timestamp.dateValue()
            return date.formatted(date: .numeric, time: .shortened)
        }
    }
    
    private func formatDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        return date.formatted(date: .numeric, time: .shortened)
    }
}