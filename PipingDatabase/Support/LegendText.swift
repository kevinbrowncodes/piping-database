import Foundation

/// Turns a dataset legend note into a caption fit for the dims cards.
///
/// The bundled JSON legends are written for the extraction pipeline —
/// "elbow90/elbow45: end to opposite outside face (overall, per diagram)",
/// "Minimum thickness of flange (catalog C). Inside perType.LJ …" — and that
/// provenance belongs in the data files, not beside a dimension on a phone
/// (BUG-0004). This keeps the first plain-language clause and drops the
/// scope prefix, parenthetical notes, catalog/print asides and unit suffixes.
enum LegendText {
    static func display(_ raw: String) -> String {
        var s = raw

        // 1. Parenthetical notes, innermost first: "(catalog C)", "(per diagram)".
        while let r = s.range(of: #"\s*\([^()]*\)"#, options: .regularExpression) {
            s.removeSubrange(r)
        }

        // 2. First clause only: cut at a sentence boundary or a semicolon.
        for stop in [". ", "; "] {
            if let r = s.range(of: stop) { s = String(s[..<r.lowerBound]) }
        }

        // 3. Scope prefix such as "elbow90/elbow45:" or "Sockolet only:".
        if let colon = s.firstIndex(of: ":"),
           s.distance(from: s.startIndex, to: colon) <= 45 {
            s = String(s[s.index(after: colon)...])
        }

        // 4. Extraction asides that survive without parentheses.
        for pattern in [#",?\s*printed\s+'[^']*'"#, #",?\s*as printed"#,
                        #",?\s*per catalog diagram"#, #",?\s*per diagram"#,
                        #",\s*decimal\b"#, #",\s*inches\b"#, #",\s*pounds\b"#] {
            while let r = s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                s.removeSubrange(r)
            }
        }

        // 5. Tidy: single spaces, no dangling punctuation, capitalised.
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",.;:")))
        guard let first = s.first else { return raw }
        return first.uppercased() + s.dropFirst()
    }
}
