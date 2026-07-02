//
//  CollectionAppearanceCatalog.swift
//  Doughy

import SwiftUI
import UIKit

// MARK: - Icons

/// A selectable collection icon: a shared semantic `key` (persisted, cross-platform),
/// a localized `label` for the picker, and the iOS glyph that draws it.
struct CollectionIcon: Identifiable, Hashable {
    /// How the icon is drawn on iOS. `emoji` is rendered as text (full color); `symbol`
    /// is an SF Symbol; `asset` is a custom template image in the asset catalog.
    enum Glyph: Hashable {
        case emoji(String)
        case symbol(String)
        case asset(String)
    }

    let key: String
    let label: String
    let glyph: Glyph

    var id: String { key }
}

/// The shared, cross-platform collection-icon catalog. The persisted value is a semantic
/// slug, mapped here to an emoji glyph (Android maps the same slug to a Material icon), so
/// an icon chosen on one platform resolves on the other and round-trips through `.doughy`.
///
/// `all` is the curated, baking-first picker list. `legacyEmoji` additionally resolves the
/// older Android slugs that aren't offered in the iOS picker, so a collection icon chosen
/// on Android still renders here. An unknown slug resolves to `nil`, so the avatar safely
/// falls back to the collection's first letter.
enum CollectionIconCatalog {
    static let customEmojiPrefix = "emoji:"

    static let all: [CollectionIcon] = [
        CollectionIcon(key: "bread", label: String(localized: "collection.icon.bread", defaultValue: "Bread"), glyph: .emoji("🍞")),
        CollectionIcon(key: "bagel", label: String(localized: "collection.icon.bagel", defaultValue: "Bagel"), glyph: .emoji("🥯")),
        CollectionIcon(key: "croissant", label: String(localized: "collection.icon.croissant", defaultValue: "Croissant"), glyph: .emoji("🥐")),
        CollectionIcon(key: "pretzel", label: String(localized: "collection.icon.pretzel", defaultValue: "Pretzel"), glyph: .emoji("🥨")),
        CollectionIcon(key: "pancakes", label: String(localized: "collection.icon.pancakes", defaultValue: "Pancakes"), glyph: .emoji("🥞")),
        CollectionIcon(key: "pizza", label: String(localized: "collection.icon.pizza", defaultValue: "Pizza"), glyph: .emoji("🍕")),
        CollectionIcon(key: "grain", label: String(localized: "collection.icon.grain", defaultValue: "Grain"), glyph: .emoji("🌾")),
        CollectionIcon(key: "cake", label: String(localized: "collection.icon.cake", defaultValue: "Cake"), glyph: .emoji("🍰")),
        CollectionIcon(key: "cupcake", label: String(localized: "collection.icon.cupcake", defaultValue: "Cupcake"), glyph: .emoji("🧁")),
        CollectionIcon(key: "cookie", label: String(localized: "collection.icon.cookie", defaultValue: "Cookie"), glyph: .emoji("🍪")),
        CollectionIcon(key: "pie", label: String(localized: "collection.icon.pie", defaultValue: "Pie"), glyph: .emoji("🥧")),
        CollectionIcon(key: "donut", label: String(localized: "collection.icon.donut", defaultValue: "Donut"), glyph: .emoji("🍩")),
        CollectionIcon(key: "icecream", label: String(localized: "collection.icon.icecream", defaultValue: "Ice cream"), glyph: .emoji("🍨")),
        CollectionIcon(key: "egg", label: String(localized: "collection.icon.egg", defaultValue: "Egg"), glyph: .emoji("🥚")),
        CollectionIcon(key: "cheese", label: String(localized: "collection.icon.cheese", defaultValue: "Cheese"), glyph: .emoji("🧀")),
        CollectionIcon(key: "honey", label: String(localized: "collection.icon.honey", defaultValue: "Honey"), glyph: .emoji("🍯")),
        CollectionIcon(key: "coffee", label: String(localized: "collection.icon.coffee", defaultValue: "Coffee"), glyph: .emoji("☕")),
        CollectionIcon(key: "tea", label: String(localized: "collection.icon.tea", defaultValue: "Tea"), glyph: .emoji("🍵")),
        CollectionIcon(key: "wine", label: String(localized: "collection.icon.wine", defaultValue: "Wine"), glyph: .emoji("🍷")),
        CollectionIcon(key: "oven", label: String(localized: "collection.icon.oven", defaultValue: "Oven"), glyph: .emoji("🔥")),
        CollectionIcon(key: "herb", label: String(localized: "collection.icon.herb", defaultValue: "Herb"), glyph: .emoji("🌿")),
        CollectionIcon(key: "star", label: String(localized: "collection.icon.star", defaultValue: "Star"), glyph: .emoji("⭐")),
        CollectionIcon(key: "heart", label: String(localized: "collection.icon.heart", defaultValue: "Heart"), glyph: .emoji("❤️")),
        CollectionIcon(key: "home", label: String(localized: "collection.icon.home", defaultValue: "Home"), glyph: .emoji("🏠")),
    ]

