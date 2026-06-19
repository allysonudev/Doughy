//
//  RecipeScannerTests.swift
//  Doughy Tests
//

import XCTest
import UIKit
@testable import Doughy

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Runs `RecipeScanner` against a folder of real recipe screenshots (see "Recipes" test
/// resource folder) and prints the resolved recipe for each, so results can be eyeballed
/// for regressions after prompt/scanner changes. Requires Apple Intelligence to be
/// available (skips otherwise) since the scanner relies on FoundationModels.
final class RecipeScannerTests: XCTestCase {

    private static let recipeFileNames = [
        "cinnamon_rolls_grams",
        "bread_machine_cups",
        "cinnamon_rolls_cups",
        "partial_recipe",
        "vodka_pizza_sauce",
        "rye_bread_honey_butter",
        "no_knead_bread_grams",
        "pizza_dough_biga",
        "uk_bread_grams",
        "uk_scones",
        "nyt_chocolate_chip_cookies",
        "brown_butter_chocolate_chip_cookies",
        "brownies_cocoa",
        "brownies_chocolate",
    ]

    /// What we expect `RecipeScanner` to produce for each fixture, hand-derived from the
    /// recipe text. Not asserted (model output varies run to run) — printed alongside the
    /// actual result so a human can eyeball whether scanning + resolution is on track.
    /// Grams shown are either taken directly from the recipe text (when given) or computed
    /// via the same cup/tablespoon/teaspoon/ounce density table the scanner uses.
    private static let expectedSummaries: [String: String] = [
        "cinnamon_rolls_grams": """
            Flour: 545g all-purpose flour (100%, exact).
            Dough: whole milk ~243g by default (240ml milk with the default US-cup \
            basis), water 60g (60ml), granulated \
            sugar 50g, active dry yeast 7g, butter 42g, kosher salt 7g, egg as an \
            extra count (no weight given).
            To assemble: granulated sugar 265g, ground cinnamon 6g (explicit grams win \
            over the teaspoon amount), butter 113g.
            Brown sugar drizzle: butter 113g, light brown sugar 150g (5oz).
            """,
        "bread_machine_cups": """
            Flour: 300g all-purpose flour (2.5 cups @120g/cup) (100%, estimated).
            Active dry yeast ~7.1g (1/4 oz, exact), salt ~1.5g (1/4 tsp), warm water \
            ~236.6g (1 cup), olive oil ~10.1g (1/2-1 tbsp, midpoint 0.75 tbsp).
            """,
        "cinnamon_rolls_cups": """
            Flour: 480g all-purpose flour (4 cups @120g/cup) (100%, estimated).
            Dough: active dry yeast 7g (1 package), water \
            ~236.6g (1 cup), sugar 99g (1/2 cup), margarine/butter ~170g (3/4 cup, mapped \
            to butter), eggs as extra counts, salt 6g (1 tsp), vegetable oil ~13.6g (1 tbsp).
            Filling: dark brown sugar ~106.5g (1/2 cup), butter ~57g (1/4 cup); ground \
            cinnamon (2 tbsp), grated orange zest (1 tbsp), golden raisins (1/2 cup), and \
            chopped walnuts (1/2 cup) all have only volume amounts in low-confidence \
            categories with no learned conversion, so expect each flagged "extra" in its \
            original unit.
            Glaze: water ~59.1g (1/4 cup), confectioners' sugar 226g (2 cups, mapped to \
            powderedSugar); orange zest and egg white are extra counts.
            """,
        "partial_recipe": """
            Flour: 450g all-purpose flour (100%, exact). This crop shows the frosting, \
            filling, and dough ingredient lists, so it should parse the visible cream \
            cheese, sugars, butter, cinnamon/nutmeg extras, pecans, flour, yeast, salt, \
            baking soda, milk, and yogurt.
            """,
        "vodka_pizza_sauce": """
            This is a sauce recipe that references an external "basic New York pizza \
            dough" — no flour ingredient appears directly in this text. Expect \
            ScanError.noFlourFound (or a resolved recipe with 0g total flour).
            If ingredients are still extracted: olive oil ~27g (2 tbsp), canned tomatoes \
            ~794g (28 oz, exact ounce conversion regardless of category), heavy cream \
            240g (1 cup, mapped to cream); garlic (~4 tsp), dried oregano (1 tsp), red \
            pepper flakes (1/2 tsp), and vodka (1/3 cup) are volume-only in low-confidence \
            categories, so expect each flagged "extra". Salt/pepper should resolve to 0g, \
            mozzarella resolves from 1 pound, basil leaves are an extra count, and the \
            external pizza dough recipe reference should be skipped.
            """,
        "rye_bread_honey_butter": """
            Flour: rye flour 212g (2 cups @106g/cup) + all-purpose flour 240g (2 cups \
            @120g/cup) = 452g total (rye ~46.9%, AP ~53.1%, estimated).
            Bread: milk 360g (1.5 cups), active dry yeast ~7.1g (1/4 oz, exact), brown \
            sugar ~53.3g (1/4 cup), butter ~28.4g (2 tbsp), kosher salt 2.5g (1/2 tsp); \
            neutral oil for greasing ~0g (no quantity).
            Honey butter: honey 85g (1/4 cup); "1 stick butter" — "stick" isn't a \
            recognized unit, so expect ~0g unless the model converts it to 1/2 cup \
            (~113.5g).
            """,
        "no_knead_bread_grams": """
            Flour: 1000g white all-purpose flour (100%, exact — every quantity in this \
            recipe is given directly in grams).
            Water 720g, fine sea salt 21g, instant active dry yeast 4g.
            """,
        "pizza_dough_biga": """
            Biga (preferment): water ~532g (2 1/4 cups), yeast 4g (stated for the fresh \
            yeast option), bread/"00" pizza flour 1000g [flour, preferment] (35.3oz/1000g \
            — explicit grams win over the ounce figure).
            Dough: sea salt 22g, water 100g (1/2 cup, stated as 100g), ice water 80g \
            (1/3 cup, stated as 80g); diastatic malt powder (1 1/2 tbsp, no gram given) \
            is a low-confidence "other" ingredient with a tablespoon amount, so expect it \
            flagged "extra" 1.5 tablespoons. Flour/semolina for dusting ~0g (no quantity).
            NOTE: all 1000g of flour is in the biga/preferment with none in the main \
            dough — main-dough flour weight is 0g, which may not map cleanly onto the \
            app's "preferment % of total flour" model.
            """,
        "uk_bread_grams": """
            Flour: 500g strong white bread flour (100%, exact).
            Salt 10g, instant yeast 10g; fine semolina for dusting ~0g (no quantity).
            NOTE: this recipe has no water or other liquid at all — likely a cropped/\
            incomplete ingredient list.
            """,
        "uk_scones": """
            Flour: 500g strong white flour (100%, exact).
            Butter 80g, caster sugar 80g (mapped to granulatedSugar, exact grams given), \
            baking powder ~20g (5 tsp @192g/cup), milk ~253.6g (250ml, mapped via milk \
            density); 2 free-range eggs and the egg+salt glaze are counts with no \
            quantity, ~0g. Serving items (butter, jam, clotted cream) have no quantities, \
            ~0g / not parsed.
            """,
        "nyt_chocolate_chip_cookies": """
            Flours: cake flour ~241g (8.5oz, exact) + bread flour ~241g (8.5oz, exact) = \
            ~482g total (each ~50.0%).
            Baking soda ~5.7g (1 1/4 tsp @220g/cup), baking powder ~6g (1 1/2 tsp \
            @192g/cup), coarse sea salt ~9g (1 1/2 tsp @288g/cup), unsalted butter ~284g \
            (1 1/4 cups @227g/cup), light brown sugar ~284g (10oz, exact), granulated \
            sugar ~227g (8oz, exact); 2 large eggs as extra counts.
            Vanilla extract (2 tsp, no gram) is a low-confidence "other" ingredient with a \
            teaspoon amount, so expect it flagged "extra" 2 teaspoons.
            Bittersweet chocolate disks/fèves ~567g (1 1/4 pounds).
            """,
        "brown_butter_chocolate_chip_cookies": """
            Flour: 325g all-purpose flour (100%, exact — "2 1/2 cups/325 grams").
            Salted butter 255g (1 cup + 2 tbsp/255g), granulated sugar 100g (1/2 cup/100g), \
            light brown sugar 55g (1/4 cup/55g), chocolate 170g (6oz/170g — explicit grams \
            win); 1 large egg as an extra count.
            Vanilla extract (1 tsp, no gram) is a low-confidence "other" ingredient with a \
            teaspoon amount, so expect it flagged "extra" 1 teaspoon.
            Demerara sugar for rolling and flaky sea salt for sprinkling have no \
            quantities, ~0g.
            """,
        "brownies_cocoa": """
            Flour: 1/4 cup all-purpose flour = 30g (100% — note this is unusually low, \
            so every other ingredient's percentage will look very large relative to it).
            Butter 1/2 cup (1 stick) ≈ 113.5g, sugar 1 cup = 200g; 2 eggs as extra counts.
            Cocoa (1/2 cup), chopped walnuts/pecans (1 cup), and vanilla (1 teaspoon) are \
            all low-confidence categories with only a volume amount and no learned \
            conversion, so expect each flagged "extra" (0.5 cup, 1 cup, 1 teaspoon \
            respectively). "Pinch of salt" has no quantity, ~0g.
            """,
        "brownies_chocolate": """
            Flour: 1/2 cup all-purpose flour = 60g (100% — again unusually low, so other \
            ingredients' percentages will look very large).
            Butter ~113.5g (8 tbsp @227g/cup), unsweetened chocolate ~113.4g (4oz, exact \
            ounce conversion regardless of category), sugar 250g (1 1/4 cups @200g/cup), \
            salt ~1.5g (1/4 tsp); 2 eggs as extra counts.
            Vanilla extract (1 tsp) and walnuts/pecans (2/3 cup) are low-confidence \
            categories with only a volume amount and no learned conversion, so expect each \
            flagged "extra" (1 teaspoon and 0.667 cup respectively).
            """,
    ]

    func testScanSampleRecipes() async throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        try await runScans()
    }

    func testExtraIngredientOunceConversionUsesSharedConstant() {
        let suggestion = ExtraIngredientConversion.suggest(name: "unsweetened chocolate",
                                                           amount: 4,
                                                           unit: "ounce")

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.grams ?? 0, 4 * UnitConversion.gramsPerOunce, accuracy: 0.001)
    }

    func testResolverUsesLocalDensityWhenModelInventsGramWeight() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "all-purpose flour",
                                          alternativeName: "",
                                          category: .allPurposeFlour,
                                          weightGrams: 512,
                                          volumeAmount: 2.5,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: true,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams,
                       IngredientDensityStore.shared.gramsPerCup(for: .allPurposeFlour) * 2.5,
                       accuracy: 0.001)
        XCTAssertFalse(resolved.isExtra)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverTrustsExplicitGramWeightOverVolume() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: true,
                                          name: "all-purpose flour",
                                          alternativeName: "",
                                          category: .allPurposeFlour,
                                          weightGrams: 325,
                                          volumeAmount: 2.5,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: true,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 325, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverKeepsLowConfidenceVolumeIngredientsAsExtras() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "vanilla extract",
                                          alternativeName: "",
                                          category: .other,
                                          weightGrams: 8,
                                          volumeAmount: 2,
                                          volumeUnit: .teaspoon,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertTrue(resolved.isExtra)
        XCTAssertEqual(resolved.weightGrams, 0, accuracy: 0.001)
        XCTAssertEqual(resolved.extraAmount, 2, accuracy: 0.001)
        XCTAssertEqual(resolved.extraUnit, .teaspoon)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverTrustsExplicitGramWeightForLowConfidenceIngredient() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: true,
                                          name: "ground cinnamon",
                                          alternativeName: "",
                                          category: .spices,
                                          weightGrams: 6,
                                          volumeAmount: 2.5,
                                          volumeUnit: .teaspoon,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertFalse(resolved.isExtra)
        XCTAssertEqual(resolved.weightGrams, 6, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverDoesNotConvertEggCountsToGrams() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "large eggs",
                                          alternativeName: "",
                                          category: .eggs,
                                          weightGrams: 100,
                                          volumeAmount: 2,
                                          volumeUnit: .egg,
                                          eggSize: .large,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 0, accuracy: 0.001)
        XCTAssertTrue(resolved.isExtra)
        XCTAssertEqual(resolved.extraAmount, 2, accuracy: 0.001)
        XCTAssertEqual(resolved.extraUnit, .count)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverTreatsNonGramEggMassAsCountExtra() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "large eggs",
                                          alternativeName: "",
                                          category: .eggs,
                                          weightGrams: 0,
                                          volumeAmount: 2,
                                          volumeUnit: .ounce,
                                          eggSize: .large,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 0, accuracy: 0.001)
        XCTAssertTrue(resolved.isExtra)
        XCTAssertEqual(resolved.extraAmount, 2, accuracy: 0.001)
        XCTAssertEqual(resolved.extraUnit, .count)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverTreatsImplausibleCupAmountAsMisplacedGrams() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "strong white bread flour",
                                          alternativeName: "",
                                          category: .breadFlour,
                                          weightGrams: 0,
                                          volumeAmount: 500,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: true,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 500, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverPrefersGramWeightWhenVolumeDisagreesWildly() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "softened butter",
                                          alternativeName: "",
                                          category: .butter,
                                          weightGrams: 80,
                                          volumeAmount: 5,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 80, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverNormalizesPlainKosherSaltToMorton() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "kosher salt",
                                          alternativeName: "",
                                          category: .diamondCrystalKosherSalt,
                                          weightGrams: 0,
                                          volumeAmount: 1,
                                          volumeUnit: .teaspoon,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.category, .mortonKosherSalt)
        XCTAssertEqual(resolved.weightGrams, 5, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverDoesNotTreatYeastPackageAsCup() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "active dry yeast",
                                          alternativeName: "",
                                          category: .activeDryYeast,
                                          weightGrams: 0,
                                          volumeAmount: 1,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 0, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverUsesImpliedYeastPackageWeight() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "active dry yeast",
                                          alternativeName: "",
                                          category: .activeDryYeast,
                                          weightGrams: 7,
                                          volumeAmount: 1,
                                          volumeUnit: .cup,
                                          eggSize: .unspecified,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertEqual(resolved.weightGrams, 7, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverConvertsPoundsAndKilograms() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let chocolate = ParsedIngredient(hasExplicitWeightGrams: false,
                                         name: "bittersweet chocolate disks",
                                         alternativeName: "",
                                         category: .chocolateChips,
                                         weightGrams: 0,
                                         volumeAmount: 1.25,
                                         volumeUnit: .pound,
                                         eggSize: .unspecified,
                                         eggPart: .whole,
                                         isFlour: false,
                                         isPreferment: false)
        let flour = ParsedIngredient(hasExplicitWeightGrams: false,
                                     name: "bread flour",
                                     alternativeName: "",
                                     category: .breadFlour,
                                     weightGrams: 0,
                                     volumeAmount: 1,
                                     volumeUnit: .kilogram,
                                     eggSize: .unspecified,
                                     eggPart: .whole,
                                     isFlour: true,
                                     isPreferment: false)

        XCTAssertEqual(RecipeScanner.resolve(chocolate).weightGrams, 20 * UnitConversion.gramsPerOunce, accuracy: 0.001)
        XCTAssertEqual(RecipeScanner.resolve(flour).weightGrams, 1_000, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserExtractsCinnamonRollsGramIngredients() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        For the Dough:
        Nonstick spray
        240 ml (1 cup) whole milk, warmed to 100°F (38°C)
        60 ml (1/4 cup) water, warmed to 100°F (38°C)
        50 g granulated sugar (1 3/4 ounces; 1/4 cup)
        7 g (2 1/4 teaspoons) active dry yeast
        42 g unsalted butter (1 1/2 ounces; 3 tablespoons), melted
        7 g (1 1/2 teaspoons) Diamond Crystal kosher salt; for table salt, use half as much by volume
        1 large egg, at room temperature or the same weight
        545 g all-purpose flour (19 1/4 ounces; 4 1/4 cups)
        To Assemble:
        265 g granulated sugar (9 1/3 ounces; 1 1/3 cups)
        6 g (2 1/2 teaspoons) ground cinnamon
        113 g unsalted butter (4 ounces; 8 tablespoons), melted
        For the Brown Sugar Drizzle:
        113 g unsalted butter (4 ounces; 8 tablespoons)
        150 g light brown sugar (5 1/4 ounces; about 3/4 cup)
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertEqual(resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }, 545, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 545 })
        XCTAssertTrue(resolved.contains { $0.name == "Whole Milk" && abs($0.weightGrams - 243.4612) < 0.01 })
        XCTAssertTrue(resolved.contains { $0.name == "Water" && abs($0.weightGrams - 60) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Granulated Sugar" && $0.weightGrams == 50 })
        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && $0.weightGrams == 7 })
        XCTAssertTrue(resolved.contains { $0.name == "Unsalted Butter" && $0.weightGrams == 42 })
        XCTAssertTrue(resolved.contains { $0.name == "Diamond Crystal Kosher Salt" && $0.weightGrams == 7 })
        XCTAssertTrue(resolved.contains { $0.name == "Large Egg" && $0.isExtra && $0.extraAmount == 1 && $0.extraUnit == .count })
        XCTAssertTrue(resolved.contains { $0.name == "Ground Cinnamon" && !$0.isExtra && $0.weightGrams == 6 })
        XCTAssertTrue(resolved.contains { $0.name == "Light Brown Sugar" && $0.weightGrams == 150 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverUsesWaterConversionAsMilliliterCupBasis() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let store = IngredientDensityStore.shared
        let hadWaterOverride = store.isCustomized(.water)
        let previousWater = store.gramsPerCup(for: .water)
        defer {
            if hadWaterOverride {
                store.setGramsPerCup(previousWater, for: .water)
            } else {
                store.resetToDefault(for: .water)
            }
        }

        store.setGramsPerCup(240, for: .water)

        let water = ParsedIngredient(hasExplicitWeightGrams: false,
                                     name: "water",
                                     alternativeName: "",
                                     category: .water,
                                     weightGrams: 0,
                                     volumeAmount: 60,
                                     volumeUnit: .milliliter,
                                     eggSize: .unspecified,
                                     eggPart: .whole,
                                     isFlour: false,
                                     isPreferment: false)
        let milk = ParsedIngredient(hasExplicitWeightGrams: false,
                                    name: "whole milk",
                                    alternativeName: "",
                                    category: .milk,
                                    weightGrams: 0,
                                    volumeAmount: 240,
                                    volumeUnit: .milliliter,
                                    eggSize: .unspecified,
                                    eggPart: .whole,
                                    isFlour: false,
                                    isPreferment: false)

        XCTAssertEqual(RecipeScanner.resolve(water).weightGrams, 60, accuracy: 0.001)
        XCTAssertEqual(RecipeScanner.resolve(milk).weightGrams, 240, accuracy: 0.001)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserCleansCommonOCRMeasurementJunk() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        7 9 (2 1/4 teaspoons) active dry yeast
        545 g all-purpose flour (19 1/4 ounces; 4 1/4 cups)
        50 g granulated sugar (1 3/4 ounces; 1/4 cup)
        42 g unsalted butter (1 1/2 ounces; 3 tablespoons), melted
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && $0.weightGrams == 7 })
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 545 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserReadsSlashFractionsBeforeBareIntegers() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1/4 cup light brown sugar
        1/4 cup honey
        1/4 teaspoon salt
        1 tablespoon vegetable oil
        2 cups all-purpose flour
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Light Brown Sugar" && abs($0.weightGrams - 53.25) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Honey" && abs($0.weightGrams - 85) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Salt" && abs($0.weightGrams - 1.5) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Vegetable Oil" && abs($0.weightGrams - 13.625) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserKeepsClosingMeasurementFragmentsWithPreviousLine() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1 cup plus 2 tablespoons granulated sugar (8
        ounces)
        2 large eggs
        1 2/3 cups bread flour (8 1/2 ounces)
        2 teaspoons natural vanilla extract
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Granulated Sugar" && abs($0.weightGrams - 226.796) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Large Eggs" && $0.isExtra && $0.extraAmount == 2 && $0.extraUnit == .count })
        XCTAssertTrue(resolved.contains { $0.name == "Bread Flour" && abs($0.weightGrams - 240.97075) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Natural Vanilla Extract" && $0.isExtra && $0.extraAmount == 2 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserHandlesCupBasedFlourWithoutModelFallback() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        2 1/2 cups all-purpose flour
        1/4 oz active dry yeast
        1/4 teaspoon salt
        1 cup warm water
        1 tablespoon olive oil
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertEqual(resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }, 300, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 300 })
        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && abs($0.weightGrams - 7.087375) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Salt" && abs($0.weightGrams - 1.5) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserKeepsUnmeasuredYeastPackageAtZeroGrams() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1 package active dry yeast
        1 cup warm water
        4 cups all-purpose flour
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && $0.weightGrams == 7 })
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 480 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserKeepsMeasuredFlourWithDustingNote() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        4 cups all-purpose flour, plus more for dusting
        1 cup warm water
        1 teaspoon salt
        1 package active dry yeast
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 480 })
        XCTAssertTrue(resolved.contains { $0.name == "Water" && abs($0.weightGrams - 236.588) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserExtractsCinnamonRollsCupIngredients() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients:
        Dough:
        1 package active dry yeast
        1 cup warm water
        1/2 cup sugar
        3/4 cup (1 1/2 sticks) melted margarine or butter, cooled, plus more for brushing
        2 large eggs
        1 teaspoon salt
        4 cups all-purpose flour, plus more for dusting
        1 tablespoon vegetable oil
        Filling:
        1/2 cup dark brown sugar
        2 tablespoons ground cinnamon
        1 tablespoon grated orange zest
        1/2 cup golden raisins
        1/2 cup chopped walnuts
        1/4 cup melted margarine or butter, cooled
        Glaze:
        1/4 cup water
        2 cups confectioners' sugar, sifted
        1 orange, zest finely grated
        1 large egg white
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)
        let totalFlour = resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }

        XCTAssertEqual(totalFlour, 480, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && $0.weightGrams == 7 })
        XCTAssertTrue(resolved.contains { $0.name == "Water" && abs($0.weightGrams - 236.588) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Sugar" && abs($0.weightGrams - 99) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 480 })
        XCTAssertTrue(resolved.contains { $0.name == "Large Eggs" && $0.isExtra && $0.extraAmount == 2 && $0.extraUnit == .count })
        XCTAssertTrue(resolved.contains { $0.name == "Ground Cinnamon" && $0.isExtra && $0.extraAmount == 2 && $0.extraUnit == .tablespoon })
        XCTAssertTrue(resolved.contains { $0.name == "Confectioners' Sugar" && $0.weightGrams == 226 })
        XCTAssertTrue(resolved.contains { $0.name == "Orange Zest" && $0.isExtra && $0.extraAmount == 1 && $0.extraUnit == .count })
        XCTAssertTrue(resolved.contains { $0.name == "Large Egg White" && $0.isExtra && $0.extraAmount == 1 && $0.extraUnit == .count })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserUsesMidpointForVolumeRanges() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        2 1/2 cups all-purpose flour
        1/2 - 1 tablespoon olive oil
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Olive Oil" && abs($0.weightGrams - 10.125) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserRepairsSplitAmountRangeAndUnitRows() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        2 1/2 cups all-purpose flour
        1/2 - 1
        tablespoon olive oil
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Olive Oil" && abs($0.weightGrams - 10.125) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserHandlesNoQuantitySeasoningsAndCounts() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1/2 cup all-purpose flour
        Pinch of salt
        Kosher salt
        Freshly ground black pepper
        12 to 16 basil leaves
        1 orange, zest finely grated
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Salt" && $0.weightGrams == 0 })
        XCTAssertTrue(resolved.contains { $0.name == "Kosher Salt" && $0.weightGrams == 0 })
        XCTAssertTrue(resolved.contains { $0.name == "Freshly Ground Black Pepper" && $0.weightGrams == 0 })
        XCTAssertTrue(resolved.contains { $0.name == "Basil Leaves" && $0.isExtra && $0.extraAmount == 14 && $0.extraUnit == .count })
        XCTAssertTrue(resolved.contains { $0.name == "Orange Zest" && $0.isExtra && $0.extraAmount == 1 && $0.extraUnit == .count })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserHandlesFreeRangeEggCounts() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        500 g strong white flour
        2 free-range eggs
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Eggs" && $0.isExtra && $0.extraAmount == 2 && $0.extraUnit == .count })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserKeepsWrappedBulletTextWithPreviousIngredient() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        For the dough:
        1 1/2 tablespoons (22 grams) diastatic malt
        texture and brown crust, but is optional
        1/3 cup (80 grams) iced water
        1000 grams bread flour
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Diastatic Malt" && $0.weightGrams == 22 })
        XCTAssertFalse(resolved.contains { $0.name.contains("Texture") })
        XCTAssertTrue(resolved.contains { $0.name == "Iced Water" && $0.weightGrams == 80 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserConvertsPoundMassIngredients() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1/2 cup all-purpose flour
        1 1/4 pounds bittersweet chocolate disks or fèves, at least 60 percent cacao content
        1 pound fresh mozzarella
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Bittersweet Chocolate Disks Or Fèves" && abs($0.weightGrams - 566.99) < 0.01 })
        XCTAssertTrue(resolved.contains { $0.name == "Fresh Mozzarella" && abs($0.weightGrams - 453.592) < 0.01 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserReadsTwoThirdsCupAsFraction() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1/2 cup all-purpose flour
        2/3 cup lightly toasted walnuts or pecans (optional)
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Lightly Toasted Walnuts Or Pecans" && $0.isExtra && abs($0.extraAmount - 2.0 / 3.0) < 0.001 && $0.extraUnit == .cup })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testResolverNormalizesCommonTwoThirdsCupOCRForNuts() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let ingredient = ParsedIngredient(hasExplicitWeightGrams: false,
                                          name: "lightly toasted walnuts or pecans",
                                          alternativeName: "",
                                          category: .nuts,
                                          weightGrams: 0,
                                          volumeAmount: 2 + 1.0 / 3.0,
                                          volumeUnit: .cup,
                                          eggSize: .large,
                                          eggPart: .whole,
                                          isFlour: false,
                                          isPreferment: false)

        let resolved = RecipeScanner.resolve(ingredient)

        XCTAssertTrue(resolved.isExtra)
        XCTAssertEqual(resolved.extraAmount, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(resolved.extraUnit, .cup)
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserExtractsRyeBreadCupIngredients() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients:
        Bread:
        1 1/2 cups milk
        One 1/4-ounce package active dry yeast
        1/4 cup packed brown sugar
        2 tablespoons butter, melted
        1/2 teaspoon kosher salt
        2 cups rye flour
        2 cups all-purpose flour, plus more for flouring
        Neutral oil, for oiling the bowl and baking sheet
        Honey Butter:
        1 stick butter, softened
        1/4 cup honey
        Kosher salt
        Freshly ground black pepper
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)
        let totalFlour = resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }

        XCTAssertEqual(totalFlour, 452, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "Milk" && $0.weightGrams == 360 })
        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && abs($0.weightGrams - UnitConversion.gramsPerOunce / 4) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Packed Brown Sugar" && abs($0.weightGrams - 53.25) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Butter" && abs($0.weightGrams - 28.375) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Kosher Salt" && abs($0.weightGrams - 2.5) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Rye Flour" && $0.weightGrams == 212 })
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 240 })
        XCTAssertTrue(resolved.contains { $0.name == "Honey" && $0.weightGrams == 85 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserExtractsSlashSeparatedGramAmountsWithoutSpaces() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        500g/1lb 2oz strong white bread flour, plus extra for dusting
        10g/1/3oz salt
        10g/1/3oz instant yeast
        fine semolina, for dusting
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Strong White Bread Flour" && $0.weightGrams == 500 })
        XCTAssertTrue(resolved.contains { $0.name == "Salt" && $0.weightGrams == 10 })
        XCTAssertTrue(resolved.contains { $0.name == "Instant Yeast" && $0.weightGrams == 10 })
        XCTAssertFalse(resolved.contains { $0.name == "Fine Semolina" })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserExtractsNoFlourSauceIngredients() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        2 tablespoons extra-virgin olive oil, plus more for drizzling
        4 medium cloves garlic, minced (about 4 teaspoons)
        1 teaspoon dried oregano
        1/2 teaspoon red pepper flakes
        1 (28-ounce) can whole peeled tomatoes, roughly broken up by hand
        1 cup heavy cream
        1/3 cup vodka
        Kosher salt and freshly ground black pepper
        1 recipe basic New York pizza dough, divided and risen at least 2 hours (see notes)
        1 pound fresh mozzarella (preferably buffalo milk), torn into rough 3/4- to 1-inch chunks
        12 to 16 basil leaves
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertEqual(resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }, 0, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "Extra-Virgin Olive Oil" && $0.weightGrams == 27 })
        XCTAssertTrue(resolved.contains { $0.name == "Medium Cloves Garlic" && $0.isExtra && $0.extraAmount == 4 && $0.extraUnit == .teaspoon })
        XCTAssertTrue(resolved.contains { $0.name == "Dried Oregano" && $0.isExtra && $0.extraAmount == 1 && $0.extraUnit == .teaspoon })
        XCTAssertTrue(resolved.contains { $0.name == "Red Pepper Flakes" && $0.isExtra && $0.extraAmount == 0.5 && $0.extraUnit == .teaspoon })
        XCTAssertTrue(resolved.contains { $0.name == "Can Whole Peeled Tomatoes" && abs($0.weightGrams - 793.786) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Heavy Cream" && $0.weightGrams == 240 })
        XCTAssertTrue(resolved.contains { $0.name == "Vodka" && $0.isExtra && abs($0.extraAmount - 1.0 / 3.0) < 0.001 && $0.extraUnit == .cup })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserRepairsSplitAmountAndUnitRows() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        cups all-purpose flour (may substitute
        2 1/2 whole wheat flour for 1 cup of the all-purpose)
        1 (1/4 ounce) package active dry yeast
        1/4 teaspoon salt
        1 cup warm water
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.category == .allPurposeFlour && $0.weightGrams == 300 })
        XCTAssertFalse(resolved.contains { $0.category == .wholeWheatFlour && $0.isFlour })
        XCTAssertTrue(resolved.contains { $0.name == "Active Dry Yeast" && abs($0.weightGrams - 7.087375) < 0.001 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserHandlesOunceBasedCookieRecipe() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        2 cups minus 2 tablespoons (8 1/2 ounces) cake flour
        1 2/3 cups (8 1/2 ounces) bread flour
        1 1/4 teaspoons baking soda
        1 1/2 teaspoons baking powder
        1 1/2 teaspoons coarse sea salt
        1 1/4 cups unsalted butter
        10 ounces light brown sugar
        8 ounces granulated sugar
        2 large eggs
        2 teaspoons natural vanilla extract
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)
        let totalFlour = resolved.filter(\.isFlour).reduce(0) { $0 + $1.weightGrams }

        XCTAssertEqual(totalFlour, 481.9415, accuracy: 0.001)
        XCTAssertTrue(resolved.contains { $0.name == "Cake Flour" && abs($0.weightGrams - 240.97075) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Bread Flour" && abs($0.weightGrams - 240.97075) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Light Brown Sugar" && abs($0.weightGrams - 283.495) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Granulated Sugar" && abs($0.weightGrams - 226.796) < 0.001 })
        XCTAssertTrue(resolved.contains { $0.name == "Natural Vanilla Extract" && $0.isExtra && $0.extraAmount == 2 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserCleansSlashSeparatedGramNames() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        Ingredients
        1 cup plus 2 tablespoons/255 grams total salted butter (2 1/4 sticks), cold
        1/2 cup/100 grams granulated sugar
        1/4 cup/55 grams light brown sugar
        2 1/2 cups/325 grams all-purpose flour
        6 ounces/170 grams semi-sweet or bittersweet dark chocolate, chopped
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertTrue(resolved.contains { $0.name == "Salted Butter" && $0.weightGrams == 255 })
        XCTAssertTrue(resolved.contains { $0.name == "Granulated Sugar" && $0.weightGrams == 100 })
        XCTAssertTrue(resolved.contains { $0.name == "Light Brown Sugar" && $0.weightGrams == 55 })
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.weightGrams == 325 })
        XCTAssertTrue(resolved.contains { $0.name == "Semi-Sweet Or Bittersweet Dark Chocolate" && $0.weightGrams == 170 })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    func testLocalParserIgnoresFocacciaPreambleAndWrappedIngredientNotes() throws {
        guard #available(iOS 26, *) else {
            throw XCTSkip("RecipeScanner requires iOS 26.")
        }
        #if canImport(FoundationModels)
        let text = """
        9:06
        environment, I would suggest using bread
        flour. If you are in Canada or the UK, also
        consider using bread flour or consider
        holding back some of the water. Reference
        the video for how the texture of the bread
        should look; then add water back as needed.
        Ingredients
        4 cups (512 g) all-purpose flour or bread
        flour, see notes above
        2 to 3 teaspoons (10 to 15 grams) kosher
        salt, see notes above
        2 teaspoons (8 g) instant yeast, see notes
        above if using active dry
        2 cups (455 g) lukewarm water, made by
        combining 1/2 cup boiling water with 1 1/2
        cups cold water
        butter for greasing
        4 tablespoons olive oil, divided
        flaky sea salt, such as Maldon
        1 to 2 teaspoons whole rosemary leaves,
        optional
        Instructions
        """

        let parsed = RecipeScanner.parseIngredientsLocally(from: text)
        let resolved = parsed.ingredients.map(RecipeScanner.resolve)

        XCTAssertFalse(resolved.contains { $0.name.localizedCaseInsensitiveContains("environment") })
        XCTAssertFalse(resolved.contains { $0.name.localizedCaseInsensitiveContains("combining") })
        XCTAssertEqual(resolved.filter { $0.category == .water && $0.weightGrams > 0 }.count, 1)
        XCTAssertTrue(resolved.contains { $0.name == "All-Purpose Flour" && $0.alternativeName == "Bread Flour" && $0.weightGrams == 512 })
        XCTAssertTrue(resolved.contains { $0.name == "Kosher Salt" && $0.weightGrams == 12.5 })
        XCTAssertTrue(resolved.contains { $0.name == "Instant Yeast" && $0.alternativeName == "Active Dry Yeast" && $0.weightGrams == 8 })
        XCTAssertTrue(resolved.contains { $0.name == "Water" && $0.weightGrams == 455 })
        XCTAssertTrue(resolved.contains { $0.name == "Olive Oil" && $0.weightGrams == 54 })
        XCTAssertTrue(resolved.contains { $0.name == "Whole Rosemary Leaves" && $0.isExtra && $0.extraAmount == 1.5 && $0.extraUnit == .teaspoon })
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    @available(iOS 26, *)
    private func runScans() async throws {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else {
            throw XCTSkip("Apple Intelligence is not available on this simulator/device.")
        }

        let bundle = Bundle(for: Self.self)
        for name in Self.recipeFileNames {
            guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Recipes"),
                  let image = UIImage(contentsOfFile: url.path) else {
                XCTFail("Missing test fixture image: Recipes/\(name).png")
                continue
            }

            print("\n========== \(name) ==========")
            if let expected = Self.expectedSummaries[name] {
                print("--- Expected ---")
                print(expected.trimmingCharacters(in: .whitespacesAndNewlines))
                print("--- Actual ---")
            }
            do {
                let result = try await RecipeScanner.shared.scan(image: image)
                printDiagnostics(for: result)
            } catch {
                print("Scan failed: \(error.localizedDescription)")
            }
        }
        #else
        throw XCTSkip("FoundationModels is not available in this build.")
        #endif
    }

    @available(iOS 26, *)
    private func printDiagnostics(for result: ScanResult) {
        let recipe = result.resolvedRecipe
        print("Name: \(recipe.name)")
        if recipe.hasPreferment {
            print("Preferment: \(recipe.prefermentName)")
        }

        let totalFlour = recipe.ingredients
            .filter { $0.isFlour }
            .reduce(0) { $0 + $1.weightGrams }
        print("Total flour: \(totalFlour)g")

        for ingredient in recipe.ingredients {
            let prefTag = ingredient.isPreferment ? " (preferment)" : ""
            if ingredient.isExtra {
                print("  [extra] \(ingredient.name)\(prefTag): \(ingredient.extraAmount) \(ingredient.extraUnit.rawValue)")
            } else {
                let percent = totalFlour > 0 ? ingredient.weightGrams / totalFlour * 100 : 0
                let flourTag = ingredient.isFlour ? " [flour]" : ""
                print("  \(ingredient.name)\(flourTag)\(prefTag): \(ingredient.weightGrams)g (\(String(format: "%.1f", percent))%)")
            }
        }
    }
}
