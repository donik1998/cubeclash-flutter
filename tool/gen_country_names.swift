import Foundation

// Emits the body of an ISO 3166-1 alpha-2 -> English country name map,
// sourced from the OS's ICU locale data rather than hand-typed.
let en = Locale(identifier: "en_US")
var rows: [(String, String)] = []

for code in Locale.isoRegionCodes {
    // Skip non-country regions (continents, groupings) which are numeric or 3-char.
    guard code.count == 2, code.allSatisfy({ $0.isUppercase && $0.isLetter }) else { continue }
    guard let name = en.localizedString(forRegionCode: code) else { continue }
    rows.append((code, name))
}

rows.sort { $0.0 < $1.0 }
for (code, name) in rows {
    let escaped = name.replacingOccurrences(of: "'", with: "\\'")
    print("  '\(code)': '\(escaped)',")
}
FileHandle.standardError.write("count=\(rows.count)\n".data(using: .utf8)!)
