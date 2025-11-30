import SwiftUI

struct RecurrencePicker: View {
    @Binding var rule: RecurrenceRule?
    @Binding var endDate: Date?
    /// 用來決定週期的基準日期（優先使用排程日/截止日，而非今日）
    var anchorDate: Date
    
    @State private var selectedType: RecurrenceType = .none
    @State private var customDays: Set<Int> = []
    @State private var hasEndDate: Bool = false
    
    enum RecurrenceType: String, CaseIterable, Identifiable {
        case none = "不重複"
        case daily = "每天"
        case weekdays = "工作日 (週一至週五)"
        case weekends = "週末 (週六、週日)"
        case weekly = "每週"
        case biweekly = "每兩週"
        case monthly = "每月"
        case custom = "自定義"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("重複規則", selection: $selectedType) {
                ForEach(RecurrenceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedType) { updateRule() }
            .onChange(of: anchorDate) {
                // 當基準日期更新時（例如調整排程日），同步更新規則
                updateRule()
            }
            
            if selectedType == .custom {
                // Weekday selector
                HStack {
                    ForEach(1...7, id: \.self) { day in
                        let isSelected = customDays.contains(day)
                        Text(dayName(day))
                            .font(.caption2)
                            .fontWeight(isSelected ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? AppDesignSystem.accentColor : Color.appSecondaryBackground)
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onTapGesture {
                                if isSelected {
                                    customDays.remove(day)
                                } else {
                                    customDays.insert(day)
                                }
                                updateRule()
                            }
                    }
                }
                
                if customDays.isEmpty {
                    Text("請選擇至少一個重複日。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if selectedType != .none {
                Toggle("設定結束日期", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { oldValue, newValue in
                        if !newValue { endDate = nil }
                    }
                
                if hasEndDate {
                    DatePicker("結束日期", selection: Binding(get: { endDate ?? Date() }, set: { endDate = $0 }), displayedComponents: .date)
                }
            }
        }
        .onAppear {
            initializeFromRule()
        }
    }
    
    private func dayName(_ day: Int) -> String {
        // 1 = 週一 ... 7 = 週日
        let days = ["一", "二", "三", "四", "五", "六", "日"]
        return days[(day - 1) % 7]
    }
    
    private func initializeFromRule() {
        guard let rule = rule else {
            selectedType = .none
            return
        }
        
        hasEndDate = endDate != nil
        
        switch rule {
        case .daily: selectedType = .daily
        case .weekdays: selectedType = .weekdays
        case .weekends:
            selectedType = .weekends
            customDays = [6, 7]
        case .weekly: selectedType = .weekly
        case .biweekly: selectedType = .biweekly
        case .monthly: selectedType = .monthly
        case .custom(let days):
            selectedType = .custom
            customDays = Set(days)
        }
    }
    
    private func updateRule() {
        let calendar = Calendar.current
        let weekday = isoWeekday(from: anchorDate) // 1=Mon
        let dayOfMonth = calendar.component(.day, from: anchorDate)
        
        switch selectedType {
        case .none:
            rule = nil
        case .daily:
            rule = .daily
        case .weekdays:
            rule = .weekdays
        case .weekends:
            rule = .weekends
        case .weekly:
            rule = .weekly(dayOfWeek: weekday)
        case .biweekly:
            rule = .biweekly(dayOfWeek: weekday)
        case .monthly:
            rule = .monthly(dayOfMonth: dayOfMonth)
        case .custom:
            let normalized = customDays.sorted()
            rule = normalized.isEmpty ? nil : .custom(daysOfWeek: normalized)
        }
    }
    
    private func isoWeekday(from date: Date) -> Int {
        // 將 Calendar 的 weekday (週日=1) 轉為 ISO (週一=1)
        let weekday = Calendar.current.component(.weekday, from: date)
        return ((weekday + 5) % 7) + 1
    }
}
