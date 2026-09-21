import UIKit

enum ForgeHaptic {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func delete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

enum ForgeSystem {
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
