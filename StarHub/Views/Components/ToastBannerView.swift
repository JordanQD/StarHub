import SwiftUI

/// Floating non-blocking toast pill overlaid at the bottom of `MainView`.
struct ToastBannerView: View {
    var store: ToastStore

    var body: some View {
        Group {
            if let toast = store.current {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: toast.symbol)
                        .foregroundStyle(toast.tint)
                        .font(.system(size: 14, weight: .semibold))
                    Text(toast.message)
                        .font(AppDesign.Font.body(.medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        store.dismiss(id: toast.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, AppDesign.Spacing.xs)
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.vertical, AppDesign.Spacing.sm)
                .floatingInteractiveGlass(in: Capsule())
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                .padding(.bottom, AppDesign.Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.animation(.snappy), value: store.current?.id)
    }
}
