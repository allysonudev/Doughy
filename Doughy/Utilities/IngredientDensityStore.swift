//
//  IngredientDensityStore.swift
//  Doughy
//

import Foundation

/// Groups `IngredientCategory` cases for display in the conversions settings screen.
enum IngredientCategoryGroup: String, CaseIterable {
    case flours = "Flours"
    case sweeteners = "Sweeteners"
    case fatsAndOils = "Fats & Oils"
    case dairy = "Dairy"
    case leaveningAndStarters = "Leavening & Starters"
    case salts = "Salt"
    case other = "Other"
}

/// A unit of volume an ingredient's density can be expressed/edited in. Densities are
/// always stored canonically as grams-per-cup; this is purely a display preference.
enum DensityUnit: String, CaseIterable, Identifiable {
    case cup
    case milliliter
    case tablespoon
    case teaspoon

    var id: String { rawValue }

    /// How many of this unit make up one US cup, used to convert to/from the
    /// canonical grams-per-cup storage.
    var unitsPerCup: Double {
        switch self {
        case .cup: return 1
        case .tablespoon: return 16
        case .teaspoon: return 48
        case .milliliter: return 236.588
        }
    }

    var label: String {
        switch self {
        case .cup: return "g/cup"
        case .tablespoon: return "g/tbsp"
        case .teaspoon: return "g/tsp"
        case .milliliter: return "g/ml"
        }
    }
}

/// Which part of an egg a quantity refers to: the whole egg (in its shell), or just
/// the separated white or yolk.
enum EggPart: String, CaseIterable, Identifiable {
    case whole
    case white
    case yolk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whole: return "Whole Egg"
        case .white: return "Egg White"
        case .yolk: return "Egg Yolk"
        }
    }
}

/// A standard US egg size, used to convert an "X eggs"/"X egg whites"/"X egg yolks"
/// quantity to grams. Unlike other ingredients, eggs are measured by count rather
/// than volume, so they get their own per-egg weights instead of a grams-per-cup
/// density.
enum EggSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge
    case jumbo

    var id: String { rawValue }

    /// Approximate weight of one whole egg out of its shell (white plus yolk), in grams — the
    /// usable weight a recipe actually calls for.
    var gramsPerEgg: Double {
        switch self {
        case .small: return 38
        case .medium: return 44
        case .large: return 50
        case .extraLarge: return 56
        case .jumbo: return 62
        }
    }

    /// Approximate weight of one separated egg white, in grams — roughly two-thirds of the egg's
    /// out-of-shell weight. Actual white/yolk weights vary more than whole-egg weights, since
    /// separating an egg isn't an exact science.
    var gramsPerEggWhite: Double {
        switch self {
        case .small: return 25
        case .medium: return 29
        case .large: return 33
        case .extraLarge: return 37
        case .jumbo: return 41
        }
    }

    /// Approximate weight of one separated egg yolk, in grams — roughly a third of the egg's
    /// out-of-shell weight.
    var gramsPerEggYolk: Double {
        switch self {
        case .small: return 13
        case .medium: return 15
        case .large: return 17
        case .extraLarge: return 19
        case .jumbo: return 21
        }
    }

    /// The default weight, in grams, for `part` of this egg size.
    func defaultGrams(for part: EggPart) -> Double {
        switch part {
        case .whole: return gramsPerEgg
        case .white: return gramsPerEggWhite
        case .yolk: return gramsPerEggYolk
        }
    }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        case .jumbo: return "Jumbo"
        }
    }
}

/// A closed set of common baking ingredients with known densities, used to convert
/// volume measurements (cups/tablespoons/teaspoons) to grams. Mirrors
/// `ParsedIngredientCategory` in RecipeScanner.swift (same raw values), but is
/// available everywhere - including below iOS 26, where the scanner's
/// FoundationModels-backed enum doesn't exist.
enum IngredientCategory: String, CaseIterable, Identifiable {
    // Flours
    case breadFlour
    case allPurposeFlour
    case cakeFlour
    case wholeWheatFlour
    case ryeFlour
    case speltFlour
    case semolinaFlour
    case oatFlour
    case cornmeal
    case riceFlour
    case almondFlour
    case buckwheatFlour
    case glutenFreeFlourBlend

