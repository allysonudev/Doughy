//
//  CollectionAppearance.swift
//  Doughy

import Foundation

/// The visual identity of a recipe collection: a shared semantic icon key plus a
/// color key. Both are optional — an un-customized collection falls back to a
/// first-letter avatar over a color derived from its name.
///
/// Keys are *shared semantic slugs* (e.g. "pizza", "coffee"), not platform symbol
/// names, so the same value maps to an SF Symbol on iOS and a Material icon on
/// Android and round-trips through the `.doughy` file.
struct CollectionAppearance: Codable, Equatable {
    var iconKey: String?
    var colorKey: String?

    init(iconKey: String? = nil, colorKey: String? = nil) {
        self.iconKey = iconKey
        self.colorKey = colorKey
    }

    var isEmpty: Bool { iconKey == nil && colorKey == nil }

    static let none = CollectionAppearance()
}
