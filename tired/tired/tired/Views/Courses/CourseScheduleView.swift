import SwiftUI
import FirebaseAuth

/// 課程時間表視圖 - Moodle-like 課表顯示
@available(iOS 17.0, *)
struct CourseScheduleView: View {
    let organizationId: String
    let organizationName: String

    @StateObject private var viewModel = CourseScheduleViewModel()
    @State private var selectedSchedule: CourseSchedule?
    @State private var showingScheduleDetail = false

    // 便利初始化器 - 從 OrgAppInstance 創建
    init(appInstance: OrgAppInstance) {
        self.organizationId = appInstance.organizationId
        self.organizationName = appInstance.name ?? "課程"
    }

    // 主要初始化器
    init(organizationId: String, organizationName: String) {
        self.organizationId = organizationId
        self.organizationName = organizationName
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("載入課表中...")
            } else if viewModel.schedules.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 週視圖標題
                        weekHeaderView

                        // 課表列表（按星期分組）
                        ForEach(1...7, id: \.self) { dayOfWeek in
                            daySection(for: dayOfWeek)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("課程時間表")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSchedules(organizationId: organizationId)
        }
        .sheet(isPresented: $showingScheduleDetail) {
            if let schedule = selectedSchedule {
                ScheduleDetailSheet(schedule: schedule, organizationName: organizationName)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("尚無課程時間表")
                .font(.title3)
                .fontWeight(.semibold)

            Text("課程管理員可以新增課程時間")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }

    // MARK: - Week Header

    private var weekHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text(organizationName)
                    .font(.headline)
            }

            Text("每週課程安排")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(12)
    }

    // MARK: - Day Section

    private func daySection(for dayOfWeek: Int) -> some View {
        let schedulesForDay = viewModel.schedules.filter { $0.dayOfWeek == dayOfWeek }

        guard !schedulesForDay.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                // 星期標題
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(dayColor(for: dayOfWeek))

                    Text(dayName(for: dayOfWeek))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("\(schedulesForDay.count) 節課")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // 課程列表
                ForEach(schedulesForDay.sorted(by: { $0.startTime < $1.startTime })) { schedule in
                    ScheduleCard(schedule: schedule)
                        .onTapGesture {
                            selectedSchedule = schedule
                            showingScheduleDetail = true
                        }
                }
            }
            .padding()
            .background(Color.appSecondaryBackground)
            .cornerRadius(12)
        )
    }

    // MARK: - Helpers

    private func dayName(for dayOfWeek: Int) -> String {
        let days = ["", "週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        return days[dayOfWeek]
    }

    private func dayColor(for dayOfWeek: Int) -> Color {
        switch dayOfWeek {
        case 1: return .red      // 週日
        case 2: return .blue     // 週一
        case 3: return .green    // 週二
        case 4: return .orange   // 週三
        case 5: return .purple   // 週四
        case 6: return .pink     // 週五
        case 7: return .indigo   // 週六
        default: return .gray
        }
    }
}

// MARK: - Schedule Card

struct ScheduleCard: View {
    let schedule: CourseSchedule

    var body: some View {
        HStack(spacing: 12) {
            // 時間標籤
            VStack(spacing: 4) {
                Text(schedule.startTime)
                    .font(.caption)
                    .fontWeight(.semibold)

                Rectangle()
                    .frame(width: 2, height: 16)
                    .foregroundColor(.gray)

                Text(schedule.endTime)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.blue)
            .frame(width: 50)

            // 課程資訊
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let location = schedule.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.orange)
                    }
                }

                if let instructor = schedule.instructor {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(instructor)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }

                if let weekRange = schedule.weekRange {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                        Text("第 \(weekRange) 週")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Schedule Detail Sheet

struct ScheduleDetailSheet: View {
    let schedule: CourseSchedule
    let organizationName: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 課程名稱
                    VStack(alignment: .leading, spacing: 8) {
                        Text("課程")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(organizationName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    Divider()

                    // 時間資訊
                    DetailRow(
                        icon: "clock.fill",
                        title: "上課時間",
                        value: "\(schedule.dayName) \(schedule.timeRange)"
                    )

                    // 地點資訊
                    if let location = schedule.location {
                        DetailRow(
                            icon: "mappin.circle.fill",
                            title: "上課地點",
                            value: location
                        )
                    }

                    // 教師資訊
                    if let instructor = schedule.instructor {
                        DetailRow(
                            icon: "person.fill",
                            title: "授課教師",
                            value: instructor
                        )
                    }

                    // 學期資訊
                    if let semester = schedule.semester {
                        DetailRow(
                            icon: "calendar",
                            title: "學期",
                            value: semester
                        )
                    }

                    // 週次資訊
                    if let weekRange = schedule.weekRange {
                        DetailRow(
                            icon: "calendar.badge.clock",
                            title: "週次",
                            value: "第 \(weekRange) 週"
                        )
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Color.appPrimaryBackground)
            .navigationTitle("課程詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.body)
            }

            Spacer()
        }
        .padding()
        .background(Color.appSecondaryBackground)
        .cornerRadius(8)
    }
}

// MARK: - ViewModel

@MainActor
class CourseScheduleViewModel: ObservableObject {
    @Published var schedules: [CourseSchedule] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let courseService = CourseService()

    func loadSchedules(organizationId: String) {
        isLoading = true

        Task {
            do {
                let fetchedSchedules = try await courseService.getCourseSchedules(organizationId: organizationId)
                self.schedules = fetchedSchedules
                self.errorMessage = nil
            } catch {
                self.errorMessage = "載入課表失敗：\(error.localizedDescription)"
                ToastManager.shared.showToast(message: self.errorMessage ?? "載入失敗", type: .error)
            }
            self.isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 17.0, *) {
        NavigationView {
            CourseScheduleView(
                organizationId: "preview-org",
                organizationName: "資料庫系統"
            )
        }
    }
}
