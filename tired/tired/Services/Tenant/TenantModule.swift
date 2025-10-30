import SwiftUI

struct TenantModuleMetadata {
    let title: String
    let systemImage: String
    let accentColor: Color
}

struct TenantModuleEntryAction: Identifiable {
    let id = UUID()
    let module: AppModule
    let title: String
    let icon: String
    let color: Color
    let badge: String?
    let action: () -> Void
}
