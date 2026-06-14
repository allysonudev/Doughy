//
//  HistoryEntry.swift
//  Doughy
//

import Foundation

/// A single entry in a recipe's history: either a free-text note, or a
/// version snapshot taken before a real edit, a "Set as Default", or a
/// restore.
struct HistoryEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case note
        case version(RecipeSnapshot)
    }

    let id: UUID
    let date: Date
    let kind: Kind
    let text: String
}