    /// Android slugs not offered in the iOS picker, kept resolvable for cross-platform import.
    private static let legacyEmoji: [String: String] = [
        "burger": "🍔", "dinner": "🍝", "brunch": "🥐", "noodles": "🍜",
        "rice": "🍚", "meal": "🍱", "soup": "🍲", "tapas": "🍢",
        "restaurant": "🍽️", "flatware": "🍴", "cocktail": "🍸",
        "plant": "🌱", "fridge": "🧊", "blender": "🥤", "microwave": "🔥",
        "bolt": "⚡",
    ]

    private static let byKey: [String: CollectionIcon] = {
        var map = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })
        for (key, emoji) in legacyEmoji where map[key] == nil {
            map[key] = CollectionIcon(key: key, label: key.capitalized, glyph: .emoji(emoji))
        }
        return map
    }()

    /// Resolves a persisted icon slug to its catalog entry, or nil (→ first-letter avatar).
    static func icon(for key: String?) -> CollectionIcon? {
        guard let key else { return nil }
        if let emoji = customEmoji(from: key) {
            return CollectionIcon(key: key, label: emoji, glyph: .emoji(emoji))
        }
        return byKey[key]
    }

    static func customEmojiKey(for input: String) -> String? {
        normalizedCustomEmoji(input).map { customEmojiPrefix + $0 }
    }

    static func customEmoji(from key: String) -> String? {
        guard key.hasPrefix(customEmojiPrefix) else { return nil }
        return normalizedCustomEmoji(String(key.dropFirst(customEmojiPrefix.count)))
    }

    static func normalizedCustomEmoji(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let character = trimmed.first else { return nil }
        let scalars = Array(character.unicodeScalars)
        let hasEmojiPresentation = scalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmojiModifierBase
        }
        let hasEmojiSequenceMarker = scalars.contains { scalar in
            scalar.value == 0xFE0F || scalar.value == 0x200D || scalar.value == 0x20E3 || scalar.properties.isEmojiModifier
        }
        guard hasEmojiPresentation || hasEmojiSequenceMarker else { return nil }
        return String(character)
    }
}

// MARK: - Colors

/// A selectable collection color: a shared `key` (persisted) and its rendered hue.
/// Keys and values mirror the Android `recipeColorCatalog` so colors round-trip.
struct CollectionColorOption: Identifiable, Hashable {
    let key: String
    let label: String
    let color: Color

    var id: String { key }
}

