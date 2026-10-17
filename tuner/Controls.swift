import SwiftUI

/// A button that fires the moment it's touched (not on release) with no highlight
/// animation, so it reacts instantly.
struct PressButton<Label: View>: View {
    private let action: () -> Void
    private let label: Label
    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        label
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                    }
                    .onEnded { _ in isPressed = false }
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}
