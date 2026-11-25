import SwiftUI

/// Mod Backups hub: Install Backups, Config Backups, and Recoverable Files,
/// using native macOS HIG toolbar principal segmented control, unified toolbar
/// search (`⌘F`), and Finder-style expandable tables.
struct BackupsView: View {
    var vm: StarHubTHViewModel
    @ObservedObject var localization: LocalizationStore
    /// Filter passed from the config editor ("All backups of this mod…").
    @State private var configFilter: String?
    @State private var searchText = ""
    @State private var searchPresented = false

    var body: some View {
        Group {
            switch navigation.backupsSegment {
            case .install:
                ModInstallBackupsView(vm: vm, localization: localization, search: $searchText)
            case .config:
                ModConfigBackupsView(vm: vm, localization: localization,
                                     modFilter: $configFilter, search: $searchText)
            case .files:
                RecoverableFilesView(viewModel: vm, localization: localization, search: $searchText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppDesign.Color.windowBg)
        .navigationSubtitle(localization.L(L10n.Backups.pageSubtitle))
        .searchable(text: $searchText, isPresented: $searchPresented,
                    placement: .toolbar, prompt: localization.L(L10n.ModInstall.backupsSearch))
        .background {
            Button(localization.L(L10n.ModInstall.backupsSearch)) { searchPresented = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(localization.L(L10n.A11y.backupsSegment), selection: Binding(
                    get: { navigation.backupsSegment },
                    set: { navigation.backupsSegment = $0 }
                )) {
                    ForEach(BackupsSegment.allCases, id: \.self) { segment in
                        Text(label(segment)).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    navigation.openMaintenance()
                } label: {
                    Label(localization.L(L10n.Maintenance.backupsFreeSpaceLink), systemImage: "internaldrive")
                }
                .help(localization.L(L10n.Maintenance.backupsFreeSpaceLink))
            }

            if #available(macOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .automatic)
            }
        }
        .onAppear(perform: consumeConfigFocus)
        .onChange(of: navigation.pendingConfigBackupsFocus) { _, _ in consumeConfigFocus() }
    }

    private var navigation: NavigationStore { vm.navigationStore }

    private func consumeConfigFocus() {
        guard let folder = navigation.pendingConfigBackupsFocus else { return }
        configFilter = folder
        navigation.pendingConfigBackupsFocus = nil
    }

    private func label(_ segment: BackupsSegment) -> String {
        switch segment {
        case .install: return localization.L(L10n.Backups.segmentInstall)
        case .config:  return localization.L(L10n.Backups.segmentConfig)
        case .files:   return localization.L(L10n.Backups.segmentFiles)
        }
    }
}
