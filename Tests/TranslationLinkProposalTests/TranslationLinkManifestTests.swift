import Testing
import Foundation
@testable import StarHubTHCore

/// C7-T1 — un candidat à `EntryDll` est un mod de code (fork), pas un pack.
@Suite struct TranslationLinkManifestTests {

    private func manifest(_ text: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TLManifest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("manifest.json")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    @Test func aForkWithItsOwnDllHasCode() throws {
        let path = try manifest("""
        {
          // fork mrbabilo
          "Name": "Easy Access Buttons FR",
          "UniqueID": "mrbabilo.EasyAccessButtons",
          "EntryDll": "EasyAccessButtonsFR.dll",
        }
        """)
        #expect(TranslationLinkManifest.hasCode(manifestAt: path))
    }

    @Test func anI18nOnlyPackHasNoCode() throws {
        let path = try manifest("""
        { "Name": "Some Mod FR", "UniqueID": "x.SomeModFR",
          "ContentPackFor": { "UniqueID": "Pathoschild.ContentPatcher" } }
        """)
        #expect(TranslationLinkManifest.hasCode(manifestAt: path) == false)
    }

    @Test func aMissingOrBlankManifestHasNoCode() throws {
        #expect(TranslationLinkManifest.hasCode(manifestAt: "/nonexistent/manifest.json") == false)
        let blank = try manifest(#"{ "Name": "X FR", "EntryDll": "  " }"#)
        #expect(TranslationLinkManifest.hasCode(manifestAt: blank) == false)
    }
}
