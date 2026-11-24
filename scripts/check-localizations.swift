import Foundation

private let locales = ["en", "fr", "zh-Hans"]

private let formatPattern = try NSRegularExpression(
    pattern: #"%%|%(([1-9]\d*)\$)?[-+#0]*(?:\d+)?(?:\.\d+)?(hh|h|ll|l|L|z|t|j)?([@diouxXfFeEgGaAcsp])"#
)
private let keyPattern = try NSRegularExpression(pattern: #"static let \w+\s*=\s*"([^"]+)""#)

private func captures(_ match: NSTextCheckingResult, _ group: Int, in text: String) -> String? {
    Range(match.range(at: group), in: text).map { String(text[$0]) }
}

private func formatSignature(_ text: String) -> [String: Int] {
    var signature: [String: Int] = [:]
    var implicitSlot = 0
    for match in formatPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
        guard let conversion = captures(match, 4, in: text) else {
            signature["percent", default: 0] += 1
            continue
        }
        let slot: Int
        if let position = captures(match, 2, in: text).flatMap(Int.init) {
            slot = position
        } else {
            implicitSlot += 1
            slot = implicitSlot
        }
        let length = captures(match, 3, in: text) ?? ""
        signature["\(slot):\(length)\(conversion)", default: 0] += 1
    }
    return signature
}

private func strings(_ locale: String) throws -> [String: String] {
    let url = URL(fileURLWithPath: "assets/\(locale).lproj/Localizable.strings")
    let data = try Data(contentsOf: url)
    guard let result = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
        throw CocoaError(.propertyListReadCorrupt, userInfo: [NSURLErrorKey: url])
    }
    return result
}

let reference = try strings(locales[0])
let referenceKeys = Set(reference.keys)
var errors: [String] = []

for locale in locales.dropFirst() {
    let translations = try strings(locale)
    let keys = Set(translations.keys)
    for key in referenceKeys.subtracting(keys).sorted() { errors.append("\(locale): missing \(key)") }
    for key in keys.subtracting(referenceKeys).sorted() { errors.append("\(locale): unexpected \(key)") }
    for key in referenceKeys.intersection(keys).sorted() {
        guard let english = reference[key], let translation = translations[key] else { continue }
        if formatSignature(english) != formatSignature(translation) {
            errors.append("\(locale): mismatched format arguments for \(key)")
        }
    }
}

let source = try String(contentsOfFile: "StarHub/Localization/L10n.swift", encoding: .utf8)
    .split(separator: "\n")
    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    .joined(separator: "\n")
let declared = keyPattern.matches(in: source, range: NSRange(source.startIndex..., in: source))
    .compactMap { captures($0, 1, in: source) }
for key in Set(declared).subtracting(referenceKeys).sorted() {
    errors.append("L10n.swift: unknown key \(key)")
}

if errors.isEmpty {
    print("Verified \(referenceKeys.count) keys across \(locales.count) localizations.")
} else {
    for error in errors { print(error) }
    exit(EXIT_FAILURE)
}
