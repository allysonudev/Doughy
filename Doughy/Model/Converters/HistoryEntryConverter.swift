//
//  HistoryEntryConverter.swift
//  Doughy
//

import Foundation

class HistoryEntryConverter: NSObject {

    private let objectFactory = ObjectFactory.shared

    static let shared = HistoryEntryConverter()

    private override init() { }

    func convertToCoreData(entry: HistoryEntry) -> XCHistoryEntry {
        let coreData = objectFactory.createHistoryEntry()

        coreData.id = entry.id
        coreData.date = entry.date
        coreData.text = entry.text

        switch entry.kind {
        case .note:
            coreData.kind = "note"
        case .version(let snapshot):
            coreData.kind = "version"
            coreData.snapshot = try? JSONEncoder().encode(snapshot)
        }

        return coreData
    }

    func convertToExternal(entry: XCHistoryEntry) -> HistoryEntry {
        let kind: HistoryEntry.Kind
        if entry.kind == "version", let data = entry.snapshot,
           let snapshot = try? JSONDecoder().decode(RecipeSnapshot.self, from: data) {
            kind = .version(snapshot)
        } else {
            kind = .note
        }

        return HistoryEntry(id: entry.id!, date: entry.date!, kind: kind, text: entry.text!)
    }
}
