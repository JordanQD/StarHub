import Testing
@testable import StarHubTHCore

@Suite("Flèches dans la liste des mods")
struct ModListKeyStepTests {
    private let order = (1...30).map { "mod-\($0)" }

    private func step(_ current: String?, _ move: ModListKeyStep.Move) -> String? {
        ModListKeyStep.target(from: current, move: move, in: order)
    }

    @Test func parcourtLaListeSansCoupure() {
        #expect(step("mod-12", .next) == "mod-13")
        #expect(step("mod-13", .previous) == "mod-12")
        #expect(step("mod-24", .next) == "mod-25")
    }

    @Test func auxBoutsRienNeBouge() {
        #expect(step("mod-30", .next) == nil)
        #expect(step("mod-1", .previous) == nil)
    }

    @Test func sansSelectionOnPartDesExtremites() {
        #expect(step(nil, .next) == "mod-1")
        #expect(step(nil, .previous) == "mod-30")
        #expect(step("hors-cadrage", .next) == "mod-1")
    }

    @Test func debutEtFin() {
        #expect(step("mod-20", .first) == "mod-1")
        #expect(step("mod-4", .last) == "mod-30")
    }

    @Test func listeVide() {
        #expect(ModListKeyStep.target(from: nil, move: .next, in: []) == nil)
        #expect(ModListKeyStep.target(from: nil, move: .last, in: []) == nil)
    }
}