    // Sweeteners
    case granulatedSugar
    case brownSugar
    case powderedSugar
    case honey
    case mapleSyrup
    case molasses

    // Fats and oils
    case butter
    case oliveOil
    case vegetableOil
    case coconutOil
    case shortening

    // Dairy
    case milk
    case buttermilk
    case yogurt
    case cream
    case sourCream

    // Leavening and starters
    case instantYeast
    case activeDryYeast
    case freshYeast
    case sourdoughStarter
    case bakingPowder
    case bakingSoda

    // Salt
    case tableSalt
    case kosherSalt
    case seaSalt

    // Other
    case water
    case seeds
    case nuts
    case spices
    case cocoaPowder
    case chocolateChips

    var id: String { rawValue }

    var group: IngredientCategoryGroup {
        switch self {
        case .breadFlour, .allPurposeFlour, .cakeFlour, .wholeWheatFlour, .ryeFlour,
             .speltFlour, .semolinaFlour, .oatFlour, .cornmeal, .riceFlour, .almondFlour,
             .buckwheatFlour, .glutenFreeFlourBlend:
            return .flours
        case .granulatedSugar, .brownSugar, .powderedSugar, .honey, .mapleSyrup, .molasses:
            return .sweeteners
        case .butter, .oliveOil, .vegetableOil, .coconutOil, .shortening:
            return .fatsAndOils
        case .milk, .buttermilk, .yogurt, .cream, .sourCream:
            return .dairy
        case .instantYeast, .activeDryYeast, .freshYeast, .sourdoughStarter, .bakingPowder, .bakingSoda:
            return .leaveningAndStarters
        case .tableSalt, .kosherSalt, .seaSalt:
            return .salts
        case .water, .seeds, .nuts, .spices, .cocoaPowder, .chocolateChips:
            return .other
        }
    }

    var displayName: String {
        switch self {
        case .breadFlour: return "Bread Flour"
        case .allPurposeFlour: return "All-Purpose Flour"
        case .cakeFlour: return "Cake Flour"
        case .wholeWheatFlour: return "Whole Wheat Flour"
        case .ryeFlour: return "Rye Flour"
        case .speltFlour: return "Spelt Flour"
        case .semolinaFlour: return "Semolina Flour"
        case .oatFlour: return "Oat Flour"
        case .cornmeal: return "Cornmeal"
        case .riceFlour: return "Rice Flour"
        case .almondFlour: return "Almond Flour"
        case .buckwheatFlour: return "Buckwheat Flour"
        case .glutenFreeFlourBlend: return "Gluten-Free Flour Blend"

        case .granulatedSugar: return "Granulated Sugar"
        case .brownSugar: return "Brown Sugar"
        case .powderedSugar: return "Powdered Sugar"
        case .honey: return "Honey"
        case .mapleSyrup: return "Maple Syrup"
        case .molasses: return "Molasses"

        case .butter: return "Butter"
        case .oliveOil: return "Olive Oil"
        case .vegetableOil: return "Vegetable Oil"
        case .coconutOil: return "Coconut Oil"
        case .shortening: return "Shortening"

        case .milk: return "Milk"
        case .buttermilk: return "Buttermilk"
        case .yogurt: return "Yogurt"
        case .cream: return "Cream"
        case .sourCream: return "Sour Cream"

        case .instantYeast: return "Instant Yeast"
        case .activeDryYeast: return "Active Dry Yeast"
        case .freshYeast: return "Fresh Yeast"
        case .sourdoughStarter: return "Sourdough Starter"
        case .bakingPowder: return "Baking Powder"
        case .bakingSoda: return "Baking Soda"

        case .tableSalt: return "Table Salt"
        case .kosherSalt: return "Kosher Salt"
        case .seaSalt: return "Sea Salt"

        case .water: return "Water"
        case .seeds: return "Seeds"
        case .nuts: return "Nuts"
        case .spices: return "Spices"
        case .cocoaPowder: return "Cocoa Powder"
        case .chocolateChips: return "Chocolate Chips"
        }
    }

