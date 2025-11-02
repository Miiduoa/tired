import SwiftUI
import PhotosUI

// MARK: - Image Editor View

struct ImageEditorView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var editedImage: UIImage?
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var showFilters = false
    @State private var selectedFilter: FilterType = .none
    
    enum FilterType: String, CaseIterable {
        case none = "原圖"
        case sepia = "懷舊"
        case noir = "黑白"
        case vibrant = "鮮豔"
        case cool = "冷色"
        case warm = "暖色"
        
        var ciFilterName: String? {
            switch self {
            case .none: return nil
            case .sepia: return "CISepiaTone"
            case .noir: return "CIPhotoEffectNoir"
            case .vibrant: return "CIColorControls"
            case .cool: return "CITemperatureAndTint"
            case .warm: return "CITemperatureAndTint"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 預覽區域
                    imagePreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 控制區域
                    controlPanel
                        .padding(.vertical, TTokens.spacingMD)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("編輯照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveImage()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            editedImage = image
        }
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        GeometryReader { geometry in
            if let displayImage = processedImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value.magnitude
                            }
                    )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(spacing: TTokens.spacingMD) {
            // 濾鏡選擇器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TTokens.spacingSM) {
                    ForEach(FilterType.allCases, id: \.self) { filter in
                        filterButton(filter)
                    }
                }
                .padding(.horizontal, TTokens.spacingLG)
            }
            
            // 調整滑桿
            VStack(spacing: TTokens.spacingMD) {
                adjustmentSlider(
                    title: "亮度",
                    value: $brightness,
                    range: -0.5...0.5,
                    icon: "sun.max.fill"
                )
                
                adjustmentSlider(
                    title: "對比度",
                    value: $contrast,
                    range: 0.5...1.5,
                    icon: "circle.lefthalf.filled"
                )
                
                adjustmentSlider(
                    title: "飽和度",
                    value: $saturation,
                    range: 0...2,
                    icon: "paintpalette.fill"
                )
                
                adjustmentSlider(
                    title: "旋轉",
                    value: $rotation,
                    range: -180...180,
                    icon: "rotate.right.fill"
                )
            }
            .padding(.horizontal, TTokens.spacingLG)
            
            // 重置按鈕
            Button {
                resetAdjustments()
                HapticFeedback.light()
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.warn)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: TTokens.radiusMD)
                            .fill(Color.warn.opacity(0.1))
                    }
            }
            .padding(.horizontal, TTokens.spacingLG)
        }
    }
    
    // MARK: - Filter Button
    
    private func filterButton(_ filter: FilterType) -> some View {
        Button {
            selectedFilter = filter
            HapticFeedback.selection()
        } label: {
            VStack(spacing: TTokens.spacingXS) {
                // 預覽縮圖
                if let thumbnail = generateThumbnail(with: filter) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: TTokens.radiusSM))
                        .overlay {
                            RoundedRectangle(cornerRadius: TTokens.radiusSM)
                                .strokeBorder(
                                    selectedFilter == filter ? Color.tint : Color.clear,
                                    lineWidth: 2
                                )
                        }
                } else {
                    RoundedRectangle(cornerRadius: TTokens.radiusSM)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
                
                Text(filter.rawValue)
                    .font(.caption2)
                    .foregroundStyle(selectedFilter == filter ? .primary : .secondary)
            }
        }
    }
    
    // MARK: - Adjustment Slider
    
    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: TTokens.spacingXS) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: value, in: range)
                .tint(Color.tint)
                .onChange(of: value.wrappedValue) { _, _ in
                    HapticFeedback.light()
                }
        }
    }
    
    // MARK: - Image Processing
    
    private var processedImage: UIImage? {
        guard let baseImage = editedImage else { return nil }
        
        var processedImage = baseImage
        
        // 應用濾鏡
        if selectedFilter != .none, let filtered = applyFilter(to: processedImage, filter: selectedFilter) {
            processedImage = filtered
        }
        
        // 應用調整
        processedImage = applyAdjustments(to: processedImage)
        
        return processedImage
    }
    
    private func applyFilter(to image: UIImage, filter: FilterType) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filterName = filter.ciFilterName else { return image }
        
        let context = CIContext()
        var outputImage: CIImage?
        
        switch filter {
        case .sepia:
            if let filter = CIFilter(name: filterName) {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(0.8, forKey: kCIInputIntensityKey)
                outputImage = filter.outputImage
            }
        case .noir:
            if let filter = CIFilter(name: filterName) {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                outputImage = filter.outputImage
            }
        case .vibrant:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(1.5, forKey: kCIInputSaturationKey)
                outputImage = filter.outputImage
            }
        case .cool:
            if let filter = CIFilter(name: filterName) {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 5000, y: 0), forKey: "inputNeutral")
                outputImage = filter.outputImage
            }
        case .warm:
            if let filter = CIFilter(name: filterName) {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                outputImage = filter.outputImage
            }
        default:
            return image
        }
        
        guard let output = outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func applyAdjustments(to image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        var outputImage = ciImage
        
        // 應用色彩調整
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(outputImage, forKey: kCIInputImageKey)
            colorFilter.setValue(brightness, forKey: kCIInputBrightnessKey)
            colorFilter.setValue(contrast, forKey: kCIInputContrastKey)
            colorFilter.setValue(saturation, forKey: kCIInputSaturationKey)
            if let output = colorFilter.outputImage {
                outputImage = output
            }
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func generateThumbnail(with filter: FilterType) -> UIImage? {
        guard let baseImage = editedImage else { return nil }
        
        // 創建縮圖
        let thumbnailSize = CGSize(width: 60, height: 60)
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0)
        baseImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let thumbnail = thumbnail else { return nil }
        
        if filter == .none {
            return thumbnail
        }
        
        return applyFilter(to: thumbnail, filter: filter)
    }
    
    // MARK: - Actions
    
    private func resetAdjustments() {
        withAnimation(.spring(response: 0.3)) {
            brightness = 0
            contrast = 1
            saturation = 1
            rotation = 0
            scale = 1.0
            selectedFilter = .none
        }
    }
    
    private func saveImage() {
        if let processed = processedImage {
            image = processed
            HapticFeedback.success()
            ToastCenter.shared.show("照片已保存", style: .success)
        }
        dismiss()
    }
}

// MARK: - Photo Picker with Editor

struct PhotoPickerWithEditor: View {
    @Binding var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showEditor = false
    @State private var tempImage: UIImage?
    
    var body: some View {
        Button {
            showPhotoPicker = true
            HapticFeedback.light()
        } label: {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: TTokens.radiusMD))
                    .overlay {
                        RoundedRectangle(cornerRadius: TTokens.radiusMD)
                            .strokeBorder(Color.tint, lineWidth: 2)
                    }
            } else {
                RoundedRectangle(cornerRadius: TTokens.radiusMD)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay {
                        VStack(spacing: TTokens.spacingXS) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                            Text("選擇照片")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.tint)
                    }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePicker(image: $tempImage, sourceType: .photoLibrary)
                .onDisappear {
                    if tempImage != nil {
                        showEditor = true
                    }
                }
        }
        .sheet(isPresented: $showEditor) {
            if tempImage != nil {
                ImageEditorView(image: $tempImage)
                    .onDisappear {
                        if let edited = tempImage {
                            selectedImage = edited
                        }
                        tempImage = nil
                    }
            }
        }
    }
}

// MARK: - Legacy UIKit Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

