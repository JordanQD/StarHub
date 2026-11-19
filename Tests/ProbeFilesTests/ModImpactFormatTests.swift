import Foundation
import Testing
@testable import StarHubTHCore

struct ModImpactFormatTests {
    private let french = Locale(identifier: "fr_FR")
    private let english = Locale(identifier: "en_US")

    @Test func numbersAndPercentagesFollowRegionalFormats() {
        #expect(ModImpactFormat.number(1.25, digits: 2, locale: french) == "1,25")
        #expect(ModImpactFormat.number(1.25, digits: 2, locale: english) == "1.25")
        #expect(ModImpactFormat.percent(0.123, locale: french) == "12,3\u{00A0}%")
        #expect(ModImpactFormat.percent(0.0004, locale: english) == "0.04%")
    }

    /// Sous la seconde, des millisecondes : « −0,0 s » pour 40 ms disait zéro.
    @Test func shortDurationsStayReadable() {
        #expect(ModImpactFormat.duration(40, locale: french) == "40 ms")
        #expect(ModImpactFormat.duration(999, locale: english) == "999 ms")
        #expect(ModImpactFormat.duration(2_450, locale: french) == "2,5 s")
        #expect(ModImpactFormat.duration(12_400, locale: english) == "12 s")
        #expect(ModImpactFormat.duration(110_000, locale: french) == "1 min 50 s")
    }

    /// Un écart qui s'arrondit à 0 n'est ni un gain ni une perte.
    @Test func aRoundedZeroEvolutionIsStable() {
        #expect(ModImpactFormat.evolution(-0.4) == .stable)
        #expect(ModImpactFormat.evolution(0.49) == .stable)
        #expect(ModImpactFormat.evolution(-0.5) == .gain)
        #expect(ModImpactFormat.evolution(3) == .loss)
    }
}
