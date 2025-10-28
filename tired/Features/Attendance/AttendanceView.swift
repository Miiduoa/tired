
import SwiftUI
import CoreImage.CIFilterBuiltins

struct AttendanceView: View {
    @State private var seed: String = UUID().uuidString
    @State private var seconds: Int = 30
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("掃描此 QR 於 \(seconds) 秒內完成")
                .font(.headline)
            
            Image(uiImage: qrCode(from: seed))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .padding()
                .background(Color.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator), lineWidth: 0.5)
                }
            
            HStack(spacing: 12) {
                Label("GPS 正常", systemImage: "location")
                Label("BLE 開啟", systemImage: "dot.radiowaves.left.and.right")
                Label("裝置已驗證", systemImage: "iphone")
            }
            .font(.subheadline).foregroundStyle(.secondary)
            
            Button("重新產生 QR") {
                seed = UUID().uuidString
                seconds = 30
            }.gradientPrimary()
            
            Spacer()
        }
        .padding(16)
        .onReceive(timer) { _ in
            if seconds > 0 { seconds -= 1 }
            if seconds == 0 {
                // 自動換碼
                seed = UUID().uuidString
                seconds = 30
            }
        }
        .navigationTitle("10 秒點名")
        .background(Color.bg.ignoresSafeArea())
    }
    
    func qrCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        if let output = filter.outputImage?.transformed(by: transform),
           let cgimg = context.createCGImage(output, from: output.extent) {
            return UIImage(cgImage: cgimg)
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
