import SwiftUI

// MARK: - My Events View

@available(iOS 17.0, *)
struct MyEventsView: View {
    @StateObject private var viewModel = MyEventsViewModel()

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                List {
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else if viewModel.events.isEmpty {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("還沒有報名任何活動")
                                .font(AppDesignSystem.headlineFont)
                                .foregroundColor(.primary)
                            Text("前往身份頁面查看並報名活動")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(AppDesignSystem.paddingLarge)
                        .glassmorphicCard() // Apply glassmorphic to empty state
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingLarge, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))

                    } else {
                        // Upcoming events
                        let upcomingEvents = viewModel.events.filter { $0.event.startAt > Date() }
                        if !upcomingEvents.isEmpty {
                            Section {
                                ForEach(upcomingEvents) { eventWithReg in
                                    MyEventRow(eventWithReg: eventWithReg)
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                Text("即將到來")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Past events
                        let pastEvents = viewModel.events.filter { $0.event.startAt <= Date() }
                        if !pastEvents.isEmpty {
                            Section {
                                ForEach(pastEvents) { eventWithReg in
                                    MyEventRow(eventWithReg: eventWithReg)
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                Text("已結束")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped) // Use inset grouped to make sections glassmorphic
                .navigationTitle("我的活動")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    await viewModel.loadEvents()
                }
                .background(Color.clear) // Make NavigationView's background clear
            }
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
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack {
                Text(eventWithReg.event.title)
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                    .foregroundColor(isUpcoming ? .primary : .secondary)

                Spacer()

                if isUpcoming {
                    Text("即將開始")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(AppDesignSystem.accentColor)
                        .padding(.horizontal, AppDesignSystem.paddingSmall)
                        .padding(.vertical, AppDesignSystem.paddingSmall / 2)
                        .background(AppDesignSystem.accentColor.opacity(0.1))
                        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                }
            }

            HStack(spacing: AppDesignSystem.paddingSmall) {
                Label(eventWithReg.event.startAt.formatLong(), systemImage: "calendar")
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)

                if let location = eventWithReg.event.location {
                    Label(location, systemImage: "mappin")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if let orgName = eventWithReg.organization?.name {
                HStack(spacing: AppDesignSystem.paddingSmall / 2) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                    Text(orgName)
                        .font(AppDesignSystem.captionFont)
                }
                .foregroundColor(AppDesignSystem.accentColor)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
    }
}