import SwiftUI

struct DiscoverySectionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            configuration.title
            configuration.icon
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
    }
}

struct DiscoveryShelf<Card: View>: View {
    let rows: [DiscoveryScoping.Row]
    let localization: LocalizationStore
    @ViewBuilder let card: (DiscoveryScoping.Row) -> Card
    @State private var visibleWidth: CGFloat = 0
    @State private var stripFrame: CGRect = .zero
    @Namespace private var scrollSpace

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: AppDesign.Grid.gutter) {
                    ForEach(rows) { row in
                        card(row)
                            .frame(width: AppDesign.Grid.minCardWidth)
                    }
                }
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .named(scrollSpace))
                } action: { stripFrame = $0 }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: scrollSpace)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { visibleWidth = $0 }
            .overlay(alignment: .leading) {
                if stripFrame.minX < -1 {
                    arrow(.backward) { move(by: -1, proxy: proxy) }
                }
            }
            .overlay(alignment: .trailing) {
                if visibleWidth > 0, stripFrame.maxX > visibleWidth + 1 {
                    arrow(.forward) { move(by: 1, proxy: proxy) }
                }
            }
        }
    }

    private enum Direction { case backward, forward }

    @ViewBuilder
    private func arrow(_ direction: Direction, action: @escaping () -> Void) -> some View {
        let backward = direction == .backward
        let title = localization.L(backward ? L10n.Main.navBack : L10n.Main.navForward)
        let button = Button(action: action) {
            Label(title, systemImage: backward ? "chevron.backward" : "chevron.forward")
                .labelStyle(.iconOnly)
                .frame(width: 16, height: 42)
        }
        .help(title)
        .controlSize(.regular)
        .buttonBorderShape(.capsule)
        .padding(AppDesign.Spacing.xs)
        if #available(macOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func move(by direction: Int, proxy: ScrollViewProxy) {
        let stride = AppDesign.Grid.minCardWidth + AppDesign.Grid.gutter
        let first = Int((max(0, -stripFrame.minX) / stride).rounded(.down))
        let page = max(1, Int(visibleWidth / stride))
        let target = min(max(0, first + direction * page), rows.count - 1)
        withMotion { proxy.scrollTo(rows[target].id, anchor: .leading) }
    }
}

struct DiscoveryPageEnd: View {
    let isLoading: Bool
    let nextOffset: Int?
    let load: () -> Void
    @State private var nearBottom = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Color.clear
            }
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: Bool.self) { geometry in
            guard let viewport = geometry.bounds(of: .scrollView(axis: .vertical)) else { return false }
            let marker = geometry.frame(in: .scrollView(axis: .vertical))
            return marker.maxY >= 0 && marker.minY <= viewport.height + AppDesign.Grid.minCardWidth
        } action: { nearBottom = $0 }
        .task(id: nearBottom && !isLoading ? nextOffset : nil) {
            if nearBottom && !isLoading && nextOffset != nil { load() }
        }
    }
}
