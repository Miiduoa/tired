import SwiftUI

// MARK: - My Tasks Stats View

@available(iOS 17.0, *)
struct MyTasksStatsView: View {
    @StateObject private var viewModel = TasksStatsViewModel()

    var body: some View {
        List {
            Section("本週統計") {
                HStack {
                    Text("已完成任務")
                    Spacer()
                    Text("\(viewModel.completedCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("待完成任務")
                    Spacer()
                    Text("\(viewModel.pendingCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("總預估時長")
                    Spacer()
                    Text(viewModel.formattedEstimatedTime)
                        .foregroundColor(.secondary)
                }
            }

            Section("分類統計") {
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("學校")
                    Spacer()
                    Text("\(viewModel.schoolCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("工作")
                    Spacer()
                    Text("\(viewModel.workCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                    Text("社團")
                    Spacer()
                    Text("\(viewModel.clubCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("生活")
                    Spacer()
                    Text("\(viewModel.personalCount)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("任務統計")
        .navigationBarTitleDisplayMode(.inline)
    }
}
