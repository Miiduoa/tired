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


/// 包裝 CalendarView 以便在 SwiftUI 中更好地使用
@available(iOS 17.0, *)
struct CalendarViewRepresentable: View {
    let interval: DateInterval
    let itemsByDate: [Date: [CalendarItem]]
    @Binding var selectedDate: Date?
    
    var body: some View {
        let calendar = Calendar.current
        let datesWithItems = Set(itemsByDate.keys.map { calendar.startOfDay(for: $0) })
        
        // 使用 DatePicker 作為日曆視圖
        DatePicker(
            "選擇日期",
            selection: Binding(
                get: { selectedDate ?? Date() },
                set: { selectedDate = $0 }
            ),
            in: interval.start...interval.end,
            displayedComponents: [.date]
        )
        .datePickerStyle(.graphical)
        .onChange(of: selectedDate) {
             // 這裡可以處理日期變更，但因為我們使用了 Binding，selectedDate 會自動更新
        }
        .onAppear {
            // Set initial selection if needed
        }
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
