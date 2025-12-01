import SwiftUI

@available(iOS 17.0, *)
struct AssignmentBoardView: View {
    let appInstance: OrgAppInstance
    let organizationId: String
    
    // In a real app, this would use a specialized ViewModel
    // For now, we can reuse TaskBoard logic or show a specialized interface
    
    var body: some View {
        TaskBoardView(appInstance: appInstance, organizationId: organizationId)
            .navigationTitle("作業專區")
    }
}

@available(iOS 17.0, *)
struct BulletinBoardView: View {
    let appInstance: OrgAppInstance
    
    var body: some View {
        VStack {
            Image(systemName: "megaphone")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text("公告欄")
                .font(.title)
            Text("發布重要通知與公告")
                .foregroundColor(.secondary)
        }
        .navigationTitle(appInstance.name ?? "公告欄")
    }
}

@available(iOS 17.0, *)
struct RollCallView: View {
    let appInstance: OrgAppInstance
    
    var body: some View {
        VStack {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("點名系統")
                .font(.title)
            Text("QR Code 簽到 / 點名")
                .foregroundColor(.secondary)
        }
        .navigationTitle(appInstance.name ?? "點名系統")
    }
}

@available(iOS 17.0, *)
struct GradebookView: View {
    let appInstance: OrgAppInstance
    
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            Text("成績查詢")
                .font(.title)
            Text("查看學期成績與評量")
                .foregroundColor(.secondary)
        }
        .navigationTitle(appInstance.name ?? "成績查詢")
    }
}



