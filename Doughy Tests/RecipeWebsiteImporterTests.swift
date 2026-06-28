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
}
