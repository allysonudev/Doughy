//
//  RecipeWebsiteImporterTests.swift
//  Doughy Tests
//

@testable import Doughy
import XCTest

final class RecipeWebsiteImporterTests: XCTestCase {
    private let sourceURL = URL(string: "https://example.com/focaccia")!

    func testParsesRecipeJSONLDAndResolvesIngredients() throws {
        let html = """
        <html>
        <head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Weekend Focaccia",
          "recipeIngredient": [
            "500 g bread flour",
            "375 g water",
            "10 g fine sea salt",
            "3/4 cup margarine",
            "2 large eggs"
          ],
          "recipeInstructions": [
            { "@type": "HowToStep", "text": "Mix the dough." },
            { "@type": "HowToStep", "text": "Bake until golden." }
          ]
        }
        </script>
        </head>
        </html>
        """

        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.name, "Weekend Focaccia")
        XCTAssertNotNil(draft.structuredRecipeJSON)
        XCTAssertTrue(draft.structuredRecipeJSON?.contains(#""name" : "Weekend Focaccia""#) == true)
        XCTAssertTrue(draft.structuredRecipeJSON?.contains(#""recipeIngredient""#) == true)
        XCTAssertEqual(draft.ingredientLines.count, 5)
        XCTAssertEqual(draft.instructions, ["Mix the dough.", "Bake until golden."])

        let flour = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Bread Flour" })
        XCTAssertTrue(flour.isFlour)
        XCTAssertEqual(flour.weightGrams, 500, accuracy: 0.001)

        let egg = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Large Eggs" })
        XCTAssertFalse(egg.isExtra)
        XCTAssertEqual(egg.weightGrams, 2 * IngredientDensityStore.shared.gramsPerEgg(for: .large), accuracy: 0.001)

        let margarine = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Margarine" })
        XCTAssertFalse(margarine.isExtra)
        XCTAssertEqual(margarine.weightGrams, 170.25, accuracy: 0.001)
    }

    func testFindsRecipeInsideGraph() throws {
        let html = """
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@graph": [
            { "@type": "BreadcrumbList", "name": "Breadcrumbs" },
            {
              "@type": ["Recipe"],
              "name": "Chocolate Babka",
              "recipeIngredient": ["4 cups bread flour", "1 cup milk"],
              "recipeInstructions": {
                "@type": "HowToSection",
                "itemListElement": [
                  { "@type": "HowToStep", "text": "Make the dough." }
                ]
              }
            }
          ]
        }
        </script>
        """

        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.name, "Chocolate Babka")
        XCTAssertEqual(draft.instructions, ["Make the dough."])
        XCTAssertTrue(draft.resolvedIngredients.contains { $0.name == "Bread Flour" && $0.isFlour })
    }

    func testDecodesNumericHTMLEntities() throws {
        let html = """
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Spinach &#038; Cheese Bread",
          "recipeIngredient": ["2 cups bread flour", "1 cup water"],
          "recipeInstructions": [
            { "@type": "HowToStep", "text": "Mix &#x26; bake." }
          ]
        }
        </script>
        """

        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.name, "Spinach & Cheese Bread")
        XCTAssertEqual(draft.instructions, ["Mix & bake."])
    }

    func testThrowsWhenNoStructuredRecipeDataExists() {
        let html = "<html><body><h1>No recipe here</h1></body></html>"

        XCTAssertThrowsError(try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)) { error in
            XCTAssertEqual(error as? WebsiteRecipeImportError, .noRecipeData)
        }
    }

    func testNormalizesUserEnteredURLs() {
        XCTAssertEqual(
            RecipeWebsiteImporter.normalizedURL(from: "example.com/recipe")?.absoluteString,
            "https://example.com/recipe"
        )
        XCTAssertEqual(
            RecipeWebsiteImporter.normalizedURL(from: "http://example.com/recipe")?.absoluteString,
            "http://example.com/recipe"
        )
        XCTAssertNil(RecipeWebsiteImporter.normalizedURL(from: "not a url"))
    }

