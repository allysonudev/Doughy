//
//  CoreDataSortedAccessors.swift
//  Doughy
//
//  Replaces NSOrderedSet-based `.array` casts that are incompatible with CloudKit.
//  Each property sorts the unordered NSSet by the `sortOrder` attribute stamped on
//  insert, preserving the user-defined ordering without relying on ordered relationships.

import Foundation

extension XCRecipe {
    var sortedIngredients: [XCIngredient] {
        (ingredients as? Set<XCIngredient> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
    var sortedInstructions: [XCInstruction] {
        (instructions as? Set<XCInstruction> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension XCPreferment {
    var sortedIngredients: [XCIngredient] {
        (ingredients as? Set<XCIngredient> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension XCCalculatedRecipe {
    var sortedIngredients: [XCCalculatedIngredient] {
        (ingredients as? Set<XCCalculatedIngredient> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
    var sortedInstructions: [XCInstruction] {
        (instructions as? Set<XCInstruction> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension XCCalculatedPreferment {
    var sortedIngredients: [XCCalculatedIngredient] {
        (ingredients as? Set<XCCalculatedIngredient> ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}
