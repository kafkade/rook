import SwiftUI
import UIKit

enum RookColor {
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
    static let canvas = adaptive(
        UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1),
        UIColor(red: 0.063, green: 0.114, blue: 0.188, alpha: 1)
    )
    static let surface = adaptive(
        .white, UIColor(red: 0.098, green: 0.161, blue: 0.251, alpha: 1)
    )
    static let secondary = adaptive(
        UIColor(red: 0.31, green: 0.38, blue: 0.47, alpha: 1),
        UIColor(red: 0.70, green: 0.77, blue: 0.85, alpha: 1)
    )
    static let accent = adaptive(
        UIColor(red: 0.45, green: 0.29, blue: 0.07, alpha: 1),
        UIColor(red: 1, green: 0.835, blue: 0.51, alpha: 1)
    )
    static let onAccent = adaptive(
        .white, UIColor(red: 0.063, green: 0.114, blue: 0.188, alpha: 1)
    )
    static let track = adaptive(
        UIColor(red: 0.76, green: 0.81, blue: 0.87, alpha: 1),
        UIColor(red: 0.21, green: 0.28, blue: 0.37, alpha: 1)
    )
}

extension View {
    func rookList() -> some View {
        self.scrollContentBackground(.hidden).background(RookColor.canvas)
            .tint(RookColor.accent)
    }
    func rookPrimary() -> some View {
        self.buttonStyle(.borderedProminent)
            .tint(RookColor.accent).foregroundStyle(RookColor.onAccent)
    }

    func rookPrivacyCover() -> some View { modifier(RookPrivacyCover()) }

    func rookIssueHost(active: Bool = true) -> some View {
        modifier(RookIssueHost(active: active))
    }
}

private struct RookPrivacyCover: ViewModifier {
    @EnvironmentObject private var model: RookModel
    func body(content: Content) -> some View {
        ZStack {
            content.accessibilityHidden(model.privacyCover)
            if model.privacyCover {
                RookColor.canvas.ignoresSafeArea()
                Label("Rook · Your training stays private", systemImage: "lock.fill")
                    .padding().foregroundStyle(RookColor.secondary)
            }
        }
    }
}

private struct RookIssueHost: ViewModifier {
    @EnvironmentObject private var model: RookModel
    let active: Bool
    func body(content: Content) -> some View {
        content.alert(item: Binding(
            get: { active && !model.privacyCover ? model.issue : nil },
            set: { if active { model.issue = $0 } }
        )) { issue in
            Alert(title: Text(issue.title), message: Text(issue.message), dismissButton: .default(Text("OK")))
        }
    }
}
