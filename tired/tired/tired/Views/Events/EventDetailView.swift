import SwiftUI
import Combine
import FirebaseAuth

@available(iOS 17.0, *)
struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EventDetailViewModel // Use a dedicated ViewModel

    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false
    @State private var isProcessingDelete = false

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
                                EventInfoRow(icon: "calendar", iconColor: .blue, title: "開始時間", value: event.startAt.formatDateTime())
                                if let endAt = event.endAt {
                                    EventInfoRow(icon: "calendar.badge.clock", iconColor: .blue, title: "結束時間", value: endAt.formatDateTime())
                                }
                                if let location = event.location {
                                    EventInfoRow(icon: "mappin.and.ellipse", iconColor: .red, title: "地點", value: location)
                                }
                                if let capacity = event.capacity {
                                    EventInfoRow(icon: "person.2.fill", iconColor: .green, title: "人數限制", value: "\(capacity) 人")
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
                            _Concurrency.Task {
                                guard !isProcessingDelete else { return }
                                await MainActor.run { isProcessingDelete = true }
                                let success = await viewModel.deleteEventAsync()
                                await MainActor.run { isProcessingDelete = false }
                                if success {
                                    dismiss()
                                }
                            }
                        }
                        Button("取消", role: .cancel) {
                            // 明確關閉刪除確認
                            showingDeleteConfirmation = false
                        }
                    } message: {
                        if isProcessingDelete {
                            Text("正在刪除，請稍候...")
                        } else {
                            Text("您確定要刪除此活動嗎？此操作無法撤銷。")
                        }
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
    @Published var organizationName = ""
    
    private let eventId: String
    private let eventService = EventService()
    private let organizationService = OrganizationService()
    
    init(eventId: String) {
        self.eventId = eventId
    }
    
    func fetchEvent() {
        _Concurrency.Task {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }

            do {
                let fetchedEvent = try await eventService.fetchEvent(id: eventId)
                await MainActor.run {
                    self.event = fetchedEvent
                    self.isLoading = false
                    _Concurrency.Task {
                        await self.fetchOrganizationName(orgId: fetchedEvent.organizationId)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchOrganizationName(orgId: String) async {
        do {
            let org = try await organizationService.fetchOrganization(id: orgId)
            await MainActor.run {
                self.organizationName = org.name
            }
        } catch {
            await MainActor.run {
                self.organizationName = "未知組織"
            }
        }
    }
    
    func deleteEvent() {
        guard event != nil else { return }
        
        _Concurrency.Task {
            do {
                try await eventService.deleteEvent(id: eventId)
            } catch {
                await MainActor.run {
                    self.errorMessage = "刪除失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    // Async wrapper that returns success state so UI can react accordingly
    func deleteEventAsync() async -> Bool {
        guard event != nil else {
            await MainActor.run {
                self.errorMessage = "找不到活動"
            }
            return false
        }

        do {
            try await eventService.deleteEvent(id: eventId)
            await MainActor.run {
                ToastManager.shared.showToast(message: "活動已刪除", type: .success)
            }
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "刪除失敗: \(error.localizedDescription)"
                ToastManager.shared.showToast(message: "刪除失敗: \(error.localizedDescription)", type: .error)
            }
            return false
        }
    }
    
    func updateEvent(
        title: String,
        description: String?,
        startAt: Date,
        endAt: Date,
        location: String?,
        capacity: Int?
    ) async throws {
        guard var eventToUpdate = event else {
            throw NSError(domain: "EventDetailViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        }
        
        eventToUpdate.title = title
        eventToUpdate.description = description
        eventToUpdate.startAt = startAt
        eventToUpdate.endAt = endAt
        eventToUpdate.location = location
        eventToUpdate.capacity = capacity
        eventToUpdate.updatedAt = Date()
        
        try await eventService.updateEvent(eventToUpdate)
        
        await MainActor.run {
            self.event = eventToUpdate
        }
    }
}

// Helper view for info rows
private struct EventInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Edit Event View

@available(iOS 17.0, *)
struct EditEventView: View {
    let event: Event
    @ObservedObject var viewModel: EventDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var location: String
    @State private var hasCapacity: Bool
    @State private var capacity: Int
    @State private var isUpdating = false
    
    init(event: Event, viewModel: EventDetailViewModel) {
        self.event = event
        self.viewModel = viewModel
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description ?? "")
        _startAt = State(initialValue: event.startAt)
        _endAt = State(initialValue: event.endAt ?? event.startAt.addingTimeInterval(3600))
        _location = State(initialValue: event.location ?? "")
        _hasCapacity = State(initialValue: event.capacity != nil)
        _capacity = State(initialValue: event.capacity ?? 50)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("活動名稱", text: $title)
                    TextField("活動描述", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("時間") {
                    DatePicker("開始時間", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("結束時間", selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("地點") {
                    TextField("活動地點", text: $location)
                }
                
                Section("人數限制") {
                    Toggle("限制人數", isOn: $hasCapacity)
                    if hasCapacity {
                        Stepper("最多 \(capacity) 人", value: $capacity, in: 1...1000)
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
                        updateEvent()
                    }
                    .disabled(title.isEmpty || isUpdating)
                }
            }
        }
    }
    
    private func updateEvent() {
        _Concurrency.Task {
            await MainActor.run { isUpdating = true }

            do {
                try await viewModel.updateEvent(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    startAt: startAt,
                    endAt: endAt,
                    location: location.isEmpty ? nil : location,
                    capacity: hasCapacity ? capacity : nil
                )
                await MainActor.run {
                    ToastManager.shared.showToast(message: "活動更新成功！", type: .success)
                    dismiss()
                }
            } catch {
                print("❌ Error updating event: \(error)")
                await MainActor.run {
                    ToastManager.shared.showToast(message: "更新失敗: \(error.localizedDescription)", type: .error)
                    isUpdating = false
                }
            }
        }
    }
}

