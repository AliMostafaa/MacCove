import SwiftUI

struct ExpandedNotchView: View {
    @Environment(NotchState.self) private var state
    @Namespace private var tabNamespace

    var body: some View {
        ZStack(alignment: .top) {
            // Ambient background bloom
            pageBackground

            VStack(spacing: 0) {
                pageTabBar
                pageContent
            }
        }
    }

    // MARK: - Ambient Background

    @ViewBuilder
    private var pageBackground: some View {
        EmptyView()
    }

    // MARK: - Tab Bar
    // matchedGeometryEffect makes the selection pill slide rather than cross-fade,
    // which is the single biggest quality signal in the tab bar interaction.

    private var pageTabBar: some View {
        HStack(spacing: 2) {
            ForEach(NotchPage.allCases) { page in
                Button {
                    withAnimation(NotchConstants.tabSpring) {
                        state.currentPage = page
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: page.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .offset(y: state.currentPage == page ? -0.5 : 0)
                        Text(page.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(state.currentPage == page ? .white : .white.opacity(0.32))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if state.currentPage == page {
                            Capsule()
                                .fill(.white.opacity(0.13))
                                .matchedGeometryEffect(id: "tabPill", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .animation(NotchConstants.tabSpring, value: state.currentPage)
            }

            Spacer()

            Button {
                if state.isMinimized {
                    state.restore()
                } else {
                    state.minimize()
                }
            } label: {
                Image(systemName: state.isMinimized ? "dot.circle" : "minus.circle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state.isMinimized ? NotchConstants.accentGlow.opacity(0.8) : .white.opacity(0.32))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help(state.isMinimized ? "Restore notch" : "Minimize to dot")
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        Group {
            switch state.currentPage {
            case .dashboard:
                DashboardView()
            case .shelf:
                ShelfView()
            case .clipboard:
                ClipboardView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Subtle slide + fade between pages
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(x: 0, y: 4)),
                removal:   .opacity.combined(with: .offset(x: 0, y: -4))
            )
        )
        .id(state.currentPage)
        .animation(NotchConstants.tabSpring, value: state.currentPage)
    }
}
