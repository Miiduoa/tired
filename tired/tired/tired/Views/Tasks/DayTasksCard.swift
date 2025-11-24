import SwiftUI

@available(iOS 17.0, *)
struct DayTasksCard: View {
    let date: Date
    let duration: Int
    let tasks: [Task]
    let onToggle: (Task) -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatLong())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isToday ? AppDesignSystem.accentColor : .primary)

                    if isToday {
                        Text("今天")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppDesignSystem.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppDesignSystem.accentColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tasks.count) 項任務")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("約 \(duration / 60) 小時")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Tasks
            if tasks.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.secondary)
                    Text("沒有排程的任務")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, AppDesignSystem.paddingSmall)
            } else {
                ForEach(tasks) { task in
                    CompactTaskRow(task: task) {
                        onToggle(task)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
        .overlay(
            isToday ?
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(AppDesignSystem.accentColor, lineWidth: 2) :
            nil
        )
    }
}
