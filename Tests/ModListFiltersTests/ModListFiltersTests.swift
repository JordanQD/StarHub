import Testing
@testable import StarHubTHCore

struct ModListFiltersTests {
    @Test func focusLiftsEveryFilterAndPreservesOrder() {
        var filters = ModListFilters()
        filters.scope = .disabled
        filters.category = .uncategorized
        filters.configOnly = true
        filters.favoritesOnly = true
        filters.blacklistedOnly = true
        filters.frenchTranslation = .stale
        filters.search = "ancienne"
        filters.impactScope = .high
        filters.sort = .author

        filters.focus(on: "Ridgeside")

        #expect(filters.scope == .all)
        #expect(filters.category == .all)
        #expect(!filters.configOnly)
        #expect(!filters.favoritesOnly)
        #expect(!filters.blacklistedOnly)
        #expect(filters.frenchTranslation == .off)
        #expect(filters.search == "Ridgeside")
        #expect(filters.impactScope == .off)
        #expect(filters.sort == .author)
    }
}