enum CollectionColorCatalog {
    static let all: [CollectionColorOption] = [
        CollectionColorOption(key: "red", label: String(localized: "collection.color.red", defaultValue: "Red"), color: Color(hex: 0xF44336)),
        CollectionColorOption(key: "pink", label: String(localized: "collection.color.pink", defaultValue: "Pink"), color: Color(hex: 0xE91E63)),
        CollectionColorOption(key: "purple", label: String(localized: "collection.color.purple", defaultValue: "Purple"), color: Color(hex: 0x9C27B0)),
        CollectionColorOption(key: "deepPurple", label: String(localized: "collection.color.deep_purple", defaultValue: "Deep Purple"), color: Color(hex: 0x673AB7)),
        CollectionColorOption(key: "indigo", label: String(localized: "collection.color.indigo", defaultValue: "Indigo"), color: Color(hex: 0x3F51B5)),
        CollectionColorOption(key: "blue", label: String(localized: "collection.color.blue", defaultValue: "Blue"), color: Color(hex: 0x2196F3)),
        CollectionColorOption(key: "lightBlue", label: String(localized: "collection.color.light_blue", defaultValue: "Light Blue"), color: Color(hex: 0x03A9F4)),
        CollectionColorOption(key: "cyan", label: String(localized: "collection.color.cyan", defaultValue: "Cyan"), color: Color(hex: 0x00BCD4)),
        CollectionColorOption(key: "teal", label: String(localized: "collection.color.teal", defaultValue: "Teal"), color: Color(hex: 0x009688)),
        CollectionColorOption(key: "green", label: String(localized: "collection.color.green", defaultValue: "Green"), color: Color(hex: 0x4CAF50)),
        CollectionColorOption(key: "lightGreen", label: String(localized: "collection.color.light_green", defaultValue: "Light Green"), color: Color(hex: 0x8BC34A)),
        CollectionColorOption(key: "lime", label: String(localized: "collection.color.lime", defaultValue: "Lime"), color: Color(hex: 0xCDDC39)),
        CollectionColorOption(key: "yellow", label: String(localized: "collection.color.yellow", defaultValue: "Yellow"), color: Color(hex: 0xFFEB3B)),
        CollectionColorOption(key: "amber", label: String(localized: "collection.color.amber", defaultValue: "Amber"), color: Color(hex: 0xFFC107)),
        CollectionColorOption(key: "orange", label: String(localized: "collection.color.orange", defaultValue: "Orange"), color: Color(hex: 0xFF9800)),
        CollectionColorOption(key: "deepOrange", label: String(localized: "collection.color.deep_orange", defaultValue: "Deep Orange"), color: Color(hex: 0xFF5722)),
        CollectionColorOption(key: "brown", label: String(localized: "collection.color.brown", defaultValue: "Brown"), color: Color(hex: 0x795548)),
        CollectionColorOption(key: "blueGrey", label: String(localized: "collection.color.blue_grey", defaultValue: "Blue Grey"), color: Color(hex: 0x607D8B)),
    ]

    private static let byKey: [String: Color] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.color) })

    /// The container color for a persisted `key`, or nil (→ fall back to the derived color).
    static func color(for key: String?) -> Color? {
        guard let key else { return nil }
        return byKey[key]
    }

    /// A stable, distinct container color derived from a collection's name, used when the
    /// collection has no explicit color key. Deterministic across launches (unlike
    /// `String.hashValue`, which is randomly seeded per process).
    static func derivedColor(for name: String, dark: Bool) -> Color {
        let hue = Double(stableHash(name) % 360) / 360.0
        return Color(hue: hue,
                     saturation: dark ? 0.40 : 0.45,
                     brightness: dark ? 0.42 : 0.92)
    }

    /// A legible foreground color (icon/letter) over `container`.
    static func foreground(on container: Color) -> Color {
        container.isLight ? Color(white: 0.11) : .white
    }

    /// djb2 — deterministic across runs so a collection always gets the same hue.
    private static func stableHash(_ string: String) -> Int {
        var hash = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return abs(hash)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }

    /// Rough perceptual lightness, used to choose a legible foreground color.
    var isLight: Bool {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}
