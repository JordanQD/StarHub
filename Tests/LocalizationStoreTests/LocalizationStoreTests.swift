import Foundation
import Testing
@testable import StarHubTHCore

@Suite struct LocalizationStoreTests {
    @Test(arguments: ["fr", "en", "zh-Hans"])
    func resolvesStringsAndGuideFromTheBundle(_ language: String) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }

        let contents = root.appendingPathComponent("Contents")
        let resources = contents.appendingPathComponent("Resources/\(language).lproj")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleDevelopmentRegion": language, "CFBundlePackageType": "BNDL"],
            format: .xml, options: 0)
        try info.write(to: contents.appendingPathComponent("Info.plist"))

        let greeting = switch language {
        case "fr": "Bonjour"
        case "zh-Hans": "你好"
        default: "Hello"
        }
        try "\"greeting\" = \"\(greeting)\";\n".write(
            to: resources.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        try greeting.write(to: resources.appendingPathComponent("Guide.md"), atomically: true, encoding: .utf8)

        let bundle = try #require(Bundle(url: root))
        let store = LocalizationStore(bundle: bundle)
        let resolver: L10nResolver = store
        #expect(store.currentLanguage == language)
        #expect(store.L("greeting") == greeting)
        #expect(resolver.localized("greeting") == greeting)
        let guide = try #require(store.guideURL)
        #expect(try String(contentsOf: guide, encoding: .utf8) == greeting)
    }

    @Test func missingStringReturnsItsKey() {
        let resolver: L10nResolver = LocalizationStore()
        #expect(resolver.localized("some.missing.key") == "some.missing.key")
    }
}
