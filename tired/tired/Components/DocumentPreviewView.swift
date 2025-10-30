import SwiftUI
import QuickLook

struct DocumentPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let ctrl = QLPreviewController()
        ctrl.dataSource = context.coordinator
        return ctrl
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: QLPreviewItem
        init(url: URL) {
            self.item = url as NSURL
        }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { item }
    }
}

