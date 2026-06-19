//
//  IngredientDensityStore.swift
//  Doughy
//

import Foundation

/// Groups `IngredientCategory` cases for display in the conversions settings screen.
enum IngredientCategoryGroup: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case flours = "Flours"
    case sweeteners = "Sweeteners"
    case fatsAndOils = "Fats & Oils"
    case dairy = "Dairy"
    case leaveningAndStarters = "Leavening & Starters"
    case salts = "Salt"
    case other = "Other"

    var localizedTitle: String {
        switch self {
        case .flours: return String(localized: "density.group.flours", defaultValue: "Flours")
        case .sweeteners: return String(localized: "density.group.sweeteners", defaultValue: "Sweeteners")
        case .fatsAndOils: return String(localized: "density.group.fats_oils", defaultValue: "Fats & Oils")
        case .dairy: return String(localized: "density.group.dairy", defaultValue: "Dairy")
        case .leaveningAndStarters: return String(localized: "density.group.leavening", defaultValue: "Leavening & Starters")
        case .salts: return String(localized: "density.group.salt", defaultValue: "Salt")
        case .other: return String(localized: "density.group.other", defaultValue: "Other")
        }
    }
}

/// A unit of volume an ingredient's density can be expressed/edited in. Densities are
/// always stored canonically as grams-per-cup; this is purely a display preference.
enum DensityUnit: String, CaseIterable, Identifiable {
    case cup
    case deciliter
    case liter
    case milliliter
    case tablespoon
    case teaspoon

    var id: String { rawValue }

    /// How many of this unit make up one US cup, used to convert to/from the
    /// canonical grams-per-cup storage.
    var unitsPerCup: Double {
        switch self {
        case .cup:        return 1
        case .tablespoon: return 16
        case .teaspoon:   return 48
        case .milliliter: return 236.588
        case .deciliter:  return 2.36588
        case .liter:      return 0.236588
        }
    }

    var label: String {
        switch self {
        case .cup:        return "g/cup"
        case .tablespoon: return "g/tbsp"
        case .teaspoon:   return "g/tsp"
        case .milliliter: return "g/ml"
        case .deciliter:  return "g/dl"
        case .liter:      return "g/l"
        }
    }

    var localizedLabel: String {
        switch self {
        case .cup:        return String(localized: "density.unit.cup",        defaultValue: "g/cup")
        case .tablespoon: return String(localized: "density.unit.tablespoon",  defaultValue: "g/tbsp")
        case .teaspoon:   return String(localized: "density.unit.teaspoon",    defaultValue: "g/tsp")
        case .milliliter: return String(localized: "density.unit.milliliter",  defaultValue: "g/ml")
        case .deciliter:  return String(localized: "density.unit.deciliter",   defaultValue: "g/dl")
        case .liter:      return String(localized: "density.unit.liter",       defaultValue: "g/l")
        }
    }

