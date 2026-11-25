import Testing
import Foundation
@testable import StarHubTHCore

struct TranslationTargetLanguageTests {

    @Test func autoResolvesFromAppAndSystemLocales() {
        #expect(TranslationTargetLanguage.auto.resolve(appLanguage: "zh-Hans", systemLocales: ["en-US"]) == .zh)
        #expect(TranslationTargetLanguage.auto.resolve(appLanguage: "fr", systemLocales: ["en-US"]) == .fr)
        #expect(TranslationTargetLanguage.auto.resolve(appLanguage: "en", systemLocales: ["ja-JP"]) == .ja)
        #expect(TranslationTargetLanguage.auto.resolve(appLanguage: "en", systemLocales: ["en-US"]) == .zh)
    }

    @Test func explicitPreferenceOverridesAppLanguage() {
        #expect(TranslationTargetLanguage.fr.resolve(appLanguage: "zh-Hans", systemLocales: ["zh-Hans-CN"]) == .fr)
        #expect(TranslationTargetLanguage.zh.resolve(appLanguage: "fr", systemLocales: ["fr-FR"]) == .zh)
    }

    @Test func fileNamesAndModLanguagesMatchVariants() {
        let zh = TranslationTargetLanguage.Resolved.zh
        #expect(zh.primaryFileName == "zh.json")
        #expect(zh.matchesFileName("zh.json"))
        #expect(zh.matchesFileName("zh-CN.json"))
        #expect(!zh.matchesFileName("fr.json"))
        #expect(zh.matchesModLanguages(["en", "zh"]))
        #expect(zh.matchesModLanguages(["zh-cn"]))
        #expect(!zh.matchesModLanguages(["en", "fr"]))
    }

    @Test func titleAndSampleValueHeuristicsDetectChineseAndFrench() {
        let zh = TranslationTargetLanguage.Resolved.zh
        #expect(zh.matchesTitle("[CP] CJB Cheats Menu Warps - Chinese"))
        #expect(zh.matchesTitle("Automate 简体中文汉化"))
        #expect(!zh.matchesTitle("Automate"))
        #expect(zh.matchesSampleValues(["设置", "打开菜单"]))
        #expect(!zh.matchesSampleValues(["Settings", "Open menu"]))

        let fr = TranslationTargetLanguage.Resolved.fr
        #expect(fr.matchesTitle("Automate - Traduction FR"))
        #expect(fr.deepLCode == "FR")
        #expect(zh.deepLCode == "ZH-HANS")
    }
}
