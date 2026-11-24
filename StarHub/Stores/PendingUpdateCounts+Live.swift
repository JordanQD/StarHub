import Foundation

struct PendingUpdateCounts: Equatable {
    let active: Int
    let paused: Int
    var total: Int { active + paused }
}

struct PendingUpdateRow: Identifiable {
    let update: NexusUpdateChecker.ModUpdate
    let mod: ModItem?
    let isLogOnly: Bool
    var id: String { update.uniqueId }
}

struct PendingUpdateList {
    let groups: NexusUpdateGroups<PendingUpdateRow>
    let snoozed: [PendingUpdateRow]
    let affirmed: [PendingUpdateRow]

    /// A live result covers the copy in the last game log. Match installed
    /// components by UniqueID and packs by their parent folder, never by Nexus page.
    @MainActor init(_ vm: StarHubTHViewModel) {
        let installed = vm.mods.flattenedMods
        let byID = Dictionary(installed.filter { !$0.uniqueId.isEmpty }.map { ($0.uniqueId.lowercased(), $0) },
                              uniquingKeysWith: { first, _ in first })
        let packByFolder = Dictionary(vm.mods.flatMap { pack in
            (pack.children ?? []).map { ($0.folderName, pack.folderName) }
        }, uniquingKeysWith: { first, _ in first })
        let byName = Dictionary(grouping: installed) { $0.name.lowercased() }
        let byLoggedName = Dictionary(grouping: installed) { ModFocusResolver.loggedForm(of: $0.name).lowercased() }

        let live = vm.nexusUpdates
        let sleeping = vm.snoozedUpdates
        let coveredIDs = Set((live + sleeping).map { $0.uniqueId.lowercased() })
        let coveredPacks = Set(coveredIDs.compactMap { byID[$0].flatMap { packByFolder[$0.folderName] } })
        let affirmed = Dictionary(grouping: vm.affirmedUpdates) { $0.uniqueId.lowercased() }
        var pending = live.map { PendingUpdateRow(update: $0, mod: byID[$0.uniqueId.lowercased()], isLogOnly: false) }
        var deferred = sleeping.map {
            PendingUpdateRow(update: $0, mod: byID[$0.uniqueId.lowercased()], isLogOnly: false)
        }
        var logged: [String: PendingUpdateRow] = [:]

        for entry in vm.outOfDateMods {
            let name = entry.name.lowercased()
            let matches = byName[name] ?? byLoggedName[name] ?? []
            let matchingPacks = Set(matches.compactMap { packByFolder[$0.folderName] })
            if matchingPacks.count == 1, matches.allSatisfy({ packByFolder[$0.folderName] != nil }),
               let pack = matchingPacks.first, coveredPacks.contains(pack) { continue }
            let mod = Set(matches.map(\.folderName)).count == 1 ? matches.first : nil
            let logID = "log:\(name)|\(entry.url)"
            let id = mod.flatMap { $0.uniqueId.isEmpty ? nil : $0.uniqueId } ?? logID
            let key = id.lowercased()
            let pack = mod.flatMap { packByFolder[$0.folderName] }
            if coveredIDs.contains(key) || pack.map(coveredPacks.contains) == true { continue }
            if let mod, UpdateCount.isAlreadyApplied(disk: mod.version, suggested: entry.version) { continue }
            if affirmed[key]?.contains(where: {
                NexusUpdateChecker.compare($0.affirmedVersion, entry.version) != .orderedAscending
            }) == true { continue }

            let update = NexusUpdateChecker.ModUpdate(uniqueId: id, name: entry.name,
                installedVersion: mod?.version ?? "", latestVersion: entry.version,
                nexusModId: NexusWebLinks.updatePageID(for: entry.url).map(String.init) ?? "",
                url: entry.url, uploadedTime: nil)
            let group = pack.map { "pack:\($0)" } ?? key
            if let previous = logged[group],
               NexusUpdateChecker.compare(previous.update.latestVersion, entry.version) != .orderedAscending {
                continue
            }
            logged[group] = PendingUpdateRow(update: update, mod: mod, isLogOnly: true)
        }

        let now = Date()
        for row in logged.values {
            if let expiry = vm.updateSnoozer.entry(for: row.id)?.expiresAt, expiry > now {
                deferred.append(row)
            } else {
                pending.append(row)
            }
        }
        groups = NexusUpdateGroups(pending.sorted {
            $0.update.name.localizedStandardCompare($1.update.name) == .orderedAscending
        }) { $0.mod?.isEnabled }
        snoozed = deferred.sorted {
            $0.update.name.localizedStandardCompare($1.update.name) == .orderedAscending
        }
        let byFolder = Dictionary(installed.map { ($0.folderName, $0) }, uniquingKeysWith: { first, _ in first })
        self.affirmed = vm.affirmedUpdates.map { entry in
            let mod = byFolder[entry.folderName]
            let update = NexusUpdateChecker.ModUpdate(uniqueId: entry.uniqueId, name: entry.name,
                installedVersion: entry.manifestVersion, latestVersion: entry.affirmedVersion,
                nexusModId: mod.map { vm.resolvedNexusModId(for: $0) } ?? "",
                url: "", uploadedTime: nil)
            return PendingUpdateRow(update: update, mod: mod, isLogOnly: false)
        }
    }
}

extension StarHubTHViewModel {
    var pendingUpdateCounts: PendingUpdateCounts {
        let groups = PendingUpdateList(self).groups
        return PendingUpdateCounts(active: groups.active.count, paused: groups.paused.count)
    }
}