    func testImportRequestParsesDeepLink() throws {
        let encoded = "https%3A%2F%2Fexample.com%2Frecipe"
        let url = URL(string: "doughy://import?url=\(encoded)")!

        let request = try XCTUnwrap(WebsiteRecipeImportRequest(incomingURL: url))

        XCTAssertEqual(request.url.absoluteString, "https://example.com/recipe")
    }

    // A line starting with a Unicode vulgar fraction must still strip the unit from the name
    // (regression: "¼ teaspoon cream of tartar" had been parsed as "Teaspoon Cream Of Tartar").
    func testVulgarFractionDoesNotLeaveUnitInIngredientName() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Macarons",
          "recipeIngredient": [
            "¼ teaspoon cream of tartar",
            "½ cup granulated sugar"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Whip." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)
        let names = draft.resolvedIngredients.map(\.name)
        XCTAssertTrue(names.contains("Cream Of Tartar"), "names: \(names)")
        XCTAssertTrue(names.contains("Granulated Sugar"), "names: \(names)")
        XCTAssertFalse(
            names.contains { $0.localizedCaseInsensitiveContains("teaspoon") || $0.localizedCaseInsensitiveContains("cup") },
            "unit leaked into a name: \(names)"
        )
    }

    func testStripsBrandAndMarketingPrefixFromIngredientName() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Bread",
          "recipeIngredient": [
            "1 cup (120g) King Arthur Unbleached All-Purpose Flour",
            "8 ounces cream cheese, softened",
            "2 cups almond meal or almond flour"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)
        let names = draft.resolvedIngredients.map(\.name)

