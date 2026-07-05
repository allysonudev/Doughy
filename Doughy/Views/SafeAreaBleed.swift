//
//  SafeAreaBleed.swift
//  Doughy
//
//  iPadOS 26 doesn't reliably auto-extend `.background(_:)` colors past the bottom
//  safe area, which leaves a hairline of window background at the screen edge on
//  full-height tablet layouts. SwiftUI has no base view to override, so these helpers
//  name the three recurring cases instead of hand-rolling `.ignoresSafeArea` per site:
//
//  - `paneBackground`: a full-height pane's surface keeps painting under the home
//    indicator while the pane's content stays inside the safe area.
//  - `scrollsUnderHomeIndicator`: a full-height *scrollable* column (Form/List)
//    extends to the physical bottom; UIKit re-applies the inset as scroll padding,
//    so rows bleed under the home indicator instead of cutting off at the safe-area
//    line, and the last row can still scroll clear of it.
//  - `PaneDivider`: a vertical divider between full-height panes that runs to the
//    physical bottom edge instead of stopping 20pt short.
//
//  Fixed interactive content (buttons, action bars) should use none of these — it
//  belongs inside the safe area. And note `.clipped()` clips to safe-area bounds,
//  so it must come BEFORE the background, or the bleed gets cut off again.

import SwiftUI

extension View {
    /// Paints `color` behind the view and lets it continue under the bottom safe area.
    func paneBackground(_ color: Color) -> some View {
        background { color.ignoresSafeArea(.container, edges: .bottom) }
    }

    /// Like `paneBackground(_:)`, for non-color surfaces such as glass/material layers.
    func paneBackground<Background: View>(@ViewBuilder _ content: () -> Background) -> some View {
        background { content().ignoresSafeArea(.container, edges: .bottom) }
    }

    /// For full-height scrollable columns: extends the column to the physical bottom
    /// so its scroll content can bleed under the home indicator.
    func scrollsUnderHomeIndicator() -> some View {
        ignoresSafeArea(.container, edges: .bottom)
    }
}

/// A vertical divider between full-height panes that continues to the physical bottom edge.
struct PaneDivider: View {
    var body: some View {
        Divider()
            .ignoresSafeArea(.container, edges: .bottom)
    }
}
