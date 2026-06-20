//
//  WhatsNewView.swift
//  Doughy

import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Feature {
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let features: [Feature] = [
        Feature(
            symbol: "camera.viewfinder",
            title: "On-Device AI Recipe Scanning",
            body: "Use Apple Intelligence On-Device models to photograph a recipe or scan a screenshot and create your recipe in seconds. Requires iPhone 15 or later."
        ),
        Feature(
            symbol: "flask",
            title: "Convert to Volume",
            body: "Not everything is easily weighed. Common ingredients have standard mass to volume conversions. Add your own any time."
        ),
        Feature(
            symbol: "clock.arrow.circlepath",
            title: "Recipe History",
            body: "Every edit is saved. Browse and restore past versions using the clock icon on any recipe's calculator screen."
        ),
        Feature(
            symbol: "square.and.arrow.up",
            title: "Share Recipes",
            body: "Send a recipe to another Doughy user. Include a personal note they'll see when they open it."
        ),
        Feature(
            symbol: "arrow.clockwise",
            title: "Backup & Restore",
            body: "Export your full recipe library and restore it on any device. Find it under Settings."
        ),
        Feature(
            symbol: "trash",
            title: "Recently Deleted",
            body: "Deleted recipes stay in Settings → Recently Deleted for 30 days before they're permanently removed."
        ),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(features, id: \.symbol) { feature in
                    featureRow(feature)
                }
            }
            .navigationTitle("What's New in Doughy")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
