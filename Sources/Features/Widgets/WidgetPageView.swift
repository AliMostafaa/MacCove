import SwiftUI

struct WidgetPageView: View {
    var body: some View {
        VStack(spacing: 0) {
            // ── Mini chips row ─────────────────────────────────────────────────
            MiniWidgetsBar()
                .padding(.top, 6)
                .padding(.bottom, 8)

            // ── Big widgets ────────────────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ClockWidget()
                    BatteryWidget()
                    SystemStatsWidget()
                    WifiResetWidget()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
