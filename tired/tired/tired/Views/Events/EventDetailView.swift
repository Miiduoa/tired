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
    @Published var event: Event?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var organizationName: String = "" // To display org name

    private let eventService = EventService()
    private let organizationService = OrganizationService()
    private let eventId: String
    private var cancellables = Set<AnyCancellable>()

    init(eventId: String) {
        self.eventId = eventId
    }

    func fetchEvent() {
        isLoading = true
        errorMessage = nil

        _Concurrency.Task { @MainActor in
            do {
                self.event = try await eventService.fetchEvent(id: eventId)
                if let orgId = self.event?.organizationId {
                    let org = try await organizationService.fetchOrganization(id: orgId)
                    self.organizationName = org.name
                }
            } catch {
                self.errorMessage = "載入活動詳情失敗: \(error.localizedDescription)"
                ToastManager.shared.showToast(message: "載入活動詳情失敗: \(error.localizedDescription)", type: .error)
            }
            self.isLoading = false
        }
    }

    func deleteEvent() {
        guard let eventId = event?.id else { return }
        _Concurrency.Task { @MainActor in
            do {
                try await eventService.deleteEvent(id: eventId)
                ToastManager.shared.showToast(message: "活動已成功刪除！", type: .success)
            } catch {
                ToastManager.shared.showToast(message: "刪除活動失敗: \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    // Function to handle updates from EditEventView
    func updateEvent(updatedEvent: Event) {
        // This will trigger a re-render if the event object changes
        self.event = updatedEvent
        ToastManager.shared.showToast(message: "活動已成功更新！", type: .success)
    }
}

// TODO: Create EditEventView similarly to EditTaskView
@available(iOS 17.0, *)
struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: EventDetailViewModel
    
    @State private var editedEvent: Event
    @State private var isSaving = false
    
    init(event: Event, viewModel: EventDetailViewModel) {
        self.viewModel = viewModel
        _editedEvent = State(initialValue: event)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("活動名稱", text: $editedEvent.title)
                    TextField("活動描述", text: Binding(get: { editedEvent.description ?? "" }, set: { editedEvent.description = $0.isEmpty ? nil : $0 }), axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("時間") {
                    DatePicker("開始時間", selection: $editedEvent.startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("結束時間", selection: Binding(get: { editedEvent.endAt ?? editedEvent.startAt.addingTimeInterval(3600) }, set: { editedEvent.endAt = $0 }), displayedComponents: [.date, .hourAndMinute])
                }

                Section("地點") {
                    TextField("活動地點", text: Binding(get: { editedEvent.location ?? "" }, set: { editedEvent.location = $0.isEmpty ? nil : $0 }))
                }

                Section("人數限制") {
                    Toggle("限制人數", isOn: Binding(get: { editedEvent.capacity != nil }, set: { newValue in
                        if newValue {
                            editedEvent.capacity = editedEvent.capacity ?? 50
                        } else {
                            editedEvent.capacity = nil
                        }
                    }))
                    if editedEvent.capacity != nil {
                        Stepper("最多 \(editedEvent.capacity ?? 0) 人", value: Binding(get: { editedEvent.capacity ?? 0 }, set: { editedEvent.capacity = $0 }), in: 1...1000)
                    }
                }
            }
            .navigationTitle("編輯活動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveEvent()
                    }
                    .disabled(editedEvent.title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveEvent() {
        isSaving = true
        _Concurrency.Task { @MainActor in
            do {
                try await EventService().updateEvent(editedEvent)
                viewModel.updateEvent(updatedEvent: editedEvent) // Notify detail view to update
                dismiss()
            } catch {
                ToastManager.shared.showToast(message: "更新活動失敗: \(error.localizedDescription)", type: .error)
            }
            isSaving = false
        }
    }
}
