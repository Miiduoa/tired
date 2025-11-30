import SwiftUI

// MARK: - My Tasks Stats View

@available(iOS 17.0, *)
struct MyTasksStatsView: View {
    @StateObject private var viewModel = TasksStatsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var animateCharts = false

    enum TimeRange: String, CaseIterable {
        case week = "本週"
        case month = "本月"
        case all = "全部"
    }

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: AppDesignSystem.paddingLarge) {
                    // 時間範圍選擇器
                    Picker("時間範圍", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedTimeRange) {
                        viewModel.updateTimeRange(selectedTimeRange.rawValue)
                        withAnimation(.spring()) {
                            animateCharts = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                animateCharts = true
                            }
                        }
                    }
                    
                    // 主要統計卡片
                    HStack(spacing: 12) {
                        StatisticCard(
                            title: "已完成",
                            value: "\(viewModel.completedCount)",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            animationProgress: animateCharts ? 1.0 : 0.0
                        )
                        
                        StatisticCard(
                            title: "進行中",
                            value: "\(viewModel.pendingCount)",
                            icon: "clock.fill",
                            color: .orange,
                            animationProgress: animateCharts ? 1.0 : 0.0
                        )
                        
                        StatisticCard(
                            title: "完成率",
                            value: "\(viewModel.completionRate)%",
                            icon: "chart.pie.fill",
                            color: AppDesignSystem.accentColor,
                            animationProgress: animateCharts ? 1.0 : 0.0
                        )
                    }
                    .padding(.horizontal)
                    
                    // 完成率圓環圖
                    CompletionRingChart(
                        completionRate: Double(viewModel.completionRate) / 100.0,
                        completed: viewModel.completedCount,
                        total: viewModel.completedCount + viewModel.pendingCount,
                        animate: animateCharts
                    )
                    .padding(.horizontal)
                    
                    // 分類統計條形圖
                    CategoryBarChart(
                        data: viewModel.categoryData,
                        animate: animateCharts
                    )
                    .padding(.horizontal)
                    
                    // 本週日曆熱力圖
                    WeekHeatmapView(
                        dailyStats: viewModel.weeklyStats,
                        animate: animateCharts
                    )
                    .padding(.horizontal)
                    
                    // 時間統計
                    VStack(alignment: .leading, spacing: 12) {
                        Text("時間投入")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            TimeStatItem(
                                title: "預估總時長",
                                value: viewModel.formattedEstimatedTime,
                                icon: "clock",
                                color: .blue
                            )
                            
                            TimeStatItem(
                                title: "實際花費",
                                value: viewModel.formattedActualTime,
                                icon: "stopwatch",
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .glassmorphicCard()
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationTitle("任務統計")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateCharts = true
                }
            }
        }
    }
}

// MARK: - 統計卡片
@available(iOS 17.0, *)
struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animationProgress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .scaleEffect(animationProgress)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassmorphicCard(cornerRadius: 16)
        .opacity(animationProgress)
    }
}

// MARK: - 完成率圓環圖
@available(iOS 17.0, *)
struct CompletionRingChart: View {
    let completionRate: Double
    let completed: Int
    let total: Int
    let animate: Bool
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完成率")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 24) {
                // 圓環圖
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            LinearGradient(
                                colors: [AppDesignSystem.accentColor, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(animatedProgress * 100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        Text("完成")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 詳細信息
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppDesignSystem.accentColor)
                            .frame(width: 12, height: 12)
                        Text("已完成: \(completed)")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text("未完成: \(total - completed)")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "sum")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("總計: \(total)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .glassmorphicCard()
        .onChange(of: animate) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedProgress = completionRate
                }
            } else {
                animatedProgress = 0
            }
        }
    }
}

// MARK: - 分類條形圖
@available(iOS 17.0, *)
struct CategoryBarChart: View {
    let data: [(category: TaskCategory, count: Int)]
    let animate: Bool
    
    private var maxCount: Int {
        data.map { $0.count }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分類分佈")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ForEach(data, id: \.category) { item in
                    HStack(spacing: 12) {
                        // 分類標籤
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.forCategory(item.category))
                                .frame(width: 10, height: 10)
                            Text(item.category.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 70, alignment: .leading)
                        
                        // 進度條
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(Color.forCategory(item.category))
                                    .frame(
                                        width: animate ?
                                            geometry.size.width * CGFloat(item.count) / CGFloat(max(maxCount, 1)) : 0,
                                        height: 8
                                    )
                                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)
                            }
                        }
                        .frame(height: 8)
                        
                        // 數量
                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .glassmorphicCard()
    }
}

// MARK: - 週熱力圖
@available(iOS 17.0, *)
struct WeekHeatmapView: View {
    let dailyStats: [(day: String, count: Int)]
    let animate: Bool
    
    private var maxCount: Int {
        dailyStats.map { $0.count }.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本週活動")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                ForEach(dailyStats.indices, id: \.self) { index in
                    let stat = dailyStats[index]
                    VStack(spacing: 6) {
                        // 活動強度方塊
                        RoundedRectangle(cornerRadius: 8)
                            .fill(intensityColor(for: stat.count))
                            .frame(width: 40, height: 40)
                            .scaleEffect(animate ? 1.0 : 0.5)
                            .opacity(animate ? 1.0 : 0.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: animate)
                            .overlay(
                                Text("\(stat.count)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(stat.count > 0 ? .white : .secondary)
                            )
                        
                        // 星期標籤
                        Text(stat.day)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // 圖例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 12, height: 12)
                    Text("無")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppDesignSystem.accentColor.opacity(0.4))
                        .frame(width: 12, height: 12)
                    Text("少")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppDesignSystem.accentColor.opacity(0.7))
                        .frame(width: 12, height: 12)
                    Text("中")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppDesignSystem.accentColor)
                        .frame(width: 12, height: 12)
                    Text("多")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glassmorphicCard()
    }
    
    private func intensityColor(for count: Int) -> Color {
        guard maxCount > 0 else { return Color.gray.opacity(0.2) }
        let ratio = Double(count) / Double(maxCount)
        
        if count == 0 {
            return Color.gray.opacity(0.2)
        } else if ratio < 0.33 {
            return AppDesignSystem.accentColor.opacity(0.4)
        } else if ratio < 0.66 {
            return AppDesignSystem.accentColor.opacity(0.7)
        } else {
            return AppDesignSystem.accentColor
        }
    }
}

// MARK: - 時間統計項
@available(iOS 17.0, *)
struct TimeStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}