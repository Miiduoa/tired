import SwiftUI

@available(iOS 17.0, *)
struct WeeklyCapacityView: View {
    let stats: [(day: Date, duration: Int)]
    let dailyCapacity: Int

    private var totalMinutes: Int {
        stats.reduce(0) { $0 + $1.duration }
    }

    private var weeklyCapacity: Int {
        dailyCapacity * 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本週工作量")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(totalMinutes / 60) / \(weeklyCapacity / 60) 小時")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(totalMinutes > weeklyCapacity ? .red : .secondary)
            }

            // Progress bars for each day
            HStack(spacing: 4) {
                ForEach(stats.indices, id: \.self) { index in
                    let stat = stats[index]
                    let progress = min(1.0, Double(stat.duration) / Double(dailyCapacity))
                    let isOverloaded = stat.duration > dailyCapacity

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isOverloaded ? Color.red : AppDesignSystem.accentColor)
                            .frame(height: 40 * progress)
                            .frame(maxHeight: 40, alignment: .bottom)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 40)
                            )

                        Text(dayAbbreviation(stat.day))
                            .font(.system(size: 10))
                            .foregroundColor(Calendar.current.isDateInToday(stat.day) ? AppDesignSystem.accentColor : .secondary)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
}