    /// Maps a category's natural display unit to the closest equivalent for the given
    /// volume system. Used when the user hasn't explicitly saved a unit for a category.
    static func systemDefault(for natural: DensityUnit, in system: VolumeSystem) -> DensityUnit {
        switch system {
        case .imperial:
            switch natural {
            case .cup, .tablespoon, .teaspoon: return natural
            case .deciliter, .liter:           return .cup
            case .milliliter:                  return .teaspoon
            }
        case .metric:
            switch natural {
            case .deciliter, .liter, .milliliter: return natural
            case .cup:                            return .deciliter
            case .tablespoon, .teaspoon:          return .milliliter
            }
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

    var localizedDisplayName: String {
        switch self {
        case .whole: return String(localized: "egg.part.whole", defaultValue: "Whole Egg")
        case .white: return String(localized: "egg.part.white", defaultValue: "Egg White")
        case .yolk: return String(localized: "egg.part.yolk", defaultValue: "Egg Yolk")
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

    var localizedDisplayName: String {
        switch self {
        case .small: return String(localized: "egg.size.small", defaultValue: "Small")
        case .medium: return String(localized: "egg.size.medium", defaultValue: "Medium")
        case .large: return String(localized: "egg.size.large", defaultValue: "Large")
        case .extraLarge: return String(localized: "egg.size.extra_large", defaultValue: "Extra Large")
        case .jumbo: return String(localized: "egg.size.jumbo", defaultValue: "Jumbo")
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
    case mortonKosherSalt
    case diamondCrystalKosherSalt
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
        case .tableSalt, .mortonKosherSalt, .diamondCrystalKosherSalt, .seaSalt:
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
        case .mortonKosherSalt: return "Morton Kosher Salt"
        case .diamondCrystalKosherSalt: return "Diamond Crystal Kosher Salt"
        case .seaSalt: return "Sea Salt"

        case .water: return "Water"
        case .seeds: return "Seeds"
        case .nuts: return "Nuts"
        case .spices: return "Spices"
        case .cocoaPowder: return "Cocoa Powder"
        case .chocolateChips: return "Chocolate Chips"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .breadFlour: return String(localized: "density.ingredient.bread_flour", defaultValue: "Bread Flour")
        case .allPurposeFlour: return String(localized: "density.ingredient.all_purpose_flour", defaultValue: "All-Purpose Flour")
        case .cakeFlour: return String(localized: "density.ingredient.cake_flour", defaultValue: "Cake Flour")
        case .wholeWheatFlour: return String(localized: "density.ingredient.whole_wheat_flour", defaultValue: "Whole Wheat Flour")
        case .ryeFlour: return String(localized: "density.ingredient.rye_flour", defaultValue: "Rye Flour")
        case .speltFlour: return String(localized: "density.ingredient.spelt_flour", defaultValue: "Spelt Flour")
        case .semolinaFlour: return String(localized: "density.ingredient.semolina_flour", defaultValue: "Semolina Flour")
        case .oatFlour: return String(localized: "density.ingredient.oat_flour", defaultValue: "Oat Flour")
        case .cornmeal: return String(localized: "density.ingredient.cornmeal", defaultValue: "Cornmeal")
        case .riceFlour: return String(localized: "density.ingredient.rice_flour", defaultValue: "Rice Flour")
        case .almondFlour: return String(localized: "density.ingredient.almond_flour", defaultValue: "Almond Flour")
        case .buckwheatFlour: return String(localized: "density.ingredient.buckwheat_flour", defaultValue: "Buckwheat Flour")
        case .glutenFreeFlourBlend: return String(localized: "density.ingredient.gluten_free_flour_blend", defaultValue: "Gluten-Free Flour Blend")

        case .granulatedSugar: return String(localized: "density.ingredient.granulated_sugar", defaultValue: "Granulated Sugar")
        case .brownSugar: return String(localized: "density.ingredient.brown_sugar", defaultValue: "Brown Sugar")
        case .powderedSugar: return String(localized: "density.ingredient.powdered_sugar", defaultValue: "Powdered Sugar")
        case .honey: return String(localized: "density.ingredient.honey", defaultValue: "Honey")
        case .mapleSyrup: return String(localized: "density.ingredient.maple_syrup", defaultValue: "Maple Syrup")
        case .molasses: return String(localized: "density.ingredient.molasses", defaultValue: "Molasses")

        case .butter: return String(localized: "density.ingredient.butter", defaultValue: "Butter")
        case .oliveOil: return String(localized: "density.ingredient.olive_oil", defaultValue: "Olive Oil")
        case .vegetableOil: return String(localized: "density.ingredient.vegetable_oil", defaultValue: "Vegetable Oil")
        case .coconutOil: return String(localized: "density.ingredient.coconut_oil", defaultValue: "Coconut Oil")
        case .shortening: return String(localized: "density.ingredient.shortening", defaultValue: "Shortening")

        case .milk: return String(localized: "density.ingredient.milk", defaultValue: "Milk")
        case .buttermilk: return String(localized: "density.ingredient.buttermilk", defaultValue: "Buttermilk")
        case .yogurt: return String(localized: "density.ingredient.yogurt", defaultValue: "Yogurt")
        case .cream: return String(localized: "density.ingredient.cream", defaultValue: "Cream")
        case .sourCream: return String(localized: "density.ingredient.sour_cream", defaultValue: "Sour Cream")

        case .instantYeast: return String(localized: "density.ingredient.instant_yeast", defaultValue: "Instant Yeast")
        case .activeDryYeast: return String(localized: "density.ingredient.active_dry_yeast", defaultValue: "Active Dry Yeast")
        case .freshYeast: return String(localized: "density.ingredient.fresh_yeast", defaultValue: "Fresh Yeast")
        case .sourdoughStarter: return String(localized: "density.ingredient.sourdough_starter", defaultValue: "Sourdough Starter")
        case .bakingPowder: return String(localized: "density.ingredient.baking_powder", defaultValue: "Baking Powder")
        case .bakingSoda: return String(localized: "density.ingredient.baking_soda", defaultValue: "Baking Soda")

        case .tableSalt: return String(localized: "density.ingredient.table_salt", defaultValue: "Table Salt")
        case .mortonKosherSalt: return String(localized: "density.ingredient.morton_kosher_salt", defaultValue: "Morton Kosher Salt")
        case .diamondCrystalKosherSalt: return String(localized: "density.ingredient.diamond_crystal_kosher_salt", defaultValue: "Diamond Crystal Kosher Salt")
        case .seaSalt: return String(localized: "density.ingredient.sea_salt", defaultValue: "Sea Salt")

        case .water: return String(localized: "density.ingredient.water", defaultValue: "Water")
        case .seeds: return String(localized: "density.ingredient.seeds", defaultValue: "Seeds")
        case .nuts: return String(localized: "density.ingredient.nuts", defaultValue: "Nuts")
        case .spices: return String(localized: "density.ingredient.spices", defaultValue: "Spices")
        case .cocoaPowder: return String(localized: "density.ingredient.cocoa_powder", defaultValue: "Cocoa Powder")
        case .chocolateChips: return String(localized: "density.ingredient.chocolate_chips", defaultValue: "Chocolate Chips")
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
        case .honey: return 340
        case .mapleSyrup: return 322
        case .molasses: return 340

        case .butter: return 227
        case .oliveOil: return 216
        case .vegetableOil: return 218
        case .coconutOil: return 218
        case .shortening: return 205

        case .milk: return 240
        case .buttermilk: return 245
        case .yogurt: return 245
        case .cream: return 240
        case .sourCream: return 240

        case .instantYeast: return 144 // 3g/tsp
        case .activeDryYeast: return 144 // same as instant yeast
        case .freshYeast: return 180 // denser/moister than dry yeast
        case .sourdoughStarter: return 240
        case .bakingPowder: return 192 // 4g/tsp
        case .bakingSoda: return 288 // 6g/tsp

        case .tableSalt: return 288 // 6g/tsp
        case .mortonKosherSalt: return 240 // ~5g/tsp
        case .diamondCrystalKosherSalt: return 140 // ~2.9g/tsp (much fluffier than Morton's)
        case .seaSalt: return 240 // 5g/tsp

        case .water: return 236
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
             .tableSalt, .mortonKosherSalt, .diamondCrystalKosherSalt, .seaSalt:
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
    private let hiddenCategoriesKey = "ingredientDensityHiddenCategoriesKey"

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

    /// Returns the unit `category`'s density should be displayed/edited in. If the user
    /// has saved an explicit choice it is always honoured; otherwise falls back to the
    /// system-appropriate equivalent of the category's natural unit.
    func displayUnit(for category: IngredientCategory) -> DensityUnit {
        if let stored = displayUnits[category.rawValue].flatMap(DensityUnit.init(rawValue:)) {
            return stored
        }
        return DensityUnit.systemDefault(for: category.defaultDisplayUnit,
                                        in: Settings.shared.preferredVolumeSystem())
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

    /// Removes all user overrides, reverting every category and egg size to its default,
    /// and restores any hidden categories.
    func resetAllToDefaults() {
        overrides = [:]
        eggOverrides = [:]
        userDefaults.removeObject(forKey: hiddenCategoriesKey)
    }

    /// Returns the set of categories the user has hidden from the conversions list.
    func hiddenCategories() -> Set<IngredientCategory> {
        let raw = userDefaults.array(forKey: hiddenCategoriesKey) as? [String] ?? []
        return Set(raw.compactMap(IngredientCategory.init(rawValue:)))
    }

    /// Hides `category` from the conversions list.
    func hide(category: IngredientCategory) {
        var current = hiddenCategories()
        current.insert(category)
        userDefaults.set(current.map(\.rawValue), forKey: hiddenCategoriesKey)
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
