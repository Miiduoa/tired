import SwiftUI

@available(iOS 17.0, *)
struct CategoryFilterBar: View {
    @Binding var selectedCategory: TaskCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppDesignSystem.paddingSmall) {
                CategoryChip(
                    title: "全部",
                    color: .gray,
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(TaskCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        color: Color.forCategory(category),
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
        }
    }
}
