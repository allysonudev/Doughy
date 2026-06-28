//
//  CollectionAvatar.swift
//  Doughy

import SwiftUI

/// A circular avatar for a collection: its chosen icon over its chosen (or derived)
/// color, falling back to the collection's first letter when no icon is set.
///
/// Appearance is resolved from the `CollectionAppearanceStore` in the environment unless
/// an explicit `appearanceOverride` is supplied (used for the live create/edit preview).
struct CollectionAvatar: View {
    let collection: String
    var appearanceOverride: CollectionAppearance?
    var size: CGFloat = 40

    @Environment(CollectionAppearanceStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    private var appearance: CollectionAppearance {
        appearanceOverride ?? store.appearance(for: collection)
    }

    private var background: Color {
        CollectionColorCatalog.color(for: appearance.colorKey)
            ?? CollectionColorCatalog.derivedColor(for: collection, dark: colorScheme == .dark)
    }

    private var foreground: Color {
        CollectionColorCatalog.foreground(on: background)
    }

    var body: some View {
        ZStack {
            Circle().fill(background)
            iconContent
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconContent: some View {
        if let icon = CollectionIconCatalog.icon(for: appearance.iconKey) {
            CollectionIconGlyph(glyph: icon.glyph, size: size * 0.52)
                .foregroundStyle(foreground)
        } else {
            Text(firstLetter)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(foreground)
        }
    }

    private var firstLetter: String {
        let display = DefaultLocalization.collectionName(collection)
        return String(display.prefix(1)).uppercased()
    }
}

/// Renders a single collection-icon glyph (emoji, SF Symbol, or custom asset) at `size`.
/// Used by `CollectionAvatar` and the appearance picker so glyph handling stays in one place.
/// Emoji render in full color; symbol/asset glyphs inherit the surrounding `foregroundStyle`.
struct CollectionIconGlyph: View {
    let glyph: CollectionIcon.Glyph
    let size: CGFloat

    var body: some View {
        switch glyph {
        case .emoji(let value):
            Text(value).font(.system(size: size))
        case .symbol(let name):
            Image(systemName: name).font(.system(size: size, weight: .semibold))
        case .asset(let name):
            Image(name).renderingMode(.template).resizable().scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
