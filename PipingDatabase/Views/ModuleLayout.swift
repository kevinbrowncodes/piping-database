import SwiftUI

/// Places a module's scrolling content and its picker wheels.
///
/// Portrait / regular height: content above a 130-pt wheel bar (the original
/// layout). Compact height (iPhone landscape): wheels move to the trailing
/// edge and fill the height so the drawing and cards keep the room they need
/// instead of being clipped to a 160-pt sliver (BUG-0007).
struct ModuleLayout<Content: View, Pickers: View>: View {
    @Environment(\.verticalSizeClass) private var vSize
    var pickerWidth: CGFloat = 360
    @ViewBuilder let content: () -> Content
    @ViewBuilder let pickers: () -> Pickers

    var body: some View {
        if vSize == .compact {
            HStack(spacing: 0) {
                content()
                pickers()
                    .frame(width: pickerWidth)
                    .frame(maxHeight: .infinity)
                    .background(.bar)
            }
        } else {
            VStack(spacing: 0) {
                content()
                pickers()
                    .frame(height: 130)
                    .frame(maxWidth: 600)
                    .background(.bar)
            }
        }
    }
}
