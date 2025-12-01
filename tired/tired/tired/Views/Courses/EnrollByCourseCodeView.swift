import SwiftUI

/// 使用選課代碼加入課程視圖
@available(iOS 17.0, *)
struct EnrollByCourseCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var courseCode = ""
    @State private var isEnrolling = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var enrolledCourse: Course?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                // 標題
                VStack(spacing: 8) {
                    Text("加入課程")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("請輸入教師提供的8位選課代碼")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // 輸入框
                TextField("選課代碼", text: $courseCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.title3, design: .monospaced))
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 按鈕
                Button(action: {
                    Task {
                        await enrollByCourseCode()
                    }
                }) {
                    if isEnrolling {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("加入課程")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(courseCode.count == 8 ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(courseCode.count != 8 || isEnrolling)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("加入課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("錯誤", isPresented: $showError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("加入成功", isPresented: $showSuccess) {
                Button("確定", role: .cancel) {
                    dismiss()
                }
            } message: {
                if let course = enrolledCourse {
                    Text("您已成功加入「\(course.name)」")
                }
            }
        }
    }
    
    private func enrollByCourseCode() async {
        guard let userId = authService.currentUserId else { return }
        
        isEnrolling = true
        
        do {
            let courseId = try await EnrollmentService.shared.enrollByCourseCode(
                courseCode.uppercased(),
                userId: userId
            )
            
            // 獲取課程資訊
            let course = try await CourseService.shared.fetchCourse(id: courseId)
            enrolledCourse = course
            
            isEnrolling = false
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isEnrolling = false
        }
    }
}

#Preview {
    EnrollByCourseCodeView()
        .environmentObject(AuthService.shared)
}