    /// Approximate grams per US cup, used as the starting point for
    /// `IngredientDensityStore` before any user customization. Sourced from King
    /// Arthur Baking's ingredient weight chart
    /// (kingarthurbaking.com/learn/ingredient-weight-chart) where available.
    var defaultGramsPerCup: Double {
        switch self {
        case .breadFlour: return 120
        case .allPurposeFlour: return 120
        case .cakeFlour: return 120
        case .wholeWheatFlour: return 113
        case .ryeFlour: return 106
        case .speltFlour: return 99
        case .semolinaFlour: return 163
        case .oatFlour: return 92
        case .cornmeal: return 138
        case .riceFlour: return 142
        case .almondFlour: return 96
        case .buckwheatFlour: return 120
        case .glutenFreeFlourBlend: return 156

        case .granulatedSugar: return 198
        case .brownSugar: return 213
        case .powderedSugar: return 113
        case .honey: return 336 // 21g/tbsp
        case .mapleSyrup: return 312
        case .molasses: return 340

        case .butter: return 226
        case .oliveOil: return 200
        case .vegetableOil: return 198
        case .coconutOil: return 226
        case .shortening: return 184

        case .milk: return 227
        case .buttermilk: return 227
        case .yogurt: return 227
        case .cream: return 227
        case .sourCream: return 227

        case .instantYeast: return 144 // 3g/tsp
        case .activeDryYeast: return 144 // same as instant yeast
        case .freshYeast: return 144 // same as instant yeast
        case .sourdoughStarter: return 234
        case .bakingPowder: return 192 // 4g/tsp
        case .bakingSoda: return 288 // 6g/tsp

        case .tableSalt: return 288 // 6g/tsp
        case .kosherSalt: return 256 // ~5.3g/tsp (Morton's)
        case .seaSalt: return 240 // 5g/tsp

        case .water: return 227
        case .seeds: return 160
        case .nuts: return 120
        case .spices: return 100
        case .cocoaPowder: return 84
        case .chocolateChips: return 170
        }
    }

    /// The unit each ingredient's density is most naturally expressed in (e.g. yeast
    /// and leaveners by the teaspoon, salts by the teaspoon per the user's
    /// preference, honey by the tablespoon per King Arthur's chart). Used to seed
    /// `IngredientDensityStore`'s display unit before the user picks one explicitly.
    var defaultDisplayUnit: DensityUnit {
        switch self {
        case .instantYeast, .activeDryYeast, .freshYeast, .bakingPowder, .bakingSoda,
             .tableSalt, .kosherSalt, .seaSalt:
            return .teaspoon
        case .honey:
            return .tablespoon
        default:
            return .cup
        }
    }
}

/// Persists user-adjusted grams-per-cup conversions for each `IngredientCategory`,
/// falling back to `IngredientCategory.defaultGramsPerCup` until the user changes
/// one. Used by the recipe scanner to convert volume measurements to grams, and
/// editable from Settings since ingredient density varies with humidity, how an
/// ingredient is measured, etc.
class IngredientDensityStore: NSObject {

    static let shared = IngredientDensityStore()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "ingredientDensityStoreKey"
    private let displayUnitStorageKey = "ingredientDensityDisplayUnitStoreKey"
    private let eggOverridesStorageKey = "ingredientDensityEggOverridesKey"
    private let defaultEggSizeStorageKey = "ingredientDensityDefaultEggSizeKey"

    private override init() { super.init() }

    private var overrides: [String: Double] {
        get { userDefaults.dictionary(forKey: storageKey) as? [String: Double] ?? [:] }
        set { userDefaults.set(newValue, forKey: storageKey) }
    }

