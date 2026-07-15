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

    @Environment(CollectionAppearanceStore.self) private var appearanceStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEmojiPicker = false

    private let swatchSize: CGFloat = 40

    private var iconSwatchBackground: Color {
        CollectionColorCatalog.color(for: colorKey)
            ?? CollectionColorCatalog.derivedColor(for: collection, dark: colorScheme == .dark)
    }

    private var iconSwatchForeground: Color {
        CollectionColorCatalog.foreground(on: iconSwatchBackground)
    }

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
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("collectionAppearancePreviewAvatar")
            .accessibilityLabel(previewAccessibilityLabel)

            picker(title: String(localized: "collection.appearance.icon", defaultValue: "Icon")) {
                iconChoices
            }
            picker(title: String(localized: "collection.appearance.color", defaultValue: "Color")) {
                colorChoices
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEmojiPicker) {
            CollectionEmojiPickerSheet { emoji in
                guard let key = CollectionIconCatalog.customEmojiKey(for: emoji) else { return }
                iconKey = key
                appearanceStore.rememberEmojiIconKey(key)
                showingEmojiPicker = false
            }
            .presentationDetents([.height(320)])
        }
    }

    /// Describes the live preview avatar's current icon/color for UI testing, since the
    /// avatar itself renders as an accessibility-hidden decorative image.
    var previewAccessibilityLabel: String {
        "icon:\(iconKey ?? "none"), color:\(colorKey ?? "none")"
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
        }
        ForEach(recentEmojiIcons) { icon in
            iconButton(key: icon.key) {
                CollectionIconGlyph(glyph: icon.glyph, size: swatchSize * 0.5)
            }
        }
        ForEach(CollectionIconCatalog.all) { icon in
            iconButton(key: icon.key) {
                CollectionIconGlyph(glyph: icon.glyph, size: swatchSize * 0.5)
            }
        }
        searchEmojiButton
    }

    private var recentEmojiIcons: [CollectionIcon] {
        var keys = appearanceStore.recentEmojiIconKeys
        if let iconKey,
           CollectionIconCatalog.customEmoji(from: iconKey) != nil,
           !keys.contains(iconKey) {
            keys.insert(iconKey, at: 0)
        }
        return keys.compactMap { CollectionIconCatalog.icon(for: $0) }
    }

    private var searchEmojiButton: some View {
        Button {
            showingEmojiPicker = true
        } label: {
            ZStack {
                Circle().fill(iconSwatchBackground)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: swatchSize * 0.38, weight: .semibold))
                    .foregroundStyle(iconSwatchForeground)
            }
            .frame(width: swatchSize, height: swatchSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "collection.appearance.icon.search_emoji", defaultValue: "Search emoji"))
    }

    @ViewBuilder
    private func iconButton<Content: View>(key: String?, @ViewBuilder glyph: () -> Content) -> some View {
        Button {
            iconKey = key
        } label: {
            ZStack {
                Circle().fill(iconSwatchBackground)
                glyph()
                    .foregroundStyle(iconSwatchForeground)
            }
            .frame(width: swatchSize, height: swatchSize)
            .overlay {
                Circle().strokeBorder(Color.accentColor, lineWidth: iconKey == key ? 3 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collectionIconOption_\(key ?? "none")")
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
        .accessibilityIdentifier("collectionColorOption_\(key ?? "none")")
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

private struct CollectionEmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmojiFieldFocused: Bool
    @State private var emojiText = ""

    let onSelect: (String) -> Void

    private var selectedEmoji: String? {
        CollectionIconCatalog.normalizedCustomEmoji(emojiText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color(.secondarySystemFill))
                    if let selectedEmoji {
                        Text(selectedEmoji)
                            .font(.system(size: 44))
                    } else {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 78, height: 78)

                TextField("", text: $emojiText)
                    .font(.system(size: 34))
                    .multilineTextAlignment(.center)
                    .focused($isEmojiFieldFocused)
                    .keyboardType(.emoji ?? .default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
                    }
                    .accessibilityIdentifier("collectionEmojiField")
                    .onChange(of: emojiText) { oldValue, newValue in
                        let replacement = replacementText(oldValue: oldValue, newValue: newValue)
                        guard replacement != newValue else { return }
                        emojiText = replacement
                    }

                if !emojiText.isEmpty && selectedEmoji == nil {
                    Text(String(localized: "collection.appearance.icon.invalid_emoji", defaultValue: "Choose one emoji."))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    guard let selectedEmoji else { return }
                    onSelect(selectedEmoji)
                } label: {
                    Text(String(localized: "collection.appearance.icon.use_emoji", defaultValue: "Use Emoji"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedEmoji == nil)
                .accessibilityIdentifier("collectionUseEmojiButton")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .navigationTitle(String(localized: "collection.appearance.icon.emoji", defaultValue: "Emoji"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isEmojiFieldFocused = true
                }
            }
        }
    }

    private func replacementText(oldValue: String, newValue: String) -> String {
        guard newValue.count > 1 else {
            return CollectionIconCatalog.normalizedCustomEmoji(newValue) ?? newValue
        }

        let enteredText: String
        if !oldValue.isEmpty, newValue.hasPrefix(oldValue) {
            enteredText = String(newValue.dropFirst(oldValue.count))
        } else if !oldValue.isEmpty, newValue.hasSuffix(oldValue) {
            enteredText = String(newValue.dropLast(oldValue.count))
        } else {
            enteredText = newValue
        }

        if let emoji = lastEmoji(in: enteredText) ?? lastEmoji(in: newValue) {
            return emoji
        }
        return enteredText.last.map(String.init) ?? newValue.last.map(String.init) ?? ""
    }

    private func lastEmoji(in text: String) -> String? {
        for character in text.reversed() {
            if let emoji = CollectionIconCatalog.normalizedCustomEmoji(String(character)) {
                return emoji
            }
        }
        return nil
    }
}

extension UIKeyboardType {
    static let emoji = UIKeyboardType(rawValue: 124)
}
