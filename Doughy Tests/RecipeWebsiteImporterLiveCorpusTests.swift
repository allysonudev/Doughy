//
//  RecipeWebsiteImporterLiveCorpusTests.swift
//  Doughy Tests
//

@testable import Doughy
import XCTest

final class RecipeWebsiteImporterLiveCorpusTests: XCTestCase {
    private static var shouldRunLiveCorpus: Bool {
        if ProcessInfo.processInfo.environment["DOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS"] == "1" {
            return true
        }

        #if DOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS
        return true
        #else
        return false
        #endif
    }

    private struct LiveRecipeCase: Sendable {
        let url: URL
        let expectedName: String
        let expectedIngredientCount: Int
        let expectedInstructionCount: Int

        init(url: String, expectedName: String, expectedIngredientCount: Int, expectedInstructionCount: Int) {
            self.url = URL(string: url)!
            self.expectedName = expectedName
            self.expectedIngredientCount = expectedIngredientCount
            self.expectedInstructionCount = expectedInstructionCount
        }

        func failureMessage() async -> String? {
            do {
                let draft = try await RecipeWebsiteImporter.shared.importRecipe(from: url)
                var failures: [String] = []

                if draft.name != expectedName {
                    failures.append("name: expected \(expectedName.debugDescription), got \(draft.name.debugDescription)")
                }
                if draft.ingredientLines.count != expectedIngredientCount {
                    failures.append("ingredients: expected \(expectedIngredientCount), got \(draft.ingredientLines.count)")
                }
                if draft.instructions.count != expectedInstructionCount {
                    failures.append("instructions: expected \(expectedInstructionCount), got \(draft.instructions.count)")
                }
                if draft.resolvedIngredients.isEmpty {
                    failures.append("resolvedIngredients was empty")
                }

                guard !failures.isEmpty else { return nil }
                return "\(url.absoluteString)\n  - \(failures.joined(separator: "\n  - "))"
            } catch {
                return "\(url.absoluteString)\n  - import threw \(String(describing: error))"
            }
        }
    }

    private struct ExpectedResolvedIngredient: Sendable {
        let name: String
        let weightGrams: Double?
        let isFlour: Bool?
        let isExtra: Bool?
        let extraAmount: Double?
        let extraUnit: String?
        let isPreferment: Bool?

        init(name: String,
             weightGrams: Double? = nil,
             isFlour: Bool? = nil,
             isExtra: Bool? = nil,
             extraAmount: Double? = nil,
             extraUnit: String? = nil,
             isPreferment: Bool? = nil) {
            self.name = name
            self.weightGrams = weightGrams
            self.isFlour = isFlour
            self.isExtra = isExtra
            self.extraAmount = extraAmount
            self.extraUnit = extraUnit
            self.isPreferment = isPreferment
        }
    }

    private struct DeepLiveRecipeCase: Sendable {
        let base: LiveRecipeCase
        let expectedIngredientLines: [String]
        let expectedInstructionSnippets: [String]
        let expectedResolvedIngredients: [ExpectedResolvedIngredient]
        let expectedPrefermentName: String?
        let expectedPrefermentIngredientCount: Int?

        init(base: LiveRecipeCase,
             expectedIngredientLines: [String],
             expectedInstructionSnippets: [String],
             expectedResolvedIngredients: [ExpectedResolvedIngredient],
             expectedPrefermentName: String? = nil,
             expectedPrefermentIngredientCount: Int? = nil) {
            self.base = base
            self.expectedIngredientLines = expectedIngredientLines
            self.expectedInstructionSnippets = expectedInstructionSnippets
            self.expectedResolvedIngredients = expectedResolvedIngredients
            self.expectedPrefermentName = expectedPrefermentName
            self.expectedPrefermentIngredientCount = expectedPrefermentIngredientCount
        }

