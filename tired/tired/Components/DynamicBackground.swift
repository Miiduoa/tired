import SwiftUI

enum DynamicBackgroundStyle {
    case glassmorphism
    case blobs
}

struct DynamicBackground: View {
    let style: DynamicBackgroundStyle
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        switch style {
        case .glassmorphism:
            ZStack {
                // Dark/Light adaptive background
                let gradientColors: [Color] = {
                    if scheme == .dark {
                        return [
                            Color(red: 0.08, green: 0.10, blue: 0.14),
                            Color(red: 0.05, green: 0.07, blue: 0.11)
                        ]
                    } else {
                        return [
                            Color(red: 0.96, green: 0.98, blue: 1.0),
                            Color(red: 0.92, green: 0.96, blue: 1.0)
                        ]
                    }
                }()
                let background = LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                background
                Circle()
                    .fill((scheme == .dark ? Color.indigo : Color.blue).opacity(scheme == .dark ? 0.10 : 0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -120, y: -220)
                Circle()
                    .fill((scheme == .dark ? Color.teal : Color.mint).opacity(scheme == .dark ? 0.10 : 0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 70)
                    .offset(x: 140, y: -180)
                RoundedRectangle(cornerRadius: 40)
                    .fill(Color.purple.opacity(scheme == .dark ? 0.08 : 0.10))
                    .frame(width: 360, height: 360)
                    .rotationEffect(.degrees(35))
                    .blur(radius: 80)
                    .offset(x: 120, y: 260)
            }
            .ignoresSafeArea()
        case .blobs:
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    // Adaptive blobs
                    let base: Double = (scheme == .dark ? 0.14 : 0.20)
                    let c1: Color = Color(UIColor.systemTeal).opacity(base)
                    let c2: Color = Color(UIColor.systemIndigo).opacity(base - 0.02)
                    let c3: Color = Color(UIColor.systemPink).opacity(base - 0.04)
                    
                    // Convert trig (Double) to CGFloat explicitly
                    let width = size.width
                    let height = size.height
                    
                    let x1 = CGFloat(cos(t / 3.0) * 80.0)
                    let y1 = CGFloat(sin(t / 4.0) * 60.0)
                    let rect1 = CGRect(x: x1, y: y1, width: 260, height: 260)
                    
                    let x2 = CGFloat((Double(width) - 280.0) + sin(t / 2.0) * 40.0)
                    let y2 = CGFloat(120.0 + cos(t / 3.0) * 50.0)
                    let rect2 = CGRect(x: x2, y: y2, width: 280, height: 280)
                    
                    let x3 = CGFloat((Double(width) / 2.0 - 180.0) + cos(t / 5.0) * 30.0)
                    let y3 = CGFloat((Double(height) - 260.0) + sin(t / 6.0) * 30.0)
                    let rect3 = CGRect(x: x3, y: y3, width: 240, height: 240)
                    
                    var path1 = Path(ellipseIn: rect1)
                    var path2 = Path(ellipseIn: rect2)
                    var path3 = Path(ellipseIn: rect3)
                    
                    context.fill(path1, with: .color(c1))
                    context.fill(path2, with: .color(c2))
                    context.fill(path3, with: .color(c3))
                }
            }
            .blur(radius: 60)
            .ignoresSafeArea()
        }
    }
}
