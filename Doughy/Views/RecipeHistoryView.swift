//
//  RecipeHistoryView.swift
//  Doughy
//

import SwiftUI

struct RecipeHistoryView: View {
    let recipe: any RecipeProtocol

    @Environment(RecipeStore.self) private var store
    @State private var entries: [HistoryEntry] = []
    @State private var restoreTarget: HistoryEntry?
    @State private var actionError: String?

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Edits and notes you save will show up here.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        row(for: entry)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshEntries()
        }
        .alert("Restore Version", isPresented: Binding(
            get: { restoreTarget != nil },
            set: { if !$0 { restoreTarget = nil } }
        )) {
            Button("Restore", role: .destructive) {
                if let entry = restoreTarget {
                    restore(entry)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Restore the recipe to this version? The current state will be saved to history first.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionError ?? "")
        }
    }

    @ViewBuilder
    private func row(for entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.text)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                delete(entry)
            }
            if case .version = entry.kind {
                Button("Restore") {
                    restoreTarget = entry
                }
                .tint(.blue)
            }
        }
    }

    private func refreshEntries() {
        entries = store.historyEntries(for: recipe)
    }

    private func delete(_ entry: HistoryEntry) {
        do {
            try store.deleteHistoryEntry(entry, from: recipe)
            refreshEntries()
        } catch {
            actionError = String(localized: "history.error.delete_entry", defaultValue: "Could not delete this history entry.")
        }
    }

    private func restore(_ entry: HistoryEntry) {
        do {
            try store.restoreVersion(entry, for: recipe)
            refreshEntries()
        } catch {
            actionError = String(localized: "history.error.restore_version", defaultValue: "Could not restore this version.")
        }
    }
}
