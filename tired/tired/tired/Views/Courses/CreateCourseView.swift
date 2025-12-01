import SwiftUI

/// 建立課程視圖
@available(iOS 17.0, *)
struct CreateCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var courseName = ""
    @State private var courseCode = ""
    @State private var semester = ""
    @State private var academicYear = ""
    @State private var description = ""
    @State private var credits: Int? = nil
    @State private var selectedLevel: CourseLevel = .undergraduate
    @State private var maxEnrollment: Int? = nil
    @State private var isPublic = false
    
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本資訊") {
                    TextField("課程名稱", text: $courseName)
                    TextField("課程代碼 (如 CS101)", text: $courseCode)
                    TextField("學期 (如 2024春季)", text: $semester)
                        .onAppear {
                            semester = CourseService.getCurrentSemester()
                        }
                    TextField("學年 (如 2024)", text: $academicYear)
                        .onAppear {
                            academicYear = CourseService.getCurrentAcademicYear()
                        }
                }
                
                Section("課程設定") {
                    Picker("課程級別", selection: $selectedLevel) {
                        ForEach(CourseLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    
                    HStack {
                        Text("學分數")
                        Spacer()
                        TextField("學分", value: $credits, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    HStack {
                        Text("人數上限")
                        Spacer()
                        TextField("人數", value: $maxEnrollment, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    Toggle("公開課程", isOn: $isPublic)
                }
                
                Section("課程描述") {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
            }
            .navigationTitle("建立課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task {
                            await createCourse()
                        }
                    }
                    .disabled(isCreating || !isFormValid)
                }
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    ProgressView("建立中...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .alert("錯誤", isPresented: $showError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !courseName.isEmpty && !courseCode.isEmpty && !semester.isEmpty && !academicYear.isEmpty
    }
    
    private func createCourse() async {
        guard let userId = authService.currentUserId else { return }
        
        isCreating = true
        
        let course = Course(
            name: courseName,
            code: courseCode,
            description: description.isEmpty ? nil : description,
            semester: semester,
            academicYear: academicYear,
            credits: credits,
            courseLevel: selectedLevel,
            maxEnrollment: maxEnrollment,
            isPublic: isPublic,
            createdByUserId: userId
        )
        
        do {
            _ = try await CourseService.shared.createCourse(course)
            isCreating = false
            dismiss()
        } catch {
            errorMessage = "建立課程失敗: \(error.localizedDescription)"
            showError = true
            isCreating = false
        }
    }
}

#Preview {
    CreateCourseView()
        .environmentObject(AuthService.shared)
}
