import SwiftUI

struct ModTableToggle: View {
    let mod: ModItem
    var vm: StarHubTHViewModel
    let localization: LocalizationStore
    @State private var localIsOn: Bool?
    @State private var pendingToggle: DispatchWorkItem?
    @State private var pendingActivation: ModItem?
    @State private var pendingConflict: ConflictActivation?

    var body: some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            // Spinner pendant l'opération de toggle (rename du
            // dossier dans Mods/ entre X et .X). Disparaît dès
            // que pendingToggleFolder est remis à nil par le VM.
            if vm.pendingToggleFolder == mod.folderName {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            }
            Toggle("", isOn: Binding(
                get: { localIsOn ?? mod.isEnabled },
                set: { newValue in
                    localIsOn = newValue
                    // Annule un toggle en attente : sans cela, un
                    // double-clic laissait deux timers tirer et le 1er
                    // clic gagnait au lieu du dernier.
                    pendingToggle?.cancel()
                    let work = DispatchWorkItem {
                        if newValue != mod.isEnabled {
                            // Activer un mod que smapi.io signale cassé
                            // demande une confirmation ; le mettre en
                            // pause, jamais. La bascule optimiste est
                            // rendue tout de suite : l'interrupteur ne
                            // doit pas rester sur « actif » pendant que
                            // l'alerte attend une réponse.
                            if vm.activationWarning(for: mod) != nil {
                                localIsOn = nil
                                pendingActivation = mod
                                return
                            }
                            // Même porte, source différente : un conflit
                            // déclaré ou observé dans le journal avec un
                            // mod déjà actif (tâche 9).
                            if let other = vm.conflictWarning(for: mod) {
                                localIsOn = nil
                                pendingConflict = ConflictActivation(mod: mod, other: other)
                                return
                            }
                            // Keep the optimistic value until toggleMod's completion
                            // confirms vm.scanStore.mods has actually caught up — clearing it
                            // eagerly here races the background scanMods() and made
                            // the switch visibly snap back to its old position.
                            vm.toggleMod(mod) {
                                localIsOn = nil
                            }
                        } else {
                            localIsOn = nil
                        }
                    }
                    pendingToggle = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
                }
            ))
                .toggleStyle(SwitchToggleStyle(tint: AppDesign.Color.installed))
                .controlSize(.small)
                // Annuler un toggle en attente quand la rangée disparaît
                // (virtualisation, navigation) : sinon le debounce 300 ms
                // tirait pour un mod désaffiché.
                .onDisappear { pendingToggle?.cancel() }
                .labelsHidden()
                .accessibilityLabel(String(format: localization.L(L10n.Mods.toggleA11yLabel), mod.name))
                .accessibilityHint(localization.L(L10n.Mods.toggleA11yHint))
                .accessibilityValue(mod.isEnabled ? localization.L(L10n.Mods.enabled) : localization.L(L10n.Mods.disabled))
        }
        .compatibilityGate(vm: vm, pending: $pendingActivation) { target in
            vm.toggleMod(target)
        }
        .conflictActivationGate(vm: vm, pending: $pendingConflict) { target in
            vm.toggleMod(target)
        }
    }
}
