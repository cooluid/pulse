import SwiftUI
import UIKit

struct PulseCombinedPressControl: UIViewRepresentable {
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityLongPressName: String
    let onPressChanged: @MainActor (Bool) -> Void
    let onTap: @MainActor () -> Void
    let onLongPress: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PulsePressControl {
        let view = PulsePressControl(frame: .zero)
        view.backgroundColor = .clear
        view.actionHandler = context.coordinator
        configureAccessibility(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: PulsePressControl, context: Context) {
        context.coordinator.parent = self
        let shouldResetPress = uiView.isEnabled && !isEnabled
        uiView.isEnabled = isEnabled
        configureAccessibility(uiView, coordinator: context.coordinator)
        if shouldResetPress {
            Task { @MainActor in
                context.coordinator.handlePressChanged(false)
            }
        }
    }

    private func configureAccessibility(
        _ view: PulsePressControl,
        coordinator: Coordinator
    ) {
        view.isAccessibilityElement = true
        view.accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
        view.accessibilityIdentifier = "today.checkin.button"
        view.accessibilityLabel = accessibilityLabel
        view.accessibilityHint = accessibilityHint
        view.accessibilityCustomActions = isEnabled
            ? [
                UIAccessibilityCustomAction(
                    name: accessibilityLongPressName,
                    target: coordinator,
                    selector: #selector(Coordinator.handleAccessibilityLongPress)
                )
            ]
            : nil
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PulseCombinedPressControl

        init(parent: PulseCombinedPressControl) {
            self.parent = parent
        }

        func handlePressChanged(_ isPressed: Bool) {
            parent.onPressChanged(isPressed)
        }

        @objc func handleTap(_ control: UIControl) {
            guard control.isEnabled else { return }
            parent.onTap()
        }

        func handleLongPress() {
            guard parent.isEnabled else { return }
            parent.onLongPress()
        }

        @objc func handleAccessibilityLongPress() -> Bool {
            guard parent.isEnabled else { return false }
            parent.onLongPress()
            return true
        }
    }

    @MainActor
    final class PulsePressControl: UIControl {
        weak var actionHandler: Coordinator?
        private var longPressTimer: Timer?
        private var touchOrigin: CGPoint?
        private var didRecognizeLongPress = false

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard isEnabled else { return false }
            touchOrigin = touch.location(in: self)
            didRecognizeLongPress = false
            actionHandler?.handlePressChanged(true)
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(
                timeInterval: PulseDesign.checkInLongPressDuration,
                target: self,
                selector: #selector(recognizeLongPress),
                userInfo: nil,
                repeats: false
            )
            return true
        }

        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            guard let touchOrigin else { return false }
            let point = touch.location(in: self)
            let distance = hypot(point.x - touchOrigin.x, point.y - touchOrigin.y)
            if distance > PulseDesign.checkInPressMovementTolerance {
                cancelPendingPress()
                return false
            }
            return true
        }

        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            longPressTimer?.invalidate()
            longPressTimer = nil
            touchOrigin = nil
            actionHandler?.handlePressChanged(false)
            if !didRecognizeLongPress {
                actionHandler?.handleTap(self)
            }
            didRecognizeLongPress = false
        }

        override func cancelTracking(with event: UIEvent?) {
            cancelPendingPress()
        }

        @objc private func recognizeLongPress() {
            guard isEnabled, isTracking else { return }
            didRecognizeLongPress = true
            actionHandler?.handleLongPress()
        }

        private func cancelPendingPress() {
            longPressTimer?.invalidate()
            longPressTimer = nil
            touchOrigin = nil
            didRecognizeLongPress = false
            actionHandler?.handlePressChanged(false)
        }

        override func accessibilityActivate() -> Bool {
            guard isEnabled, let actionHandler else { return false }
            actionHandler.handleTap(self)
            return true
        }
    }
}
