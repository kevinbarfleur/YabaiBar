import SwiftUI

struct MenuBarLabelView: View {
    let activeSpaceLabel: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "square.3.layers.3d.top.filled")
            Text(activeSpaceLabel)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }
}
