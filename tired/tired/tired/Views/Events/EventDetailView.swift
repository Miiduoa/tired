import SwiftUI
import Combine
import FirebaseAuth

@available(iOS 17.0, *)
struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventDetailViewModel // Use a dedicated ViewModel

    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false

    init(eventId: String) {
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("載入活動詳情...")
                } else if let event = viewModel.event {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Event Title
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.title)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .padding(.bottom, 4)

                                // Organization Name
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.secondary)
                                    Text(viewModel.organizationName)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()

                            Divider()

                            // Event Details
                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(icon: "calendar", iconColor: .blue, title: "開始時間", value: event.startAt.formatDateTime())
                                if let endAt = event.endAt {
                                    InfoRow(icon: "calendar.badge.clock", iconColor: .blue, title: "結束時間", value: endAt.formatDateTime())
                                }
                                if let location = event.location {
                                    InfoRow(icon: "mappin.and.ellipse", iconColor: .red, title: "地點", value: location)
                                }
                                if let capacity = event.capacity {
                                    InfoRow(icon: "person.2.fill", iconColor: .green, title: "人數限制", value: "\(capacity) 人")
                                }
                                if let description = event.description, !description.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .foregroundColor(.gray)
                                                .frame(width: 24)
                                            Text("描述")
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 12)

                                        Text(description)
                                            .font(.body)
                                            .padding(.horizontal)
                                            .padding(.bottom, 12)
                                    }
                                    .background(Color.appSecondaryBackground.opacity(0.5))
                                    .cornerRadius(AppDesignSystem.cornerRadiusMedium)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .navigationTitle("活動詳情")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("關閉") { dismiss() }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("編輯") {
                                showingEditView = true
                            }
                        }
                        ToolbarItem(placement: .destructiveAction) {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .sheet(isPresented: $showingEditView) {
                        EditEventView(event: event, viewModel: viewModel)
                    }
                    .confirmationDialog("刪除活動", isPresented: $showingDeleteConfirmation) {
                        Button("刪除", role: .destructive) {
                            viewModel.deleteEvent()
                            dismiss() // Dismiss after delete attempt
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("您確定要刪除此活動嗎？此操作無法撤銷。")
                    }
                } else {
                    Text("無法載入活動詳情。\(viewModel.errorMessage ?? "")")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .background(Color.appBackground)
            .onAppear {
                viewModel.fetchEvent()
            }
        }
    }
}

// Dedicated ViewModel for EventDetailView
class EventDetailViewModel: ObservableObject {
