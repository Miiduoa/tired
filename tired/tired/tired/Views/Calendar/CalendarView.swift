import SwiftUI

@available(iOS 17.0, *)
struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDate: Date? = Date()

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("正在讀取日曆資料...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    calendarAndItemList
                }
            }
            .navigationTitle("我的日曆")
            .onAppear {
                viewModel.fetchData()
            }
        }
    }

    @ViewBuilder
    private var calendarAndItemList: some View {
        VStack {
            // 使用 SwiftUI 的 CalendarView
            CalendarViewRepresentable(
                interval: DateInterval(start: .distantPast, end: .distantFuture),
                itemsByDate: viewModel.calendarItems,
                selectedDate: $selectedDate
            )
            .frame(height: 350) // 給日曆一個固定的高度

            Divider()

            // 顯示選定日期的項目
            if let date = selectedDate, let items = viewModel.calendarItems[Calendar.current.startOfDay(for: date)], !items.isEmpty {
                List(items) { item in
                    CalendarItemRow(item: item)
                }
                .listStyle(.plain)
            } else {
                Text(selectedDate == nil ? "請選擇一個日期" : "這天沒有活動或任務")
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}


/// 自定義日曆視圖（因為 SwiftUI 沒有內建的 CalendarView）
@available(iOS 17.0, *)
struct CalendarViewRepresentable: View {
    let interval: DateInterval
    let itemsByDate: [Date: [CalendarItem]]
    @Binding var selectedDate: Date?
    
    @State private var currentMonth: Date = Date()
    private let calendar = Calendar.current

    var body: some View {
        let datesWithItems = Set(itemsByDate.keys.map { calendar.startOfDay(for: $0) })
        
        VStack(spacing: 0) {
            // 月份標題和導航
            HStack {
                Button {
                    if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                        currentMonth = newMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                
                Spacer()
                
                Button {
                    if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                        currentMonth = newMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()
            
            // 星期標題
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // 日期網格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    let day = calendar.component(.day, from: date)
                    let isDateWithItem = datesWithItems.contains(calendar.startOfDay(for: date))
                    let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                    let isDateToday = calendar.isDateInToday(date)
                    let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                    
                    Button {
                        selectedDate = date
                    } label: {
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.blue)
                            } else if isDateWithItem {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                            }
                            
                            Text("\(day)")
                                .font(.system(size: 14, weight: isDateToday ? .bold : .regular))
                                .foregroundColor(
                                    isSelected ? .white :
                                    !isCurrentMonth ? .secondary :
                                    isDateToday ? .blue : .primary
                                )
                        }
                        .frame(width: 36, height: 36)
                    }
                    .disabled(!isCurrentMonth)
                }
            }
            .padding()
        }
    }
    
    private var daysInMonth: [Date] {
        guard let firstDay = calendar.dateInterval(of: .month, for: currentMonth)?.start else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysToSubtract = (firstWeekday - 1) % 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDay) else {
            return []
        }
        
        var dates: [Date] = []
        for i in 0..<42 { // 6 週
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                dates.append(date)
            }
        }
        return dates
    }
}

/// 日曆項目列表的單行視圖
struct CalendarItemRow: View {
    let item: CalendarItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .font(.headline)
                .foregroundColor(item.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(item.organizationName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(item.type.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.tintColor.opacity(0.1))
                .foregroundColor(item.tintColor)
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 17.0, *)
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
    }
}
