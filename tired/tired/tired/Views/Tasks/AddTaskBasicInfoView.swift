import SwiftUI

@available(iOS 17.0, *)
struct AddTaskBasicInfoView: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var category: TaskCategory
    @Binding var priority: TaskPriority
    @Binding var hasDeadline: Bool
    @Binding var deadline: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("任務標題", text: $title)
                .font(.system(size: 20, weight: .semibold))
                .padding()
                .background(Color.appSecondaryBackground)
                .cornerRadius(AppDesignSystem.cornerRadiusMedium)
            
            HStack(spacing: 12) {
                Menu {
                    ForEach(TaskCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            Label(cat.displayName, systemImage: "circle.fill")
                                .foregroundColor(Color.forCategory(cat))
                        }
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(Color.forCategory(category))
                            .frame(width: 10, height: 10)
                        Text(category.displayName)
                            .font(AppDesignSystem.bodyFont)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(8)
                }
                .foregroundColor(.primary)
                
                Menu {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Button {
                            priority = p
                        } label: {
                            Text(p.displayName)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(priority == .high ? .red : (priority == .medium ? .orange : .green))
                        Text(priority.displayName)
                            .font(AppDesignSystem.bodyFont)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(8)
                }
                .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    withAnimation {
                        hasDeadline.toggle()
                        if hasDeadline {
                            if deadline < Date() {
                                deadline = Date().addingTimeInterval(86400)
                            }
                        }
                    }
                } label: {
                    Image(systemName: hasDeadline ? "calendar.badge.clock" : "calendar")
                        .foregroundColor(hasDeadline ? AppDesignSystem.accentColor : .secondary)
                        .padding(8)
                        .background(hasDeadline ? AppDesignSystem.accentColor.opacity(0.1) : Color.clear)
                        .clipShape(Circle())
                }
            }
            
            if hasDeadline {
                DatePicker("截止時間", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal, 4)
            }
            
            TextField("添加描述...", text: $description, axis: .vertical)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .padding()
                .background(Color.appSecondaryBackground.opacity(0.5))
                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }
}
