import SwiftUI

@available(iOS 17.0, *)
struct AddTaskTimeSettingsView: View {
    @Binding var estimatedHours: Double
    @Binding var hasPlannedDate: Bool
    @Binding var plannedDate: Date
    @Binding var reminderEnabled: Bool
    @Binding var reminderDate: Date
    @Binding var hasDeadline: Bool
    @Binding var deadline: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間設定")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            // Estimated time
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("預估時長")
                    Spacer()
                    Text("\(formatHours(estimatedHours))")
                        .foregroundColor(.secondary)
                }
                Slider(value: $estimatedHours, in: 0.5...8, step: 0.5)
                    .tint(AppDesignSystem.accentColor)
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)

            // Planned date
            VStack(spacing: 8) {
                Toggle("排程到特定日期", isOn: $hasPlannedDate)

                if hasPlannedDate {
                    DatePicker("", selection: $plannedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
            
            // Reminder
            VStack(alignment: .leading, spacing: 8) {
                Toggle("開啟提醒", isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) {
                        normalizeReminderDate()
                    }

                if reminderEnabled {
                    DatePicker(
                        "提醒時間",
                        selection: $reminderDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .onChange(of: reminderDate) {
                        normalizeReminderDate()
                    }
                    
                    if hasDeadline {
                        Button {
                            reminderDate = max(Date().addingTimeInterval(300), deadline.addingTimeInterval(-900))
                        } label: {
                            Label("套用「截止前15分鐘」", systemImage: "bell.badge")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }
    
    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60)) 分鐘"
        } else if hours == floor(hours) {
            return "\(Int(hours)) 小時"
        } else {
            return String(format: "%.1f 小時", hours)
        }
    }
    
    private func normalizeReminderDate() {
        guard reminderEnabled else { return }
        var candidate = reminderDate
        if candidate < Date() {
            if hasDeadline {
                candidate = max(Date().addingTimeInterval(300), deadline.addingTimeInterval(-900))
            } else {
                candidate = Date().addingTimeInterval(900)
            }
        }
        reminderDate = candidate
    }
}
