//
//  PrefermentPreset.swift
//  Doughy
//

import Foundation

/// Starting points offered by the Add Preferment tool. Picking one seeds the
/// flour/hydration/yeast fields with typical values for that style; the user
/// can still edit every field afterward.
enum PrefermentPreset: String, CaseIterable {
    case poolish = "Poolish"
    case biga = "Biga"
    case sourdoughStarter = "Sourdough Starter"

    var defaultFlourPercentOfTotal: Double {
        switch self {
        case .poolish, .biga: return 50
        case .sourdoughStarter: return 10
        }
    }

    var defaultHydrationPercent: Double {
        switch self {
        case .poolish, .sourdoughStarter: return 100
        case .biga: return 60
        }
    }

    /// Default preferment yeast, as a percentage of the preferment's *own*
    /// flour. `nil` means the preferment carries no commercial yeast of its
    /// own - a sourdough starter replaces the recipe's yeast rather than
    /// sharing it.
    ///
    /// For poolish/biga this mirrors the recipe's actual total yeast
    /// percentage rather than a flat constant: since that percentage is
    /// relative to the *total* flour and this one is relative to just the
    /// preferment's flour, using the same number gives the preferment a
    /// share of the yeast proportional to its share of the flour - which is
    /// always safe (the preferment can never claim more yeast than the
    /// recipe has). A flat default like 0.1% would overshoot a slow-fermented,
    /// low-yeast style like Neapolitan pizza (often ~0.05% total yeast),
    /// pushing the final dough's yeast negative.
    func defaultYeastPercent(for recipe: any RecipeProtocol) -> Double? {
        switch self {
        case .poolish, .biga: return PrefermentTool.yeastIngredient(in: recipe)?.defaultPercentage ?? 0
        case .sourdoughStarter: return nil
        }
    }

    /// Whether picking this preset should remove the recipe's existing yeast
    /// ingredient entirely, since the preferment leavens the whole dough instead.
    var removesMainDoughYeast: Bool { self == .sourdoughStarter }

    static func matching(name: String) -> PrefermentPreset? {
        allCases.first { $0.rawValue.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }
}
