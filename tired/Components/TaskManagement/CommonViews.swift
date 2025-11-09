import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "載入中..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                GlassButton(actionTitle, icon: "plus.circle.fill", style: .primary, action: action)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.6))

            VStack(spacing: 8) {
                Text("發生錯誤")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text(error.localizedDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let retryAction = retryAction {
                GlassButton("重試", icon: "arrow.clockwise", style: .primary, action: retryAction)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Toast Message
struct ToastMessage: View {
    let message: String
    let icon: String?
    var type: ToastType = .info

    @Binding var isShowing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(type.color)
            }

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }

    enum ToastType {
        case success
        case error
        case warning
        case info

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
}

// MARK: - Capacity Bar
struct CapacityBar: View {
    let ratio: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(fillColor)
                    .frame(width: min(CGFloat(ratio), 1.0) * geometry.size.width)
            }
        }
        .frame(height: height)
    }

    private var fillColor: Color {
        let level = CapacityCalculator.loadLevel(for: ratio)
        return Color(hex: level.color) ?? .blue
    }
}

// MARK: - Week Day Selector
struct WeekDaySelector: View {
    let weekStart: Date
    let selectedDate: Date?
    let onDateSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let date = DateUtils.addDays(weekStart, index)
                let isSelected = selectedDate != nil && DateUtils.isSameDay(date, selectedDate!)
                let isToday = DateUtils.isToday(date)

                VStack(spacing: 4) {
                    Text(DateUtils.weekdayName(date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday && !isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        onDateSelect(date)
                    }
                }
            }
        }
    }
}

// MARK: - Priority Picker
struct PriorityPicker: View {
    @Binding var priority: TaskPriority

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TaskPriority.allCases, id: \.self) { p in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        priority = p
                    }
                }) {
                    Text(p.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(priority == p ? .white : priorityColor(p))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(priority == p ? priorityColor(p) : priorityColor(p).opacity(0.1))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .P0: return .red
        case .P1: return .orange
        case .P2: return .blue
        case .P3: return .gray
        }
    }
}

// MARK: - Category Picker
struct CategoryPicker: View {
    @Binding var category: TaskCategory
    var excludeSchool: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TaskCategory.allCases.filter { !excludeSchool || $0 != .school }, id: \.self) { cat in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        category = cat
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon(cat))
                            .font(.system(size: 14))
                        Text(categoryText(cat))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(category == cat ? .white : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(category == cat ? Color.blue : Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func categoryIcon(_ category: TaskCategory) -> String {
        switch category {
        case .school: return "book.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    private func categoryText(_ category: TaskCategory) -> String {
        switch category {
        case .school: return "學校"
        case .work: return "工作"
        case .personal: return "個人"
        case .other: return "其他"
        }
    }
}

// MARK: - Previews
struct CommonViews_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                CapacityBar(ratio: 0.7, height: 8)
                    .frame(width: 200)

                PriorityPicker(priority: .constant(.P1))

                CategoryPicker(category: .constant(.school))
            }
            .padding()
        }
    }
}
