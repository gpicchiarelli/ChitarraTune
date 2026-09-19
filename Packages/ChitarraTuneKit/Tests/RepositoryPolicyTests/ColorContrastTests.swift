import Foundation
import Testing

/// WCAG 2.2 contrast of every colour in the asset catalog, in every appearance (light, dark and
/// Increase Contrast), against the backgrounds the app actually draws it on.
///
/// Xcode's accessibility audit samples rendered pixels, which is unreliable on a screen that redraws
/// 40 times a second; this test checks the same promise from the source of truth.
@Suite("Colour contrast")
struct ColorContrastTests {
    typealias RGB = (red: Double, green: Double, blue: Double)

    enum Appearance: CaseIterable { case light, dark, lightHighContrast, darkHighContrast
        var isDark: Bool { self == .dark || self == .darkHighContrast }
        var isHighContrast: Bool { self == .lightHighContrast || self == .darkHighContrast }
    }

    static func color(_ name: String, _ appearance: Appearance) throws -> RGB {
        let data = try Data(contentsOf: Repo.url("App/Resources/Assets.xcassets/\(name).colorset/Contents.json"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(json["colors"] as? [[String: Any]])
        func matches(_ entry: [String: Any]) -> Bool {
            let values = Set(((entry["appearances"] as? [[String: String]]) ?? []).compactMap { $0["value"] })
            return values.contains("dark") == appearance.isDark && values.contains("high") == appearance.isHighContrast
        }
        let entry = try #require(entries.first(where: matches), "\(name) has no \(appearance) variant")
        let components = try #require((entry["color"] as? [String: Any])?["components"] as? [String: String])
        func value(_ key: String) throws -> Double { try #require(components[key].flatMap(Double.init)) }
        return (try value("red"), try value("green"), try value("blue"))
    }

    static func luminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.040_45 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    static func blend(_ top: RGB, _ alpha: Double, over bottom: RGB) -> RGB {
        (bottom.red * (1 - alpha) + top.red * alpha,
         bottom.green * (1 - alpha) + top.green * alpha,
         bottom.blue * (1 - alpha) + top.blue * alpha)
    }

    static let white: RGB = (1, 1, 1)
    static let black: RGB = (0, 0, 0)

    /// Opacity of the state-coloured wash behind the tuner, read from `TunerBackground` itself so a
    /// change there cannot silently drift out of sync with the value this test checks against.
    static func washOpacity(reduced: Bool) throws -> Double {
        let source = try Repo.text("App/Tuner/TunerBackground.swift")
        let pattern = try NSRegularExpression(pattern: #"isLuminanceReduced \? ([\d.]+) : ([\d.]+)"#)
        let range = NSRange(source.startIndex..., in: source)
        let match = try #require(pattern.firstMatch(in: source, range: range), "wash opacity not found in TunerBackground.swift")
        func group(_ index: Int) -> String { String(source[Range(match.range(at: index), in: source)!]) }
        return try #require(Double(reduced ? group(1) : group(2)))
    }

    /// The window background and the tinted washes drawn over it.
    static func backgrounds(_ appearance: Appearance) throws -> [(String, RGB)] {
        let base = appearance.isDark ? black : white
        let grouped: RGB = appearance.isDark ? (0.11, 0.11, 0.118) : (0.949, 0.949, 0.969)
        let wash = try washOpacity(reduced: false)
        var result: [(String, RGB)] = [("window", base), ("grouped form", grouped)]
        for tint in ["AccentColor", "TuneGreen", "TuneAmber", "TuneRed"] {
            result.append(("\(tint) wash", blend(try color(tint, appearance), wash, over: base)))
        }
        return result
    }

    @Test("Text colours reach 4.5:1 on every background, 7:1 with Increase Contrast",
          arguments: ["TuneGreen", "TuneAmber", "TuneRed", "TuneSecondaryLabel", "AccentColor"])
    func textColours(name: String) throws {
        for appearance in Appearance.allCases {
            let minimum = appearance.isHighContrast ? 7.0 : 4.5
            for (background, rgb) in try Self.backgrounds(appearance) {
                let ratio = Self.contrast(try Self.color(name, appearance), rgb)
                #expect(ratio >= minimum, "\(name) \(appearance) on \(background): \(ratio)")
            }
        }
    }

    @Test("Fills behind white text reach 4.5:1, the accent 7:1", arguments: ["TuneAccentFill", "TuneGreenFill", "TuneRedFill"])
    func fills(name: String) throws {
        for appearance in Appearance.allCases {
            let minimum = name == "TuneAccentFill" || appearance.isHighContrast ? 7.0 : 4.5
            let ratio = Self.contrast(try Self.color(name, appearance), Self.white)
            #expect(ratio >= minimum, "white on \(name) \(appearance): \(ratio)")
        }
    }

    @Test("Secondary buttons reach 7:1 (accent text on the pale accent capsule)")
    func secondaryButtons() throws {
        for appearance in Appearance.allCases {
            let capsule = try Self.color("TuneAccentTint", appearance)
            let ratio = Self.contrast(try Self.color("TuneAccentText", appearance), capsule)
            #expect(ratio >= 7, "\(appearance): \(ratio)")
        }
    }

    @Test("The contrast maths matches WCAG reference values")
    func reference() {
        #expect(abs(Self.contrast(Self.white, Self.black) - 21) < 0.001)
        #expect(abs(Self.contrast((0.463, 0.463, 0.463), Self.white) - 4.54) < 0.02) // #767676, the classic 4.5:1 grey
    }
}
