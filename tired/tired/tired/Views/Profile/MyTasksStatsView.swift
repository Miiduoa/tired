import SwiftUI

// MARK: - My Tasks Stats View

@available(iOS 17.0, *)
struct MyTasksStatsView: View {
    @StateObject private var viewModel = TasksStatsViewModel()

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.edgesIgnoringSafeArea(.all) // Overall background

            NavigationView {
                List {
                    Section {
                        HStack {
                            Text("已完成任務")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.completedCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("待完成任務")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.pendingCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("總預估時長")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(viewModel.formattedEstimatedTime)
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("本週統計")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))


                    Section {
                        HStack {
                            Circle()
                                .fill(Color.forCategory(.school))
                                .frame(width: 8, height: 8)
                            Text("學校")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.schoolCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Circle()
                                .fill(Color.forCategory(.work))
                                .frame(width: 8, height: 8)
                            Text("工作")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.workCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Circle()
                                .fill(Color.forCategory(.club))
                                .frame(width: 8, height: 8)
                            Text("社團")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.clubCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Circle()
                                .fill(Color.forCategory(.personal))
                                .frame(width: 8, height: 8)
                            Text("生活")
                                .font(AppDesignSystem.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.personalCount)")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("分類統計")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.paddingSmall, leading: 0, bottom: AppDesignSystem.paddingLarge, trailing: 0))
                }
                .listStyle(.insetGrouped)
                .navigationTitle("任務統計")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.clear) // Make NavigationView's background clear
            }
        }
    }
}