import SwiftUI
import PhotosUI

@available(iOS 17.0, *)
struct EditOrganizationView: View {
    @ObservedObject var viewModel: OrganizationDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var type: OrgType
    @State private var isSaving = false

    @State private var selectedAvatarImage: UIImage?
    @State private var selectedCoverImage: UIImage?
    @State private var showingAvatarPicker = false
    @State private var showingCoverPicker = false
    @State private var isUploadingImage = false

    // Moodle-like 課程資訊編輯（P2-2）
    @State private var courseCode: String
    @State private var semester: String
    @State private var credits: String
    @State private var syllabus: String
    @State private var academicYear: String
    @State private var courseLevel: String
    @State private var maxEnrollment: String

    private let storageService = StorageService()

    init(viewModel: OrganizationDetailViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.organization?.name ?? "")
        _description = State(initialValue: viewModel.organization?.description ?? "")
        _type = State(initialValue: viewModel.organization?.type ?? .other)

        // 初始化課程資訊
        _courseCode = State(initialValue: viewModel.organization?.courseCode ?? "")
        _semester = State(initialValue: viewModel.organization?.semester ?? "")
        _credits = State(initialValue: viewModel.organization?.credits != nil ? "\(viewModel.organization!.credits!)" : "")
        _syllabus = State(initialValue: viewModel.organization?.syllabus ?? "")
        _academicYear = State(initialValue: viewModel.organization?.academicYear ?? "")
        _courseLevel = State(initialValue: viewModel.organization?.courseLevel ?? "")
        _maxEnrollment = State(initialValue: viewModel.organization?.maxEnrollment != nil ? "\(viewModel.organization!.maxEnrollment!)" : "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                Form {
                    // 頭像和封面圖片
                    Section {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            // 頭像
                            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                                Text("組織頭像")
                                    .font(AppDesignSystem.bodyFont.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: AppDesignSystem.paddingMedium) {
                                    if let selectedAvatar = selectedAvatarImage {
                                        Image(uiImage: selectedAvatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium))
                                    } else if let avatarUrl = viewModel.organization?.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                                                .fill(Color.secondary.opacity(0.2))
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium))
                                    } else {
                                        RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    
                                    Button {
                                        showingAvatarPicker = true
                                    } label: {
                                        Text(selectedAvatarImage != nil || viewModel.organization?.avatarUrl != nil ? "更換頭像" : "選擇頭像")
                                            .font(AppDesignSystem.bodyFont)
                                            .foregroundColor(AppDesignSystem.accentColor)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            Divider()
                            
                            // 封面
                            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                                Text("封面圖片")
                                    .font(AppDesignSystem.bodyFont.weight(.medium))
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: AppDesignSystem.paddingMedium) {
                                    if let selectedCover = selectedCoverImage {
                                        Image(uiImage: selectedCover)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall))
                                    } else if let coverUrl = viewModel.organization?.coverUrl, let url = URL(string: coverUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                                                .fill(Color.secondary.opacity(0.2))
                                        }
                                        .frame(width: 120, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall))
                                    } else {
                                        RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                                            .fill(Color.secondary.opacity(0.2))
                                            .frame(width: 120, height: 60)
                                            .overlay(
                                                Image(systemName: "photo.fill")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    
                                    Button {
                                        showingCoverPicker = true
                                    } label: {
                                        Text(selectedCoverImage != nil || viewModel.organization?.coverUrl != nil ? "更換封面" : "選擇封面")
                                            .font(AppDesignSystem.bodyFont)
                                            .foregroundColor(AppDesignSystem.accentColor)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, AppDesignSystem.paddingSmall)
                    } header: {
                        Text("圖片")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)
                    
                    Section {
                        TextField("組織名稱", text: $name)
                            .textFieldStyle(StandardTextFieldStyle(icon: "building.2"))
                        
                        Picker("類型", selection: $type) {
                            ForEach(OrgType.allCases, id: \.self) { orgType in
                                HStack {
                                    Image(systemName: iconForOrgType(orgType))
                                    Text(orgType.displayName)
                                }
                                .tag(orgType)
                            }
                        }
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("基本信息")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)
                    
                    Section {
                        TextEditor(text: $description)
                            .font(AppDesignSystem.bodyFont)
                            .padding(AppDesignSystem.paddingSmall)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                            .frame(height: 100)
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("描述")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    }
                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                    .listRowBackground(Color.clear)

                    // Moodle-like 課程資訊編輯（P2-2）
                    if type == .school || type == .department {
                        Section {
                            VStack(spacing: AppDesignSystem.paddingSmall) {
                                TextField("課程代碼", text: $courseCode)
                                    .textFieldStyle(StandardTextFieldStyle(icon: "number"))

                                TextField("學年", text: $academicYear, prompt: Text("例如：2024"))
                                    .textFieldStyle(StandardTextFieldStyle(icon: "calendar"))

                                TextField("學期", text: $semester, prompt: Text("例如：2024-1"))
                                    .textFieldStyle(StandardTextFieldStyle(icon: "calendar.badge.clock"))

                                HStack(spacing: AppDesignSystem.paddingMedium) {
                                    TextField("學分數", text: $credits, prompt: Text("例如：3"))
                                        .textFieldStyle(StandardTextFieldStyle(icon: "star"))
                                        .keyboardType(.numberPad)

                                    TextField("最大選課人數", text: $maxEnrollment, prompt: Text("例如：50"))
                                        .textFieldStyle(StandardTextFieldStyle(icon: "person.3"))
                                        .keyboardType(.numberPad)
                                }

                                Menu {
                                    Button("大學部") { courseLevel = "大學部" }
                                    Button("研究所") { courseLevel = "研究所" }
                                    Button("博士班") { courseLevel = "博士班" }
                                    Button("通識課程") { courseLevel = "通識課程" }
                                    Button("其他") { courseLevel = "其他" }
                                } label: {
                                    HStack {
                                        Image(systemName: "graduationcap")
                                            .foregroundColor(.secondary)
                                        Text(courseLevel.isEmpty ? "課程級別" : courseLevel)
                                            .foregroundColor(courseLevel.isEmpty ? .secondary : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(AppDesignSystem.paddingSmall)
                                    .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                                }
                            }
                        } header: {
                            Text("課程基本資訊")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        } footer: {
                            Text("這些資訊幫助學生了解課程詳情")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                        .listRowBackground(Color.clear)

                        Section {
                            TextEditor(text: $syllabus)
                                .font(AppDesignSystem.bodyFont)
                                .padding(AppDesignSystem.paddingSmall)
                                .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall, material: .regularMaterial)
                                .frame(height: 150)
                                .listRowBackground(Color.clear)
                        } header: {
                            Text("課程大綱")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        } footer: {
                            Text("支援 Markdown 格式")
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                        }
                        .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium, material: .regularMaterial)
                        .listRowBackground(Color.clear)
                    }
                }
                .background(Color.clear)
            }
            .navigationTitle("編輯組織")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .buttonStyle(GlassmorphicButtonStyle(material: .regularMaterial, cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .red))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saveOrganization()
                    }
                    .buttonStyle(GlassmorphicButtonStyle(cornerRadius: AppDesignSystem.cornerRadiusSmall, textColor: .white))
                    .disabled(name.isEmpty || isSaving || isUploadingImage)
                }
            }
            .sheet(isPresented: $showingAvatarPicker) {
                ImagePicker(images: Binding(
                    get: { selectedAvatarImage.map { [$0] } ?? [] },
                    set: { selectedAvatarImage = $0.first }
                ), maxSelection: 1)
            }
            .sheet(isPresented: $showingCoverPicker) {
                ImagePicker(images: Binding(
                    get: { selectedCoverImage.map { [$0] } ?? [] },
                    set: { selectedCoverImage = $0.first }
                ), maxSelection: 1)
            }
        }
    }
    
    private func saveOrganization() {
        guard !name.isEmpty else {
            ToastManager.shared.showToast(message: "組織名稱不能為空", type: .warning)
            return
        }
        
        guard let orgId = viewModel.organization?.id else {
            ToastManager.shared.showToast(message: "組織ID不存在", type: .error)
            return
        }
        
        isSaving = true
        isUploadingImage = true
        
        _Concurrency.Task {
            var avatarUrl: String? = viewModel.organization?.avatarUrl
            var coverUrl: String? = viewModel.organization?.coverUrl
            
            // 上傳頭像
            if let avatarImage = selectedAvatarImage {
                do {
                    let resizedImage = storageService.resizeImage(avatarImage, maxDimension: 400)
                    guard let imageData = storageService.compressImage(resizedImage, maxSizeKB: 300) else {
                        await MainActor.run {
                            isSaving = false
                            isUploadingImage = false
                            ToastManager.shared.showToast(message: "圖片壓縮失敗", type: .error)
                        }
                        return
                    }
                    
                    avatarUrl = try await storageService.uploadOrganizationAvatar(organizationId: orgId, imageData: imageData)
                } catch {
                    await MainActor.run {
                        isSaving = false
                        isUploadingImage = false
                        ToastManager.shared.showToast(message: "頭像上傳失敗：\(error.localizedDescription)", type: .error)
                    }
                    return
                }
            }
            
            // 上傳封面
            if let coverImage = selectedCoverImage {
                do {
                    let resizedImage = storageService.resizeImage(coverImage, maxDimension: 1200)
                    guard let imageData = storageService.compressImage(resizedImage, maxSizeKB: 500) else {
                        await MainActor.run {
                            isSaving = false
                            isUploadingImage = false
                            ToastManager.shared.showToast(message: "圖片壓縮失敗", type: .error)
                        }
                        return
                    }
                    
                    coverUrl = try await storageService.uploadOrganizationCover(organizationId: orgId, imageData: imageData)
                } catch {
                    await MainActor.run {
                        isSaving = false
                        isUploadingImage = false
                        ToastManager.shared.showToast(message: "封面上傳失敗：\(error.localizedDescription)", type: .error)
                    }
                    return
                }
            }
            
            isUploadingImage = false
            
            // 更新組織信息（包含圖片URL和課程資訊）
            var updatedOrg = viewModel.organization!
            updatedOrg.name = name
            updatedOrg.description = description.isEmpty ? nil : description
            updatedOrg.type = type
            updatedOrg.avatarUrl = avatarUrl
            updatedOrg.coverUrl = coverUrl

            // Moodle-like 課程資訊更新（P2-2）
            if type == .school || type == .department {
                updatedOrg.courseCode = courseCode.isEmpty ? nil : courseCode
                updatedOrg.semester = semester.isEmpty ? nil : semester
                updatedOrg.credits = Int(credits)
                updatedOrg.syllabus = syllabus.isEmpty ? nil : syllabus
                updatedOrg.academicYear = academicYear.isEmpty ? nil : academicYear
                updatedOrg.courseLevel = courseLevel.isEmpty ? nil : courseLevel
                updatedOrg.maxEnrollment = Int(maxEnrollment)
            }

            updatedOrg.updatedAt = Date()
            
            do {
                try await OrganizationService().updateOrganization(updatedOrg)
                await MainActor.run {
                    viewModel.organization = updatedOrg
                    isSaving = false
                    ToastManager.shared.showToast(message: "組織信息已更新", type: .success)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    ToastManager.shared.showToast(message: "更新失敗：\(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    private func iconForOrgType(_ type: OrgType) -> String {
        switch type {
        case .school: return "building.columns"
        case .department: return "building.2"
        case .club: return "music.note.house"
        case .company: return "briefcase"
        case .project: return "folder"
        case .other: return "square.grid.2x2"
        }
    }
}


