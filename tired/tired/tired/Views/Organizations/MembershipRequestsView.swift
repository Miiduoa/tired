import SwiftUI
import FirebaseFirestore

@available(iOS 17.0, *)
struct MembershipRequestsView: View {
    @StateObject private var viewModel: MembershipRequestsViewModel
    @Environment(\.dismiss) var dismiss
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
                            requestRow(for: request)
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
                }
                .background(Color.clear) // Make NavigationView's background clear
            }
        }
    }

    private func requestRow(for request: MembershipRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall / 2) {
                Text(request.userName)
                    .font(AppDesignSystem.bodyFont.weight(.bold))
                    .foregroundColor(.primary)
                Text("申請加入於 \(formatDate(request.createdAt))")
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: AppDesignSystem.paddingMedium) {
                Button(action: {
                    _Concurrency.Task { await viewModel.rejectRequest(request) }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Button(action: {
                    _Concurrency.Task { await viewModel.approveRequest(request) }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppDesignSystem.accentColor)
                }
                .buttonStyle(.plain)
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