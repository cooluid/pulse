import UIKit

@MainActor
protocol HapticFeedbackProviding {
    func notifyHoldReady()
    func notifySuccess()
}

@MainActor
struct HapticFeedback: HapticFeedbackProviding {
    func notifyHoldReady() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }

    func notifySuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
