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
            Dough: whole milk ~240g (240ml/1cup), water ~60g (60ml/1/4cup), granulated \
            sugar 50g, active dry yeast 7g, butter 42g, kosher salt 7g, egg ~0g (count, no \
            weight given).
            To assemble: granulated sugar 265g, butter 113g; ground cinnamon (2 1/2 tsp, \
            6g stated) is a low-confidence category + teaspoon, so expect it flagged \
            "extra" 2.5 teaspoons (its 6g is ignored by design, same as rosemary leaves).
            Brown sugar drizzle: butter 113g, light brown sugar 150g (5oz).
            """,
        "bread_machine_cups": """
            Flour: ~313g all-purpose flour (2.5 cups @125g/cup) (100%, estimated).
            Active dry yeast ~7.1g (1/4 oz, exact), salt ~1.5g (1/4 tsp), warm water \
            ~236g (1 cup), olive oil ~10.1g (1/2-1 tbsp, midpoint 0.75 tbsp).
            """,
        "cinnamon_rolls_cups": """
            Flour: 500g all-purpose flour (4 cups @125g/cup) (100%, estimated).
            Dough: active dry yeast ~0g (no quantity given, just "1 package"), water \
            236g (1 cup), sugar 100g (1/2 cup), margarine/butter ~170g (3/4 cup, mapped \
            to butter), eggs ~0g (count), salt 6g (1 tsp), vegetable oil ~13.6g (1 tbsp).
            Filling: dark brown sugar 110g (1/2 cup), butter ~57g (1/4 cup); ground \
            cinnamon (2 tbsp), grated orange zest (1 tbsp), golden raisins (1/2 cup), and \
            chopped walnuts (1/2 cup) all have only volume amounts in low-confidence \
            categories with no learned conversion, so expect each flagged "extra" in its \
            original unit.
            Glaze: water ~59g (1/4 cup), confectioners' sugar 240g (2 cups, mapped to \
            powderedSugar); orange zest and egg white are counts with no quantity, ~0g.
            """,
        "partial_recipe": """
            Screenshot is mostly section headers ("For the Frosting:", "For the Filling:", \
            "For the Dough:") with little/no visible ingredient text. Expect minimal or no \
            ingredients parsed — possibly ScanError.noFlourFound if no flour line is \
            legible.
            """,
        "vodka_pizza_sauce": """
            This is a sauce recipe that references an external "basic New York pizza \
            dough" — no flour ingredient appears directly in this text. Expect \
            ScanError.noFlourFound (or a resolved recipe with 0g total flour).
            If ingredients are still extracted: olive oil ~27g (2 tbsp), canned tomatoes \
            ~794g (28 oz, exact ounce conversion regardless of category), heavy cream \
            240g (1 cup, mapped to cream); garlic (~4 tsp), dried oregano (1 tsp), red \
            pepper flakes (1/2 tsp), and vodka (1/3 cup) are volume-only in low-confidence \
            categories, so expect each flagged "extra". Salt/pepper, the pizza dough \
            reference, mozzarella ("1 pound" — unsupported unit), and basil leaves (count) \
            should resolve to ~0g.
            """,
        "rye_bread_honey_butter": """
            Flour: rye flour 204g (2 cups @102g/cup) + all-purpose flour 250g (2 cups \
            @125g/cup) = 454g total (rye ~45.0%, AP ~55.0%, estimated).
            Bread: milk 360g (1.5 cups), active dry yeast ~7.1g (1/4 oz, exact), brown \
            sugar 55g (1/4 cup), butter ~28.4g (2 tbsp), kosher salt 2.5g (1/2 tsp); \
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
            Biga (preferment): water 531g (2 1/4 cups), yeast 4g (stated for the fresh \
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
            sugar ~227g (8oz, exact); 2 large eggs ~0g (count).
            Vanilla extract (2 tsp, no gram) is a low-confidence "other" ingredient with a \
            teaspoon amount, so expect it flagged "extra" 2 teaspoons.
            "1 1/4 pounds" bittersweet chocolate — "pounds" isn't a recognized unit, so \
            expect ~0g unless the model converts it to ounces (~567g).
            """,
        "brown_butter_chocolate_chip_cookies": """
            Flour: 325g all-purpose flour (100%, exact — "2 1/2 cups/325 grams").
            Salted butter 255g (1 cup + 2 tbsp/255g), granulated sugar 100g (1/2 cup/100g), \
            light brown sugar 55g (1/4 cup/55g), chocolate 170g (6oz/170g — explicit grams \
            win); 1 large egg ~0g (count).
            Vanilla extract (1 tsp, no gram) is a low-confidence "other" ingredient with a \
            teaspoon amount, so expect it flagged "extra" 1 teaspoon.
            Demerara sugar for rolling and flaky sea salt for sprinkling have no \
            quantities, ~0g.
            """,
        "brownies_cocoa": """
            Flour: 1/4 cup all-purpose flour ≈ 31.25g (100% — note this is unusually low, \
            so every other ingredient's percentage will look very large relative to it).
            Butter 1/2 cup (1 stick) ≈ 113.5g, sugar 1 cup = 200g; 2 eggs ~0g (count).
            Cocoa (1/2 cup), chopped walnuts/pecans (1 cup), and vanilla (1 teaspoon) are \
            all low-confidence categories with only a volume amount and no learned \
            conversion, so expect each flagged "extra" (0.5 cup, 1 cup, 1 teaspoon \
            respectively). "Pinch of salt" has no quantity, ~0g.
            """,
        "brownies_chocolate": """
            Flour: 1/2 cup all-purpose flour = 62.5g (100% — again unusually low, so other \
            ingredients' percentages will look very large).
            Butter ~113.5g (8 tbsp @227g/cup), unsweetened chocolate ~113.4g (4oz, exact \
            ounce conversion regardless of category), sugar 250g (1 1/4 cups @200g/cup), \
            salt ~1.5g (1/4 tsp); 2 eggs ~0g (count).
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
