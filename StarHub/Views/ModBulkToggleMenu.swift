import SwiftUI

/// Actions sur la sélection, le cadrage courant et l’historique.
struct ModBulkToggleMenu: View {
    let scoped: [ModItem]
    let selected: [ModItem]
    var viewModel: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    @Binding var target: Bool?
    @State private var showsHistory = false

    var body: some View {
        let anyDisabled = scoped.contains { !$0.isEnabled }
        let anyEnabled = scoped.contains { $0.isEnabled }
        Menu {
            if !selected.isEmpty {
                Button {
                    viewModel.toggleMods(selected, enable: true)
                } label: {
                    Label(localization.L(L10n.Mods.selectionEnable), systemImage: "play.circle")
                }
                .disabled(!selected.contains { !$0.isEnabled })

                Button {
                    viewModel.toggleMods(selected, enable: false)
                } label: {
                    Label(localization.L(L10n.Mods.selectionPause), systemImage: "pause.circle")
                }
                .disabled(!selected.contains { $0.isEnabled })

                Divider()
            }

            Button {
                target = true
            } label: {
                Label(localization.L(L10n.Mods.enableAll), systemImage: "checkmark.circle")
            }
            .disabled(!anyDisabled)

            Button {
                target = false
            } label: {
                Label(localization.L(L10n.Mods.disableAll), systemImage: "xmark.circle")
            }
            .disabled(!anyEnabled)

            Divider()
            Button {
                showsHistory = true
            } label: {
                Label(localization.L(L10n.ActivationHistory.menuEntry), systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Label(localization.L(L10n.Mods.activationActions), systemImage: "power")
        }
        .help(localization.L(L10n.Mods.activationActions))
        .sheet(isPresented: $showsHistory) {
            VStack(spacing: 0) {
                ScrollView {
                    ActivationHistorySection(viewModel: viewModel, localization: localization)
                        .padding(AppDesign.Spacing.lg)
                }
                Divider()
                HStack {
                    Spacer()
                    Button(localization.L(L10n.Main.ok)) { showsHistory = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(AppDesign.Spacing.md)
            }
            .frame(minWidth: 560, idealWidth: 640, minHeight: 360, idealHeight: 520)
            // « OK » porte Entrée ; Échap ferme aussi.
            .onExitCommand { showsHistory = false }
        }
    }
}
