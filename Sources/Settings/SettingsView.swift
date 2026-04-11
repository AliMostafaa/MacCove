import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(NotchState.self) private var state

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            activationTab
                .tabItem {
                    Label("Activation", systemImage: "cursorarrow.motionlines")
                }

            featuresTab
                .tabItem {
                    Label("Features", systemImage: "square.grid.2x2")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 320)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { state.settings.launchAtLogin },
                    set: { newValue in
                        state.settings.launchAtLogin = newValue
                        LaunchAtLoginHelper.setEnabled(newValue)
                    }
                ))

                Toggle("Show in Menu Bar", isOn: .constant(true))
                    .disabled(true)
                    .help("Menu bar icon is always visible")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Activation

    private var activationTab: some View {
        Form {
            Section("Hover Sensitivity") {
                HStack {
                    Text("Tight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { state.settings.hoverSensitivity },
                            set: { state.settings.hoverSensitivity = $0 }
                        ),
                        in: 5...50,
                        step: 5
                    )
                    Text("Loose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("How close your cursor needs to be to activate the notch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Collapse Delay") {
                HStack {
                    Text("Fast")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { state.settings.collapseDelay },
                            set: { state.settings.collapseDelay = $0 }
                        ),
                        in: 0.1...1.5,
                        step: 0.1
                    )
                    Text("Slow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("How long to wait before collapsing when cursor leaves")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Features

    private var featuresTab: some View {
        Form {
            Section("Enabled Pages") {
                Toggle("Now Playing", isOn: Binding(
                    get: { state.settings.enableNowPlaying },
                    set: { state.settings.enableNowPlaying = $0 }
                ))

                Toggle("Drop Shelf", isOn: Binding(
                    get: { state.settings.enableShelf },
                    set: { state.settings.enableShelf = $0 }
                ))

                Toggle("Widgets", isOn: Binding(
                    get: { state.settings.enableWidgets },
                    set: { state.settings.enableWidgets = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("MacCove")
                .font(.title2.bold())

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Transform your MacBook's notch into a powerful interactive hub")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
