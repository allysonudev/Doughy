//
//  CollectionAppearanceEditor.swift
//  Doughy

import SwiftUI

/// Lets the user choose a collection's icon and color, with a live avatar preview.
/// Binds to the icon/color slugs; `nil` means "use the default" — a first-letter avatar
/// for the icon, and the name-derived color for the color.
struct CollectionAppearanceEditor: View {
    /// The collection the appearance is for (drives the preview's letter/derived color).
    let collection: String
    @Binding var iconKey: String?
    @Binding var colorKey: String?

    private let swatchSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CollectionAvatar(
                    collection: collection,
                    appearanceOverride: CollectionAppearance(iconKey: iconKey, colorKey: colorKey),
                    size: 52
                )
                Text(String(localized: "collection.appearance.subtitle",
                            defaultValue: "Pick an icon and color for this collection."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            picker(title: String(localized: "collection.appearance.icon", defaultValue: "Icon")) {
                iconChoices
            }
            picker(title: String(localized: "collection.appearance.color", defaultValue: "Color")) {
                colorChoices
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func picker<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    content()
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var iconChoices: some View {
        iconButton(key: nil) {
            Image(systemName: "textformat")
                .font(.system(size: swatchSize * 0.4, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        ForEach(CollectionIconCatalog.all) { icon in
            iconButton(key: icon.key) {
                CollectionIconGlyph(glyph: icon.glyph, size: swatchSize * 0.5)
            }
        }
    }

    @ViewBuilder
    private func iconButton<Content: View>(key: String?, @ViewBuilder glyph: () -> Content) -> some View {
        Button {
            iconKey = key
        } label: {
            ZStack {
                Circle().fill(Color(.secondarySystemFill))
                glyph()
            }
            .frame(width: swatchSize, height: swatchSize)
            .overlay {
                Circle().strokeBorder(Color.accentColor, lineWidth: iconKey == key ? 3 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(iconAccessibilityLabel(key))
        .accessibilityAddTraits(iconKey == key ? .isSelected : [])
    }

    private func iconAccessibilityLabel(_ key: String?) -> String {
        guard let key, let icon = CollectionIconCatalog.icon(for: key) else {
            return String(localized: "collection.appearance.icon.none", defaultValue: "No icon")
        }
        return icon.label
    }

    // MARK: - Color

    @ViewBuilder
    private var colorChoices: some View {
        colorButton(key: nil, fill: CollectionColorCatalog.derivedColor(for: collection, dark: false))
        ForEach(CollectionColorCatalog.all) { option in
            colorButton(key: option.key, fill: option.color)
        }
    }

    @ViewBuilder
    private func colorButton(key: String?, fill: Color) -> some View {
        Button {
            colorKey = key
        } label: {
            ZStack {
                Circle().fill(fill)
                if key == nil {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: swatchSize * 0.36, weight: .semibold))
                        .foregroundStyle(CollectionColorCatalog.foreground(on: fill))
                }
            }
            .frame(width: swatchSize, height: swatchSize)
            .overlay {
                Circle().strokeBorder(Color.accentColor, lineWidth: colorKey == key ? 3 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorAccessibilityLabel(key))
        .accessibilityAddTraits(colorKey == key ? .isSelected : [])
    }

    private func colorAccessibilityLabel(_ key: String?) -> String {
        guard let key, let option = CollectionColorCatalog.all.first(where: { $0.key == key }) else {
            return String(localized: "collection.appearance.color.auto", defaultValue: "Automatic color")
        }
        return option.label
    }
}