        // Brand prefix and marketing descriptor both stripped.
        XCTAssertTrue(names.contains("All-Purpose Flour"), "names: \(names)")
        // A category-keyword match that's only a *substring* of a real compound ingredient
        // name (here "cream" inside "Cream Cheese") must not overwrite the name.
        XCTAssertTrue(names.contains("Cream Cheese"), "names: \(names)")
        XCTAssertTrue(names.contains("Almond Meal Or Almond Flour"), "names: \(names)")
    }

    func testDetectsPrefermentFromHTMLIngredientGroups() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Baguettes",
          "recipeIngredient": [
            "1/2 cup (113g) water, cool",
            "1 cup (120g) King Arthur Unbleached All-Purpose Flour*",
            "1 cup plus 2 tablespoons (255g) water, lukewarm",
            "all of the poolish",
            "3 1/2 cups (420g) King Arthur Unbleached All-Purpose Flour*",
            "2 teaspoons (12g) table salt"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head>
        <body>
        <div class="ingredients-list">
          <div class="ingredient-section">
            <p>Poolish</p>
            <ul class="list--bullets">
              <li>1/2 cup (113g) water, cool</li>
              <li>1 cup (120g) <a href="https://shop.example.com/flour" class="product-modal">King Arthur Unbleached All-Purpose Flour</a>*</li>
            </ul>
          </div>
          <div class="ingredient-section">
            <p>Dough</p>
            <ul class="list--bullets">
              <li>1 cup plus 2 tablespoons (255g) water, lukewarm</li>
              <li>all of the poolish</li>
              <li>3 1/2 cups (420g) <a href="https://shop.example.com/flour" class="product-modal">King Arthur Unbleached All-Purpose Flour</a>*</li>
              <li>2 teaspoons (12g) table salt</li>
            </ul>
          </div>
        </div>
        </body></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.prefermentName, "Poolish")
        // The "all of the poolish" back-reference is dropped entirely, not left behind as a
        // stray unresolved ingredient.
        XCTAssertTrue(draft.ignoredIngredientLines.contains("all of the poolish"))
        XCTAssertFalse(draft.resolvedIngredients.contains { $0.name.localizedCaseInsensitiveContains("poolish") })

        let preferment = draft.resolvedIngredients.filter(\.isPreferment)
        XCTAssertEqual(preferment.count, 2, "expected water + flour in the poolish: \(preferment)")
        XCTAssertEqual(preferment.first { $0.isFlour }?.weightGrams ?? 0, 120, accuracy: 0.01)

        let mainDough = draft.resolvedIngredients.filter { !$0.isPreferment }
        XCTAssertEqual(mainDough.count, 3, "expected water + flour + salt in the dough: \(mainDough)")
        XCTAssertEqual(mainDough.first { $0.isFlour }?.weightGrams ?? 0, 420, accuracy: 0.01)

        // Same ingredient name in both groups - this is exactly the scenario that used to
        // flatten into one list with duplicate names and crash RecipeDiff.
        let flourNames = Set(draft.resolvedIngredients.filter(\.isFlour).map(\.name))
        XCTAssertEqual(flourNames, ["All-Purpose Flour"])
    }

    func testDetectsPrefermentFromBackReferenceWhenNoHTMLGroupsPresent() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Simple Biga Bread",
          "recipeIngredient": [
            "1 cup (240g) water, cool",
            "2 cups (240g) bread flour",
            "all of the biga",
            "1 cup (240g) water, warm",
            "3 cups (360g) bread flour",
            "2 teaspoons (12g) salt"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.prefermentName, "Biga")
        XCTAssertTrue(draft.ignoredIngredientLines.contains("all of the biga"))

        let preferment = draft.resolvedIngredients.filter(\.isPreferment)
        XCTAssertEqual(preferment.count, 2)
        XCTAssertEqual(preferment.filter(\.isFlour).first?.weightGrams ?? 0, 240, accuracy: 0.01)

        let mainDough = draft.resolvedIngredients.filter { !$0.isPreferment }
        XCTAssertEqual(mainDough.filter(\.isFlour).first?.weightGrams ?? 0, 360, accuracy: 0.01)
    }

    // A real, measured preferment ingredient (has a gram amount) must never be mistaken for
    // a bare back-reference line just because it also mentions the preferment noun.
    func testRealMeasuredStarterIngredientIsNotTreatedAsBackReference() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Sourdough Loaf",
          "recipeIngredient": [
            "1/4 cup (60g) active sourdough starter, fed",
            "2 cups (240g) bread flour",
            "1 cup (240g) water"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertNil(draft.prefermentName)
        XCTAssertTrue(draft.ignoredIngredientLines.isEmpty)
        XCTAssertTrue(draft.resolvedIngredients.contains { $0.weightGrams == 60 })
    }

    func testDecodesFractionEntities() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Herb Focaccia",
          "recipeIngredient": [
            "500 g bread flour",
            "&frac12; cup olive oil"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertTrue(draft.ingredientLines.contains("½ cup olive oil"))
        let oil = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Olive Oil" })
        XCTAssertEqual(oil.weightGrams,
                       0.5 * IngredientDensityStore.shared.gramsPerCup(for: .oliveOil),
                       accuracy: 0.001)
    }

    func testSplitsSingleStringIngredientBlob() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Plain Loaf",
          "recipeIngredient": "500 g bread flour<br>320 g water<br/>10 g salt",
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.ingredientLines.count, 3)
        XCTAssertEqual(draft.resolvedIngredients.count, 3)
        let flour = try XCTUnwrap(draft.resolvedIngredients.first { $0.isFlour })
        XCTAssertEqual(flour.weightGrams, 500, accuracy: 0.001)
    }

    func testParsesEuropeanDecimalCommaAmounts() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Rúgbrauð",
          "recipeIngredient": [
            "1,000 g rye flour",
            "1,5 dl water"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        let flour = try XCTUnwrap(draft.resolvedIngredients.first { $0.isFlour })
        XCTAssertEqual(flour.weightGrams, 1000, accuracy: 0.001)

        // 1,5 dl is 1.5 deciliters, not 15 — the decimal comma must not be
        // treated as a thousands separator.
        let water = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Water" })
        let expected = (1.5 / 2.36588) * IngredientDensityStore.shared.gramsPerCup(for: .water)
        XCTAssertEqual(water.weightGrams, expected, accuracy: 0.01)
    }

    func testMultiPackageYeastUsesPackageCount() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Dinner Rolls",
          "recipeIngredient": [
            "500 g all-purpose flour",
            "2 packages active dry yeast"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        let yeast = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Active Dry Yeast" })
        XCTAssertEqual(yeast.weightGrams, 14, accuracy: 0.001)
    }

    func testPlusAsideAmountsDoNotBecomeTheWeight() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Boule",
          "recipeIngredient": [
            "4 cups bread flour, plus 30 g for dusting",
            "300 g water"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        // The flour must resolve from its 4-cup amount, not the 30 g dusting aside.
        let flour = try XCTUnwrap(draft.resolvedIngredients.first { $0.isFlour })
        XCTAssertEqual(flour.weightGrams,
                       4 * IngredientDensityStore.shared.gramsPerCup(for: .breadFlour),
                       accuracy: 0.001)
    }

    // Older blogs and WordPress recipe plugins mark recipes up with microdata
    // attributes instead of JSON-LD. Covers nested spans inside an ingredient span
    // (balanced-tag scanning), meta/content values, and the legacy "ingredients" prop.
    func testParsesMicrodataRecipeWhenNoJSONLDExists() throws {
        let html = """
        <html><body>
        <div itemscope itemtype="https://schema.org/Recipe">
          <h2 itemprop="name">Rustic Boule</h2>
          <ul>
            <li itemprop="recipeIngredient"><span class="amount">500 g</span> <span class="name">bread flour</span></li>
            <li itemprop="recipeIngredient">350 g water</li>
            <span itemprop="recipeIngredient"><span class="amount">10 g</span> salt</span>
            <meta itemprop="recipeIngredient" content="7 g instant yeast">
            <li itemprop="ingredients">5 g sugar</li>
          </ul>
          <div itemprop="recipeInstructions"><p>Mix everything.</p><p>Bake until golden.</p></div>
        </div>
        </body></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.name, "Rustic Boule")
        XCTAssertEqual(draft.ingredientLines.count, 5)
        XCTAssertTrue(draft.ingredientLines.contains("10 g salt"))
        XCTAssertEqual(draft.instructions, ["Mix everything.", "Bake until golden."])

        let flour = try XCTUnwrap(draft.resolvedIngredients.first { $0.isFlour })
        XCTAssertEqual(flour.weightGrams, 500, accuracy: 0.001)
        XCTAssertTrue(draft.resolvedIngredients.contains { $0.name == "Instant Yeast" && $0.weightGrams == 7 })
        XCTAssertTrue(draft.resolvedIngredients.contains { $0.name == "Sugar" && $0.weightGrams == 5 })
    }

    func testTangzhongBackReferenceGroupsPreferment() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Milk Bread",
          "recipeIngredient": [
            "25 g bread flour",
            "120 g whole milk",
            "all of the tangzhong",
            "350 g bread flour",
            "7 g salt"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        XCTAssertEqual(draft.prefermentName, "Tangzhong")
        XCTAssertTrue(draft.ignoredIngredientLines.contains("all of the tangzhong"))
        XCTAssertEqual(draft.resolvedIngredients.filter(\.isPreferment).count, 2)
    }

    func testFluidOuncesResolveAsVolumeNotMass() throws {
        let html = """
        <html><head>
        <script type="application/ld+json">
        {
          "@context": "https://schema.org",
          "@type": "Recipe",
          "name": "Soft Rolls",
          "recipeIngredient": [
            "500 g bread flour",
            "8 fl oz whole milk"
          ],
          "recipeInstructions": [ { "@type": "HowToStep", "text": "Mix." } ]
        }
        </script>
        </head></html>
        """
        let draft = try RecipeWebsiteImporter.parse(html: html, sourceURL: sourceURL)

        // 8 fl oz is exactly one US cup, so the milk must weigh one cup's worth —
        // a density conversion, not the 8 × 28.35 g a mass-ounce reading would give.
        let milk = try XCTUnwrap(draft.resolvedIngredients.first { $0.name == "Whole Milk" })
        XCTAssertFalse(milk.isExtra)
        XCTAssertEqual(milk.weightGrams,
                       IngredientDensityStore.shared.gramsPerCup(for: .milk),
                       accuracy: 0.01)
    }
}