        func failureMessage() async -> String? {
            do {
                let draft = try await RecipeWebsiteImporter.shared.importRecipe(from: base.url)
                var failures: [String] = []

                if draft.name != base.expectedName {
                    failures.append("name: expected \(base.expectedName.debugDescription), got \(draft.name.debugDescription)")
                }
                if draft.ingredientLines.count != base.expectedIngredientCount {
                    failures.append("ingredients: expected \(base.expectedIngredientCount), got \(draft.ingredientLines.count)")
                }
                if draft.instructions.count != base.expectedInstructionCount {
                    failures.append("instructions: expected \(base.expectedInstructionCount), got \(draft.instructions.count)")
                }
                if draft.prefermentName != expectedPrefermentName {
                    failures.append("prefermentName: expected \(expectedPrefermentName.debugDescription), got \(draft.prefermentName.debugDescription)")
                }
                if let expectedPrefermentIngredientCount,
                   draft.resolvedIngredients.filter(\.isPreferment).count != expectedPrefermentIngredientCount {
                    failures.append(
                        "prefermentIngredientCount: expected \(expectedPrefermentIngredientCount), got \(draft.resolvedIngredients.filter(\.isPreferment).count)"
                    )
                }

                for expectedLine in expectedIngredientLines
                    where !draft.ingredientLines.contains(expectedLine) {
                    failures.append("missing ingredient line \(expectedLine.debugDescription)")
                }

                for snippet in expectedInstructionSnippets
                    where !draft.instructions.contains(where: { $0.contains(snippet) }) {
                    failures.append("missing instruction snippet \(snippet.debugDescription)")
                }

                for expected in expectedResolvedIngredients {
                    guard let actual = draft.resolvedIngredients.first(where: { $0.name == expected.name }) else {
                        failures.append("missing resolved ingredient \(expected.name.debugDescription)")
                        continue
                    }

                    if let weightGrams = expected.weightGrams,
                       abs(actual.weightGrams - weightGrams) > 0.01 {
                        failures.append(
                            "\(expected.name): expected \(weightGrams)g, got \(actual.weightGrams)g"
                        )
                    }
                    if let isFlour = expected.isFlour, actual.isFlour != isFlour {
                        failures.append("\(expected.name): expected isFlour \(isFlour), got \(actual.isFlour)")
                    }
                    if let isExtra = expected.isExtra, actual.isExtra != isExtra {
                        failures.append("\(expected.name): expected isExtra \(isExtra), got \(actual.isExtra)")
                    }
                    if let extraAmount = expected.extraAmount,
                       abs(actual.extraAmount - extraAmount) > 0.01 {
                        failures.append(
                            "\(expected.name): expected extraAmount \(extraAmount), got \(actual.extraAmount)"
                        )
                    }
                    if let extraUnit = expected.extraUnit, actual.extraUnit != extraUnit {
                        failures.append("\(expected.name): expected extraUnit \(extraUnit), got \(actual.extraUnit)")
                    }
                    if let isPreferment = expected.isPreferment, actual.isPreferment != isPreferment {
                        failures.append("\(expected.name): expected isPreferment \(isPreferment), got \(actual.isPreferment)")
                    }
                }

                guard !failures.isEmpty else { return nil }
                return "\(base.url.absoluteString)\n  - \(failures.joined(separator: "\n  - "))"
            } catch {
                return "\(base.url.absoluteString)\n  - import threw \(String(describing: error))"
            }
        }
    }

    func testLiveRecipeCorpusContains100UniqueURLs() {
        XCTAssertEqual(Self.popularRecipePages.count, 100)
        XCTAssertEqual(Set(Self.popularRecipePages.map(\.url)).count, 100)
    }

