import SwiftUI

@available(iOS 17.0, *)
struct SortOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sortOption: TaskSortOption

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)

                List {
                    ForEach(TaskSortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(AppDesignSystem.accentColor)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .font(AppDesignSystem.bodyFont)
                                    .foregroundColor(.primary)
                                Spacer()
                                if sortOption == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppDesignSystem.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("排序方式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
