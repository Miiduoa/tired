import SwiftUI
import AVFoundation

enum QRScannerError: Error {
    case cameraUnavailable
    case permissionDenied
}

struct QRScannerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ScannerViewController

    let onComplete: (Result<String, QRScannerError>) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onFound = { code in
            onComplete(.success(code))
        }
        vc.onError = { err in
            onComplete(.failure(err))
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?
    var onError: ((QRScannerError) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitResult = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning { session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() }
                    else { self?.onError?(.permissionDenied) }
                }
            }
        default:
            onError?(.permissionDenied)
        }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?(.cameraUnavailable)
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(layer)
            previewLayer = layer

            session.startRunning()
        } catch {
            onError?(.cameraUnavailable)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didEmitResult else { return }
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               readable.type == .qr,
               let string = readable.stringValue,
               !string.isEmpty {
                didEmitResult = true
                session.stopRunning()
                onFound?(string)
                break
            }
        }
    }
}