    func testPopularRecipePagesImportExpectedStructuredData() async throws {
        try XCTSkipUnless(
            Self.shouldRunLiveCorpus,
            "Set DOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS=1 in the test host environment, or build with -DDOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS, to run the 100-page live recipe importer corpus."
        )

        let limitText = ProcessInfo.processInfo.environment["DOUGHY_LIVE_RECIPE_CORPUS_LIMIT"]
        let limit = limitText.flatMap(Int.init).map { max(1, min($0, Self.popularRecipePages.count)) }
            ?? Self.popularRecipePages.count
        let concurrencyText = ProcessInfo.processInfo.environment["DOUGHY_LIVE_RECIPE_CORPUS_CONCURRENCY"]
        let concurrency = concurrencyText.flatMap(Int.init).map { max(1, min($0, 8)) } ?? 4
        let cases = Array(Self.popularRecipePages.prefix(limit))

        var failures: [String] = []
        for start in stride(from: 0, to: cases.count, by: concurrency) {
            let end = min(start + concurrency, cases.count)
            let batch = cases[start..<end]

            await withTaskGroup(of: String?.self) { group in
                for recipeCase in batch {
                    group.addTask {
                        await recipeCase.failureMessage()
                    }
                }

                for await failure in group {
                    if let failure {
                        failures.append(failure)
                    }
                }
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n\n"))
    }

    func testPopularRecipeSubsetImportsDeepExpectedOutput() async throws {
        try XCTSkipUnless(
            Self.shouldRunLiveCorpus,
            "Set DOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS=1 in the test host environment, or build with -DDOUGHY_RUN_LIVE_RECIPE_IMPORT_TESTS, to run the live recipe importer corpus."
        )

        var failures: [String] = []
        for recipeCase in Self.deepRecipePages {
            if let failure = await recipeCase.failureMessage() {
                failures.append(failure)
            }
        }

        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n\n"))
    }

    private static let deepRecipePages: [DeepLiveRecipeCase] = [
        // Poolish recipe: King Arthur lists the poolish and dough as separate HTML groups
        // (no equivalent in their JSON-LD, which is one flat list including a non-ingredient
        // "all of the poolish" back-reference line) - this locks in that the importer
        // recovers the grouping instead of flattening everything into one ingredient list
        // with duplicate "All-Purpose Flour"/yeast entries (see RecipeDiff crash fix).
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://www.kingarthurbaking.com/recipes/classic-baguettes-recipe",
                expectedName: "Classic Baguettes",
                expectedIngredientCount: 8,
                expectedInstructionCount: 16
            ),
            expectedIngredientLines: [
                "1/2 cup (113g) water, cool",
                "all of the poolish",
                "2 teaspoons (12g) table salt",
            ],
            expectedInstructionSnippets: [
                "To make the poolish",
                "Bake the baguettes",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "Table Salt", weightGrams: 12, isFlour: false, isExtra: false, isPreferment: false),
            ],
            expectedPrefermentName: "Poolish",
            expectedPrefermentIngredientCount: 3
        ),
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-sandwich-bread-recipe",
                expectedName: "100% Whole Wheat Sandwich Bread",
                expectedIngredientCount: 10,
                expectedInstructionCount: 7
            ),
            expectedIngredientLines: [
                "1/2 cup (113g) water, lukewarm*",
                "3 3/4 cups (425g) King Arthur Golden Wheat Flour",
            ],
            expectedInstructionSnippets: [
                "Dissolve the yeast in the lukewarm water",
                "Bake the bread for 10 minutes",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "Water", weightGrams: 113, isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Table Salt", weightGrams: 9, isFlour: false, isExtra: false),
                // The "King Arthur" brand prefix is stripped from scraped ingredient names -
                // see stripBrandingAndMarketing(from:) in RecipeWebsiteImporter.
                ExpectedResolvedIngredient(name: "Golden Wheat Flour", weightGrams: 425, isFlour: true, isExtra: false),
            ]
        ),
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://sallysbakingaddiction.com/egg-muffins-recipe/",
                expectedName: "Breakfast Egg Muffins (Frittata Muffins)",
                expectedIngredientCount: 11,
                expectedInstructionCount: 7
            ),
            expectedIngredientLines: [
                "8 large eggs",
                "1/3 cup (80ml) whole milk or half-and-half (or nondairy milk)",
            ],
            expectedInstructionSnippets: [
                "Preheat oven to 375°F",
                "Bake for 18–20 minutes",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "Large Eggs", weightGrams: 8 * IngredientDensityStore.shared.gramsPerEgg(for: .large), isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Whole Milk Or Half-And-Half", weightGrams: IngredientDensityStore.shared.gramsPerCup(for: .milk) / 3, isFlour: false, isExtra: false),
            ]
        ),
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://www.thekitchn.com/recipe-savory-bread-pudding-with-spinach-chevre-smoked-ham-and-smoky-roasted-red-pepper-sauce-recipe-181996",
                expectedName: "Recipe: Savory Bread Pudding with Spinach, Chèvre, Smoked Ham &Smoky Roasted Red Pepper Sauce",
                expectedIngredientCount: 16,
                expectedInstructionCount: 4
            ),
            expectedIngredientLines: [
                "3 large eggs",
                "6 ounces chèvre or other fresh goat cheese, coarsely crumbled (about 1 cup)",
            ],
            expectedInstructionSnippets: [
                "Stir together the milk and bread",
                "Serve warm with a little of the sauce",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "Large Eggs", weightGrams: 3 * IngredientDensityStore.shared.gramsPerEgg(for: .large), isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Diced Smoked Ham", weightGrams: 8 * UnitConversion.gramsPerOunce, isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Chèvre Or Other Fresh Goat Cheese", weightGrams: 6 * UnitConversion.gramsPerOunce, isFlour: false, isExtra: false),
            ]
        ),
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://www.gimmesomeoven.com/1-hour-easy-cinnamon-rolls-recipe/",
                expectedName: "1-Hour Cinnamon Rolls",
                expectedIngredientCount: 16,
                expectedInstructionCount: 10
            ),
            expectedIngredientLines: [
                "3 to 3 1/2 cups all-purpose flour",
                "1 egg",
            ],
            expectedInstructionSnippets: [
                "Mix the dough.",
                "Make the icing.",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "All-Purpose Flour", weightGrams: 3.25 * IngredientDensityStore.shared.gramsPerCup(for: .allPurposeFlour), isFlour: true, isExtra: false),
                ExpectedResolvedIngredient(name: "Egg", weightGrams: IngredientDensityStore.shared.gramsPerEgg(for: IngredientDensityStore.shared.defaultEggSize()), isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Cream Cheese", weightGrams: 4 * UnitConversion.gramsPerOunce, isFlour: false, isExtra: false),
            ]
        ),
        DeepLiveRecipeCase(
            base: LiveRecipeCase(
                url: "https://cookieandkate.com/apple-carrot-muffins-recipe/",
                expectedName: "Apple & Carrot \"Superhero\" Muffins",
                expectedIngredientCount: 11,
                expectedInstructionCount: 5
            ),
            expectedIngredientLines: [
                "2 cups packed almond meal or almond flour (10 ounces)",
                "3 eggs",
                "6 tablespoons unsalted butter, melted",
            ],
            expectedInstructionSnippets: [
                "combine the almond meal",
                "whisk together the honey, eggs and butter",
            ],
            expectedResolvedIngredients: [
                ExpectedResolvedIngredient(name: "Almond Meal Or Almond Flour", weightGrams: 10 * UnitConversion.gramsPerOunce, isFlour: true, isExtra: false),
                ExpectedResolvedIngredient(name: "Eggs", weightGrams: 3 * IngredientDensityStore.shared.gramsPerEgg(for: IngredientDensityStore.shared.defaultEggSize()), isFlour: false, isExtra: false),
                ExpectedResolvedIngredient(name: "Unsalted Butter", weightGrams: 6 * IngredientDensityStore.shared.gramsPerCup(for: .butter) / 16, isFlour: false, isExtra: false),
            ]
        ),
    ]

    private static let popularRecipePages: [LiveRecipeCase] = [
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-banana-bread-recipe", expectedName: "100% Whole Wheat Banana Bread", expectedIngredientCount: 10, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-blueberry-muffins-recipe", expectedName: "100% Whole Wheat Blueberry Muffins", expectedIngredientCount: 11, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-bread-for-the-bread-machine-recipe", expectedName: "100% Whole Wheat Bread for the Bread Machine", expectedIngredientCount: 8, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-cinnamon-swirl-bread-recipe", expectedName: "100% Whole Wheat Cinnamon Swirl Bread", expectedIngredientCount: 16, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-graham-crackers-recipe", expectedName: "100% Whole Wheat Graham Crackers", expectedIngredientCount: 9, expectedInstructionCount: 11),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-hamburger-buns-recipe", expectedName: "100% Whole Wheat Hamburger Buns", expectedIngredientCount: 11, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-pain-de-mie-recipe", expectedName: "100% Whole Wheat Pain de Mie", expectedIngredientCount: 9, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-sandwich-bread-recipe", expectedName: "100% Whole Wheat Sandwich Bread", expectedIngredientCount: 10, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/100-whole-wheat-zucchini-chocolate-chip-bread-recipe", expectedName: "100% Whole Wheat Zucchini Chocolate Chip Bread", expectedIngredientCount: 13, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/3-ingredient-biscuits-made-with-all-purpose-baking-mix-recipe", expectedName: "3-Ingredient Biscuits made with All-Purpose Baking Mix", expectedIngredientCount: 3, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/3-ingredient-buttermilk-biscuits-recipe", expectedName: "3-Ingredient Buttermilk Biscuits", expectedIngredientCount: 5, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/5050-corn-and-flour-tortillas-recipe", expectedName: "50/50 Corn and Flour Tortillas", expectedIngredientCount: 6, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/9-grain-bread-recipe", expectedName: "9-Grain Bread", expectedIngredientCount: 6, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/a-dozen-simple-bagels-recipe", expectedName: "A Dozen Simple Bagels", expectedIngredientCount: 10, expectedInstructionCount: 11),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/a-few-of-my-favorite-things-casserole-recipe", expectedName: "A Few of My Favorite Things Casserole", expectedIngredientCount: 15, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.kingarthurbaking.com/recipes/a-simple-hummus-recipe", expectedName: "A Simple Hummus", expectedIngredientCount: 5, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/7_layer_bean_dip/", expectedName: "7 Layer Bean Dip", expectedIngredientCount: 12, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/african_chicken_peanut_stew/", expectedName: "African Chicken Peanut Stew", expectedIngredientCount: 14, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/agua_de_jamaica_hibiscus_tea/", expectedName: "Agua de Jamaica (Hibiscus Iced Tea)", expectedIngredientCount: 8, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/aioli/", expectedName: "Easy Aioli", expectedIngredientCount: 5, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_avocado_fries/", expectedName: "Air Fryer Avocado Fries", expectedIngredientCount: 10, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_chicken_wings/", expectedName: "Air Fryer Chicken Wings", expectedIngredientCount: 17, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_chinese_egg_rolls/", expectedName: "Air Fryer Egg Rolls", expectedIngredientCount: 14, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_crab_rangoon/", expectedName: "Air Fryer Crab Rangoon", expectedIngredientCount: 11, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_crispy_cauliflower/", expectedName: "Air Fryer Crispy Cauliflower", expectedIngredientCount: 13, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_falafel/", expectedName: "Air Fryer Falafel", expectedIngredientCount: 22, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_fried_chicken/", expectedName: "Air Fryer Fried Chicken", expectedIngredientCount: 11, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_mozzarella_sticks/", expectedName: "Air Fryer Mozzarella Sticks", expectedIngredientCount: 5, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/air_fryer_tostones/", expectedName: "Air Fryer Tostones", expectedIngredientCount: 8, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.simplyrecipes.com/recipes/albondigas_soup/", expectedName: "Albondigas Soup (Mexican Meatball Soup)", expectedIngredientCount: 19, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/9x13-inch-pan-brownie-recipe/", expectedName: "9x13-Inch Pan Brownie Recipe", expectedIngredientCount: 11, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/apple-pie-recipe/", expectedName: "My Best Apple Pie Recipe", expectedIngredientCount: 10, expectedInstructionCount: 11),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/best-banana-bread-recipe/", expectedName: "My Favorite Banana Bread", expectedIngredientCount: 11, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/bran-muffins-recipe/", expectedName: "Healthy Bran Muffins Recipe", expectedIngredientCount: 13, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/buttermilk-pancakes-recipe/", expectedName: "Buttermilk Pancakes", expectedIngredientCount: 9, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/ciabatta-bread-recipe/", expectedName: "Homemade Ciabatta Bread", expectedIngredientCount: 8, expectedInstructionCount: 13),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/coffee-cake-recipe/", expectedName: "Sour Cream Coffee Cake (with Crumb Topping)", expectedIngredientCount: 17, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/cornbread-muffins-recipe/", expectedName: "Cornbread Muffins", expectedIngredientCount: 12, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/dirt-pudding-recipe/", expectedName: "Homemade Dirt Pudding Recipe", expectedIngredientCount: 9, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/double-chocolate-chip-cookies-recipe/", expectedName: "Favorite Double Chocolate Chip Cookies Recipe", expectedIngredientCount: 11, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/dutch-baby-pancake-recipe/", expectedName: "Dutch Baby Pancake Recipe", expectedIngredientCount: 10, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://sallysbakingaddiction.com/egg-muffins-recipe/", expectedName: "Breakfast Egg Muffins (Frittata Muffins)", expectedIngredientCount: 11, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://cookieandkate.com/7-layer-dip-recipe/", expectedName: "7-Layer Dip", expectedIngredientCount: 13, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://cookieandkate.com/aguas-frescas-recipe/", expectedName: "How to Make Aguas Frescas", expectedIngredientCount: 5, expectedInstructionCount: 2),
        LiveRecipeCase(url: "https://cookieandkate.com/aji-verde-recipe/", expectedName: "Aji Verde (Spicy Peruvian Green Sauce)", expectedIngredientCount: 7, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://cookieandkate.com/almond-flour-pancakes-recipe/", expectedName: "Almond Flour Pancakes", expectedIngredientCount: 11, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://cookieandkate.com/almond-sesame-soba-zoodles-recipe/", expectedName: "Almond-Sesame Soba Zoodles with Quick-Pickled Veggies", expectedIngredientCount: 15, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://cookieandkate.com/apple-carrot-muffins-recipe/", expectedName: "Apple & Carrot \"Superhero\" Muffins", expectedIngredientCount: 11, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://cookieandkate.com/apple-oatmeal-pancakes-recipe/", expectedName: "Apple Oatmeal Pancakes", expectedIngredientCount: 10, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://cookieandkate.com/apple-steel-cut-oatmeal-recipe/", expectedName: "Apple Steel-Cut Oatmeal", expectedIngredientCount: 7, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://cookieandkate.com/arrabbiata-sauce-recipe/", expectedName: "Arrabbiata Sauce", expectedIngredientCount: 6, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://cookieandkate.com/arugula-watermelon-salad-recipe/", expectedName: "Arugula & Watermelon Salad", expectedIngredientCount: 9, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.budgetbytes.com/banana-pudding-recipe/", expectedName: "Banana Pudding", expectedIngredientCount: 3, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.budgetbytes.com/french-dressing-recipe/", expectedName: "French Dressing Recipe", expectedIngredientCount: 8, expectedInstructionCount: 1),
        LiveRecipeCase(url: "https://www.budgetbytes.com/overnight-oats-base-recipe-plus-variations/", expectedName: "Overnight Oats (Base Recipe plus Variations)", expectedIngredientCount: 18, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.budgetbytes.com/philly-cheesesteak-recipe/", expectedName: "Philly Cheesesteak Recipe", expectedIngredientCount: 12, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.budgetbytes.com/roasted-turkey-breast-recipe/", expectedName: "Roasted Turkey Breast Recipe", expectedIngredientCount: 8, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.budgetbytes.com/teriyaki-salmon-recipe/", expectedName: "Teriyaki Salmon with Sriracha Mayo", expectedIngredientCount: 11, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.budgetbytes.com/tuna-pasta-salad-recipe/", expectedName: "Classic Tuna Pasta Salad", expectedIngredientCount: 9, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.budgetbytes.com/15-minute-vegetable-curry/", expectedName: "15-Minute Vegetable Curry", expectedIngredientCount: 6, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-blueberry-breakfast-bars-cookbook-recipe-from-wholegrain-mornings-200030", expectedName: "Recipe: Blueberry Breakfast Bars", expectedIngredientCount: 18, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-cuban-meaty-potato-stuffing-recipe-237612", expectedName: "Recipe: Cuban Meaty Potato Stuffing", expectedIngredientCount: 19, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-flat-bread-with-dried-figs-roquefort-cheese-and-rosemary-cookbook-recipe-from-mediterranean-vegetarian-feasts-212824", expectedName: "Recipe: Flat Bread with Dried Figs, Roquefort Cheese, and Rosemary", expectedIngredientCount: 13, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-howto-make-the-perfect-summer-cocktaillimoncello-gin-cocktail-recipe-10-minute-happy-hour-191022", expectedName: "Limoncello Gin Cocktail", expectedIngredientCount: 5, expectedInstructionCount: 1),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-perfect-orange-margarita-recipe-which-is-your-fave-triple-sec-cointreau-citronge-or-housemade-10-minute-happy-hour-187663", expectedName: "Spring Cocktail Recipe: The Perfect Orange-y Margarita", expectedIngredientCount: 6, expectedInstructionCount: 2),
        LiveRecipeCase(url: "https://www.thekitchn.com/recipe-savory-bread-pudding-with-spinach-chevre-smoked-ham-and-smoky-roasted-red-pepper-sauce-recipe-181996", expectedName: "Recipe: Savory Bread Pudding with Spinach, Chèvre, Smoked Ham &Smoky Roasted Red Pepper Sauce", expectedIngredientCount: 16, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/copycat-recipe-chipotle-mexican-grills-chipotle-honey-vinaigrette.html", expectedName: "Chipotle Honey Vinaigrette", expectedIngredientCount: 9, expectedInstructionCount: 1),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/15-minute-chocolate-walnut-fudge.html", expectedName: "Easy Chocolate Fudge Recipe", expectedIngredientCount: 7, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/7-layer-dip.html", expectedName: "7 Layer Dip", expectedIngredientCount: 16, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/a-better-macaroni-salad.html", expectedName: "Macaroni Salad", expectedIngredientCount: 15, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/a-really-good-tuna-salad.html", expectedName: "A Really Good Tuna Salad", expectedIngredientCount: 10, expectedInstructionCount: 1),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/affogato.html", expectedName: "Affogato", expectedIngredientCount: 5, expectedInstructionCount: 1),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/albondigas-soup-mexican-meatball-soup.html", expectedName: "Albondigas Soup", expectedIngredientCount: 22, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/albondigas.html", expectedName: "Albóndigas in Chipotle Tomato Sauce", expectedIngredientCount: 17, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/all-american-potato-salad.html", expectedName: "All-American Potato Salad", expectedIngredientCount: 12, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.onceuponachef.com/recipes/almond-cookies.html", expectedName: "Almond Cookies", expectedIngredientCount: 7, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://natashaskitchen.com/7-layer-dip-recipe/", expectedName: "7-Layer Dip Recipe", expectedIngredientCount: 9, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://natashaskitchen.com/air-fryer-pork-chops-recipe/", expectedName: "Air Fryer Pork Chops", expectedIngredientCount: 8, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://natashaskitchen.com/almond-cake-recipe/", expectedName: "Almond Cake", expectedIngredientCount: 6, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://natashaskitchen.com/almond-nutella-cake-recipe/", expectedName: "Almond Nutella Cake Recipe", expectedIngredientCount: 11, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://natashaskitchen.com/almond-snowball-cookies-recipe/", expectedName: "Almond Snowball Cookies Recipe", expectedIngredientCount: 7, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://natashaskitchen.com/american-goulash-recipe/", expectedName: "American Goulash Recipe", expectedIngredientCount: 17, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://natashaskitchen.com/angelinas-easy-bread-kvas-recipe/", expectedName: "Easy Bread Kvas Recipe", expectedIngredientCount: 6, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://natashaskitchen.com/apple-bread-recipe/", expectedName: "Pull-Apart Apple Bread Recipe", expectedIngredientCount: 17, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.recipetineats.com/8-minute-lebanese-pizza-chicken-mince-recipe/", expectedName: "8 minute Lebanese Pizzas (Lahmacun!)", expectedIngredientCount: 15, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.recipetineats.com/apple-pie-recipe/", expectedName: "My Perfect Apple Pie", expectedIngredientCount: 11, expectedInstructionCount: 23),
        LiveRecipeCase(url: "https://www.recipetineats.com/asian-glazed-baked-barramundi-recipe/", expectedName: "Asian Glazed Baked Barramundi (or other fish)", expectedIngredientCount: 16, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.recipetineats.com/asian-mushroom-ramen-noodle-recipe/", expectedName: "Asian Mushroom Ramen Noodles", expectedIngredientCount: 11, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.recipetineats.com/banana-bread-recipe/", expectedName: "JB's Banana Bread", expectedIngredientCount: 12, expectedInstructionCount: 11),
        LiveRecipeCase(url: "https://www.recipetineats.com/beef-lentil-soup-beef-mince-recipe/", expectedName: "Beef & Lentil Soup with vegetables", expectedIngredientCount: 20, expectedInstructionCount: 8),
        LiveRecipeCase(url: "https://www.recipetineats.com/best-stuffing-recipe/", expectedName: "Sausage Stuffing!", expectedIngredientCount: 14, expectedInstructionCount: 9),
        LiveRecipeCase(url: "https://www.recipetineats.com/beurre-blanc-sauce-recipe/", expectedName: "Beurre Blanc Sauce", expectedIngredientCount: 6, expectedInstructionCount: 7),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/1-hour-easy-cinnamon-rolls-recipe/", expectedName: "1-Hour Cinnamon Rolls", expectedIngredientCount: 16, expectedInstructionCount: 10),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/15-minute-skinny-shrimp-scampi-recipe/", expectedName: "Skinny Shrimp Scampi", expectedIngredientCount: 13, expectedInstructionCount: 4),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/2-ingredient-slow-cooker-salsa-chicken-recipe/", expectedName: "2-Ingredient Slow Cooker Salsa Chicken", expectedIngredientCount: 4, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/20-minute-tomato-soup-recipe/", expectedName: "20-Minute Tomato Soup", expectedIngredientCount: 9, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/3-ingredient-coconut-oil-biscuits-recipe/", expectedName: "3-Ingredient Coconut Oil Biscuits", expectedIngredientCount: 3, expectedInstructionCount: 5),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/3-ingredient-nutella-croissants-recipe/", expectedName: "3-Ingredient Nutella Croissants", expectedIngredientCount: 3, expectedInstructionCount: 6),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/4-ingredient-slow-cooker-salsa-verde-chicken-recipe/", expectedName: "4-Ingredient Slow Cooker Salsa Verde Chicken", expectedIngredientCount: 6, expectedInstructionCount: 3),
        LiveRecipeCase(url: "https://www.gimmesomeoven.com/5-ingredient-bacon-asparagus-pasta-recipe/", expectedName: "5-Ingredient Bacon Asparagus Pasta", expectedIngredientCount: 5, expectedInstructionCount: 4),
    ]
}