    private var displayUnits: [String: String] {
        get { userDefaults.dictionary(forKey: displayUnitStorageKey) as? [String: String] ?? [:] }
        set { userDefaults.set(newValue, forKey: displayUnitStorageKey) }
    }

    private var eggOverrides: [String: Double] {
        get { userDefaults.dictionary(forKey: eggOverridesStorageKey) as? [String: Double] ?? [:] }
        set { userDefaults.set(newValue, forKey: eggOverridesStorageKey) }
    }

    /// Returns the unit `category`'s density should be displayed/edited in, defaulting
    /// to `category.defaultDisplayUnit`.
    func displayUnit(for category: IngredientCategory) -> DensityUnit {
        displayUnits[category.rawValue].flatMap(DensityUnit.init(rawValue:)) ?? category.defaultDisplayUnit
    }

    /// Remembers the unit `category`'s density should be displayed/edited in.
    func setDisplayUnit(_ unit: DensityUnit, for category: IngredientCategory) {
        var current = displayUnits
        current[category.rawValue] = unit.rawValue
        displayUnits = current
    }

    /// Returns the grams-per-cup value to use for `category`: the user's override if
    /// they've set one, otherwise `category.defaultGramsPerCup`.
    func gramsPerCup(for category: IngredientCategory) -> Double {
        overrides[category.rawValue] ?? category.defaultGramsPerCup
    }

    /// Returns whether the user has customized `category`'s grams-per-cup value.
    func isCustomized(_ category: IngredientCategory) -> Bool {
        overrides[category.rawValue] != nil
    }

    /// Saves a user-provided grams-per-cup value for `category`.
    func setGramsPerCup(_ value: Double, for category: IngredientCategory) {
        var current = overrides
        current[category.rawValue] = value
        overrides = current
    }

    /// Removes the user's override for `category`, reverting to its default.
    func resetToDefault(for category: IngredientCategory) {
        var current = overrides
        current.removeValue(forKey: category.rawValue)
        overrides = current
    }

    /// Removes all user overrides, reverting every category and egg size to its default.
    func resetAllToDefaults() {
        overrides = [:]
        eggOverrides = [:]
    }

    private func eggOverrideKey(_ size: EggSize, _ part: EggPart) -> String {
        "\(size.rawValue)_\(part.rawValue)"
    }

    /// Returns the weight of `part` of one egg of `size`, in grams: the user's
    /// override if they've set one, otherwise `size.defaultGrams(for: part)`.
    func gramsPerEgg(for size: EggSize, part: EggPart = .whole) -> Double {
        eggOverrides[eggOverrideKey(size, part)] ?? size.defaultGrams(for: part)
    }

    /// Returns whether the user has customized `part` of `size`'s weight.
    func isCustomized(_ size: EggSize, part: EggPart = .whole) -> Bool {
        eggOverrides[eggOverrideKey(size, part)] != nil
    }

    /// Saves a user-provided weight, in grams, for `part` of one egg of `size`.
    func setGramsPerEgg(_ value: Double, for size: EggSize, part: EggPart = .whole) {
        var current = eggOverrides
        current[eggOverrideKey(size, part)] = value
        eggOverrides = current
    }

    /// Removes the user's override for `part` of `size`, reverting to its default weight.
    func resetToDefault(for size: EggSize, part: EggPart = .whole) {
        var current = eggOverrides
        current.removeValue(forKey: eggOverrideKey(size, part))
        eggOverrides = current
    }

    /// Returns the egg size to assume when a recipe gives an egg quantity with no
    /// size word (e.g. "3 eggs"), defaulting to large.
    func defaultEggSize() -> EggSize {
        userDefaults.string(forKey: defaultEggSizeStorageKey).flatMap(EggSize.init(rawValue:)) ?? .large
    }

    /// Remembers the egg size to assume when a recipe gives an egg quantity with no
    /// size word.
    func setDefaultEggSize(_ size: EggSize) {
        userDefaults.set(size.rawValue, forKey: defaultEggSizeStorageKey)
    }
}
