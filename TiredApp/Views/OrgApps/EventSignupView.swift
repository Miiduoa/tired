import SwiftUI
import Combine

@available(iOS 17.0, *)
struct EventSignupView: View {
    let appInstance: OrgAppInstance
    let organizationId: String

    @StateObject private var viewModel: EventSignupViewModel
    @State private var showingCreateEvent = false

    init(appInstance: OrgAppInstance, organizationId: String) {
        self.appInstance = appInstance
        self.organizationId = organizationId
        self._viewModel = StateObject(wrappedValue: EventSignupViewModel(
            appInstanceId: appInstance.id ?? "",
            organizationId: organizationId
        ))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.events.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.events) { event in
                        EventCard(
                            event: event,
                            isRegistered: viewModel.isRegistered(eventId: event.id ?? ""),
                            registrationCount: viewModel.getRegistrationCount(eventId: event.id ?? ""),
                            onRegister: {
                                viewModel.registerForEvent(event: event)
                            },
                            onCancel: {
                                viewModel.cancelRegistration(event: event)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle(appInstance.name ?? "活動報名")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateEvent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暫無活動")
                .font(.system(size: 18, weight: .semibold))

            if viewModel.canManage {
                Text("點擊右上角 + 號創建新活動")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("組織管理員會在這裡發布活動")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Event Card

@available(iOS 17.0, *)
struct EventCard: View {
    let event: Event
    let isRegistered: Bool
    let registrationCount: Int
    let onRegister: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))

                    if let description = event.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isRegistered {
                    Text("已報名")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }

            Divider()

            // Event details
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    Text(event.startAt.formatLong())
                        .font(.system(size: 13))
                    Spacer()
                }

                if let endAt = event.endAt {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("\(event.startAt.formatTime()) - \(endAt.formatTime())")
                            .font(.system(size: 13))
                        Spacer()
                    }
                }

                if let location = event.location {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text(location)
                            .font(.system(size: 13))
                        Spacer()
                    }
                }

                if let capacity = event.capacity {
                    HStack {
                        Image(systemName: "person.2")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("\(registrationCount) / \(capacity) 人")
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
            }

            // Action button
            Button(action: isRegistered ? onCancel : onRegister) {
                Text(isRegistered ? "取消報名" : "立即報名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isRegistered ? .red : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isRegistered ? Color.red.opacity(0.1) : Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Create Event View

@available(iOS 17.0, *)
struct CreateEventView: View {
    @ObservedObject var viewModel: EventSignupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var startAt = Date()
    @State private var endAt = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var hasCapacity = false
    @State private var capacity: Int = 50
    @State private var isCreating = false

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
            .navigationTitle("創建活動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("創建") {
                        createEvent()
                    }
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }

    private func createEvent() {
        isCreating = true

        Task {
            do {
                try await viewModel.createEvent(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    startAt: startAt,
                    endAt: endAt,
                    location: location.isEmpty ? nil : location,
                    capacity: hasCapacity ? capacity : nil
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating event: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - EventSignup ViewModel

class EventSignupViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var registrations: [String: Bool] = [:] // eventId: isRegistered
    @Published var registrationCounts: [String: Int] = [:] // eventId: count
    @Published var canManage = false

    let appInstanceId: String
    let organizationId: String
    private let eventService = EventService()
    private var cancellables = Set<AnyCancellable>()

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(appInstanceId: String, organizationId: String) {
        self.appInstanceId = appInstanceId
        self.organizationId = organizationId
        setupSubscriptions()
        checkPermissions()
    }

    private func setupSubscriptions() {
        eventService.fetchOrganizationEvents(organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] events in
                    self?.events = events
                    self?.loadRegistrationData(for: events)
                }
            )
            .store(in: &cancellables)
    }

    private func loadRegistrationData(for events: [Event]) {
        guard let userId = userId else { return }

        Task {
            for event in events {
                guard let eventId = event.id else { continue }

                // 檢查是否已報名
                let isReg = (try? await eventService.isUserRegistered(eventId: eventId, userId: userId)) ?? false

                // 獲取報名人數
                let count = (try? await eventService.getRegistrationCount(eventId: eventId)) ?? 0

                await MainActor.run {
                    self.registrations[eventId] = isReg
                    self.registrationCounts[eventId] = count
                }
            }
        }
    }

    private func checkPermissions() {
        guard let userId = userId else { return }

        Task {
            do {
                let snapshot = try await FirebaseManager.shared.db
                    .collection("memberships")
                    .whereField("userId", isEqualTo: userId)
                    .whereField("organizationId", isEqualTo: organizationId)
                    .getDocuments()

                if let doc = snapshot.documents.first,
                   let membership = try? doc.data(as: Membership.self) {
                    await MainActor.run {
                        self.canManage = membership.role == .owner || membership.role == .admin
                    }
                }
            } catch {
                print("❌ Error checking permissions: \(error)")
            }
        }
    }

    func isRegistered(eventId: String) -> Bool {
        registrations[eventId] ?? false
    }

    func getRegistrationCount(eventId: String) -> Int {
        registrationCounts[eventId] ?? 0
    }

    func createEvent(title: String, description: String?, startAt: Date, endAt: Date, location: String?, capacity: Int?) async throws {
        let event = Event(
            orgAppInstanceId: appInstanceId,
            organizationId: organizationId,
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            location: location,
            capacity: capacity
        )

        _ = try await eventService.createEvent(event)
    }

    func registerForEvent(event: Event) {
        guard let userId = userId, let eventId = event.id else { return }

        Task {
            do {
                try await eventService.registerForEvent(eventId: eventId, userId: userId)

                await MainActor.run {
                    self.registrations[eventId] = true
                    self.registrationCounts[eventId] = (self.registrationCounts[eventId] ?? 0) + 1
                }

                // Note: 任務已由 EventService.registerForEvent() 自動創建
            } catch {
                print("❌ Error registering for event: \(error)")
            }
        }
    }

    func cancelRegistration(event: Event) {
        guard let userId = userId, let eventId = event.id else { return }

        Task {
            do {
                try await eventService.cancelRegistration(eventId: eventId, userId: userId)

                await MainActor.run {
                    self.registrations[eventId] = false
                    self.registrationCounts[eventId] = max(0, (self.registrationCounts[eventId] ?? 1) - 1)
                }
            } catch {
                print("❌ Error canceling registration: \(error)")
            }
        }
    }
}
