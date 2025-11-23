import SwiftUI

// MARK: - My Events View

@available(iOS 17.0, *)
struct MyEventsView: View {
    @StateObject private var viewModel = MyEventsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if viewModel.events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("還沒有報名任何活動")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("前往組織頁面查看並報名活動")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                // Upcoming events
                let upcomingEvents = viewModel.events.filter { $0.event.startAt > Date() }
                if !upcomingEvents.isEmpty {
                    Section("即將到來") {
                        ForEach(upcomingEvents) { eventWithReg in
                            MyEventRow(eventWithReg: eventWithReg)
                        }
                    }
                }

                // Past events
                let pastEvents = viewModel.events.filter { $0.event.startAt <= Date() }
                if !pastEvents.isEmpty {
                    Section("已結束") {
                        ForEach(pastEvents) { eventWithReg in
                            MyEventRow(eventWithReg: eventWithReg)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的活動")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadEvents()
        }
    }
}

// MARK: - My Event Row

@available(iOS 17.0, *)
struct MyEventRow: View {
    let eventWithReg: EventWithRegistration

    var isUpcoming: Bool {
        eventWithReg.event.startAt > Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(eventWithReg.event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isUpcoming ? .primary : .secondary)

                Spacer()

                if isUpcoming {
                    Text("即將開始")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            HStack(spacing: 12) {
                Label(eventWithReg.event.startAt.formatLong(), systemImage: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if let location = eventWithReg.event.location {
                    Label(location, systemImage: "mappin")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if let orgName = eventWithReg.organization?.name {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.system(size: 10))
                    Text(orgName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
