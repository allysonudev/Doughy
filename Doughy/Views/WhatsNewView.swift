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
            title: "whats_new_scan_title",
            body: "whats_new_scan_body"
        ),
        Feature(
            symbol: "flask",
            title: "whats_new_volume_title",
            body: "whats_new_volume_body"
        ),
        Feature(
            symbol: "clock.arrow.circlepath",
            title: "whats_new_history_title",
            body: "whats_new_history_body"
        ),
        Feature(
            symbol: "square.and.arrow.up",
            title: "whats_new_share_title",
            body: "whats_new_share_body"
        ),
        Feature(
            symbol: "arrow.clockwise",
            title: "whats_new_backup_title",
            body: "whats_new_backup_body"
        ),
        Feature(
            symbol: "trash",
            title: "whats_new_deleted_title",
            body: "whats_new_deleted_body"
        ),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(features, id: \.symbol) { feature in
                    featureRow(feature)
                }
            }
            .navigationTitle("whats_new_title")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Button("whats_new_got_it") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial)
                .accessibilityIdentifier("whatsNewGotItButton")
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
