//
//  DefaultRecipeFactory.swift
//  Doughy
//
//  Created by urickg on 3/21/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class DefaultRecipeFactory: NSObject {

    enum Key {
        static let neopolitanPizza    = "default_recipe_neopolitan_pizza"
        static let newYorkPizza       = "default_recipe_new_york_pizza"
        static let bagels             = "default_recipe_bagels"
        static let bagelsWithPoolish  = "default_recipe_bagels_with_poolish"

        static let byStoredName: [String: String] = [
            "Neapolitan Pizza":    neopolitanPizza,  // current spelling
            "Neopolitan Pizza":    neopolitanPizza,  // 1.0 legacy alias
            "New York Pizza":      newYorkPizza,
            "Bagels":              bagels,
            "Bagels With Poolish": bagelsWithPoolish,
        ]
    }

    private let objectFactory = ObjectFactory.shared
    private let tempConverter = TemperatureConverter.shared

    static let shared = DefaultRecipeFactory()

    private override init() { }

    func createWithKeys() -> [(recipe: RecipeProtocol, key: String)] {
        return [
            (createNeapolitan(),     Key.neopolitanPizza),
            (createNewYorkPizza(),   Key.newYorkPizza),
            (createBagel(),          Key.bagels),
            (createBagelWithPoolish(), Key.bagelsWithPoolish),
        ]
    }

    func create() -> [RecipeProtocol] {
        return createWithKeys().map { $0.recipe }
    }
    
    private func createNeapolitan() -> Recipe {
        
        let flour = Ingredient(name: "Tipo 00 Flour", isFlour: true, defaultPercentage: 100, temperature: nil)
        
        let waterTemp = Temperature(value: 90, measurement: .fahrenheit)
        let water = Ingredient(name: "Water", isFlour: false, defaultPercentage: 60, temperature: waterTemp)
        
        let salt = Ingredient(name: "Fine Sea Salt", isFlour: false, defaultPercentage: 3, temperature: nil)
        
        let yeast = Ingredient(name: "Instant Yeast", isFlour: false, defaultPercentage: 0.05, temperature: nil)
        
        let ingredients = [flour, water, salt, yeast]
        
        var instructions = [Instruction]()
        
        instructions.append(Instruction(step:
                "Mix all the ingredients.\nAdd water to the mixing bowl. Add yeast to the water and stir until combined. You can let it sit for 10 minutes to proof or move to the next step if you trust your yeast. Then add the flour. Use your hands to combine the ingredients together until fully incorporated. The doughy will be  kind of sticky and won't be smooth yet. Add the salt and incorporate it into the dough until fully mixed up. Should only take about 30 seconds. Cover the mixing bowl with a cloth."))
        instructions.append(Instruction(step:
            "Stretch and fold.\nLet the dough rest for 30 minutes. Then begin your stretch and folds. Remove the cloth. Wet your hands and loosen the dough from the sides. Making sure to keep your hands damp (not dripping, this will add hydration to the dough), grab one edge of the dough. Lift it as far as it will go without tearing (make sure it doesn't tear) and fold it into the center. Turn the bowl and repeat this until you come back to the first spot you folded. Repeat 30 minute rest and stretch and fold 3-4 times until your dough can be stretched so thin, you can see light through it. This is called the window pane test."))
        instructions.append(Instruction(step:
            "Bulk ferment.\nLet the dough sit out on the counter for 8-18 hours, depending on the temperature of the room. What you're looking for is that the dough has doubled in size. Because of the small amount of yeast, it will take a long time to rise. This is a good thing because it lets the yeast release more gas, which helps with flavor. If you find your dough is getting to 2x size too quickly, you can move it to a colder part of the house, or consider moving it to the fridge (for up to 24 hours, long than that in bulk ferment will mean the flour might start to break down if you're using 00 flour. Bread flour can last longer)."))
        instructions.append(Instruction(step:
            "Divide and shape into balls.\n Search on youtube and pick a video to help learn to shape the dough balls. https://www.youtube.com/results?search_query=how+to+shape+pizza+dough+balls It's very difficult to describe by text.  \nIf you just need a refresher, here you go. Dump the mass onto an unfloured counter. Divide the dough into preferred dough ball size. About 270 for a 10 inch pizza. Fold the edges into the center and flip it over. Take your hands and cup around the back of the pizza with pinkies touching and pull the ball toward you. The friction of the counter will cause the front of the dough to tighten into the center. Turn the dough 90º and repeat until the ball is tight and smooth.\nPlace all the dough balls into a tray to proof."))
        instructions.append(Instruction(step:
            "Proof the dough for between 2 and 8 hours at room temperature or 24 hours in the refrigerator."))
        instructions.append(Instruction(step:
            "Shape your pizza.\nThis is again something that is best explained by video. Vito Iacopelli is an excentric pizzaioli who has hundreds of videos on Pizza. Here's his shaping video https://www.youtube.com/watch?v=h75bxDwT1Ko"))
        instructions.append(Instruction(step:
            "Cook at the hottest temperature you can. For home, cook on a baking steel which has been preheated to 500ºF or more for 1 hour. For browning, you can turn on your broiler for the last 2 minutes. You should be able to cook in about 5-8 minutes depending on your surface (stone transfers heat slower than steel) and oven temperature. A wood or gas-fired oven is best. You can cook at 932º F in about 60-90 seconds."))
        
        let name = "Neapolitan Pizza"
        let collection = "Pizza"
        let defaultWeight = 270.0
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight, ingredients: ingredients, instructions: instructions)
    }
    
    private func createNewYorkPizza() -> Recipe {
        
        let flour = Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil)
        
        let waterTemp = Temperature(value: 90, measurement: .fahrenheit)
        let water = Ingredient(name: "Water", isFlour: false, defaultPercentage: 62, temperature: waterTemp)
        let salt = Ingredient(name: "Fine Sea Salt", isFlour: false, defaultPercentage: 2, temperature: nil)
        let yeast = Ingredient(name: "Instant Yeast", isFlour: false, defaultPercentage: 0.75, temperature: nil)
        let oliveOil = Ingredient(name: "Olive Oil", isFlour: false, defaultPercentage: 3, temperature: nil)
        let sugar = Ingredient(name: "Sugar", isFlour: false, defaultPercentage: 2.6, temperature: nil)
        let ingredients = [flour, water, salt, yeast, oliveOil, sugar]
        
        var instructions = [Instruction]()
        
        instructions.append(Instruction(step:
                "Mix all the ingredients.\nAdd water to the mixing bowl. Add yeast to the water and stir until combined. You can let it sit for 10 minutes to proof or move to the next step if you trust your yeast. Then add the flour. Use your hands to combine the ingredients together until fully incorporated. The doughy will be  kind of sticky and won't be smooth yet. Add the salt and incorporate it into the dough until fully mixed up. Should only take about 30 seconds. Cover the mixing bowl with a cloth."))
        instructions.append(Instruction(step:
            "Put the dough out onto the counter. Knead the dough for about 2-3 minutes. Then rest the dough into mixing bowl for about 15 minutes. Knead the dough for another 2-3 minutes. By now, the dough should be smooth and you should be able to stretch it so thin, you can see light through it. This is called the window pane test."))
        instructions.append(Instruction(step:
            "Bulk ferment.\nLet the dough sit out on the counter for 2-3 hours, depending on the temperature of the room. What you're looking for is that the dough has doubled in size. If you find your dough is getting to 2x size too quickly, you can move it to a colder part of the house. You can also bulk ferment in the refrigerator for 24 hours to give it a longer rise, which improves the flavor."))
        instructions.append(Instruction(step:
            "Divide and shape into balls.\n Search on youtube and pick a video to help learn to shape the dough balls. https://www.youtube.com/results?search_query=how+to+shape+pizza+dough+balls It's very difficult to describe by text.  \nIf you just need a refresher, here you go. Dump the mass onto an unfloured counter. Divide the dough into preferred dough ball size. About 270 for a 10 inch pizza. Fold the edges into the center and flip it over. Take your hands and cup around the back of the pizza with pinkies touching and pull the ball toward you. The friction of the counter will cause the front of the dough to tighten into the center. Turn the dough 90º and repeat until the ball is tight and smooth.\nPlace all the dough balls into a tray to proof."))
        instructions.append(Instruction(step:
            "Proof the dough for between 2 and 8 hours at room temperature or 24 hours in the refrigerator."))
        instructions.append(Instruction(step:
            "Shape your pizza.\nThis is again something that is best explained by video. Pagliacci is a Seattle-based pizza chain that made a few videos a few years ago. They don't make NY style pizza, but their shaping instructions are great. Here's their hand-tossed shaping video https://www.youtube.com/watch?v=VIJlRXMfW50"))
        instructions.append(Instruction(step:
            "Cook at the hottest temperature you can. For home, cook on a baking steel which has been preheated to 500ºF or more for 1 hour. For browning, you can turn on your broiler for the last 2 minutes. You should be able to cook in about 5-8 minutes depending on your surface (stone transfers heat slower than steel) and oven temperature. A gas-fired oven is considered authentic to NY but wood-fired ovens will work as well. You can cook at 750º F in about 3-4 minutes."))
        
        let name = "New York Pizza"
        let collection = "Pizza"
        let defaultWeight = 305.0
        
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight, ingredients: ingredients, instructions: instructions)
    }
    private func createBagel() -> Recipe {
        
        let flour = Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil)
        
        let waterTemp = Temperature(value: 95, measurement: .fahrenheit)
        let water = Ingredient(name: "Water", isFlour: false, defaultPercentage: 56, temperature: waterTemp)
        let salt = Ingredient(name: "Fine Sea Salt", isFlour: false, defaultPercentage: 2.3, temperature: nil)
        let yeast = Ingredient(name: "Instant Yeast", isFlour: false, defaultPercentage: 0.66, temperature: nil)
        let malt = Ingredient(name: "Non-Diastatic Malt", isFlour: false, defaultPercentage: 4.6, temperature: nil)
        let ingredients = [flour, water, salt, yeast, malt]

        var instructions = [Instruction]()

        instructions.append(Instruction(step:
                "Autolyse the flour and water.\nIn the bowl of a stand mixer, add the flour and water, leaving a small amount of water separate for the yeast. Mix just until combined. Let it rest for 20 minutes. After 10 minutes, combine the remaining water and the yeast to proof."))
        instructions.append(Instruction(step:
            "Mix the remaining ingredients.\nPour the yeast and water mixture into the mixing bowl. Add the malt powder or malt syrup into the bowl. Begin mixing on low-medium speed for 3 minutes. Then add the salt and continue mixing for another 7-12 minutes. The dough is ready when it's smooth and ideally it should pass the window pane test. You should be able to slowly stretch it so thin, you can see light through it. Once it's been mixed for 15 minutes, though, you don't want to mix any more."))
        instructions.append(Instruction(step:
            "Bulk ferment the dough.\nDump the dough on an unfloured work surface. Tighten the dough into a ball and place in a lightly-oiled bowl, seam-side down. Cover and let it rise for 1-1.5 hours, until it's doubled in size."))
        instructions.append(Instruction(step:
            "Divide and shape into balls.\nDivide the dough into 105-115 gram dough balls. Tighten them like you would a pizza, except these are much smaller. Let them rest for 10 minutes. To shape a bagel, you roll it out into a relatively round rectangle. Roll it up along the long side so you have a tube. Close up the seams by pinching, it doesn't have to be perfect Use the part of your hands above your palm to roll the tube and pull your hands apart to stretch out the tube until it's about 8 inches. Place that part of the hand on one end of the tube. Then grab it and with the other hand, grab the other end and wrap it around the knuckles. With the first hand, take both ends and squeeze them together. Roll this combined piece on the table to make it round and help close up the seams. Repeat this for all the bagels and place on a spray-oiled baking sheet. Wrap the baking sheet in plastic wrap and either let them proof for 1 hour, or rise in the fridge overnight."))
        instructions.append(Instruction(step:
            "Boil the bagels.\nPreheat the oven to 450º F. Then get the boiling water bath ready. You can use 2-3 quarts of water, 1 tbsp of baking soda, and 1.5 tbsp of malt syrup (not powder). Add the baking soda and malt syrup once the water is boiling. If you put the bagels in the fridge, make sure they have rest at room temp for 30-60 minutes before boiling. Boil the bagels in batches, making sure they aren't crowded. They should boil for 30-60 seconds per side and then removed to a drying rack so they can lose excess water. As soon as your done boiling all the bagels, get the desired toppings onto the bagels, such as everything seasoning, sesame seeds, dried garlic, or just flaky salt."))
        instructions.append(Instruction(step:
            "Bake the bagels.\nPlace the bagels into the oven on a baking sheet (or if you're fancy, you can bake these on a baking steel/stone). Baking at 450 for 16-18 minutes, turning the baking sheet 180º halfway through for even baking."))
        
        let name = "Bagels"
        let collection = "Bagels"
        let defaultWeight = 113.0
        
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight, ingredients: ingredients, instructions: instructions)
    }
    
    private func createBagelWithPoolish() -> PrefermentRecipe {
        
        let poolishFlour = Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil)
        let poolishWater = Ingredient(name: "Water", isFlour: false, defaultPercentage: 100, temperature: Temperature(value: 80.0, measurement: .fahrenheit))
        let poolishYeast = Ingredient(name: "Instant Yeast", isFlour: false, defaultPercentage: 0.5, temperature: nil)
        
        let poolish = Preferment(name: "Poolish", flourPercentage: 50, ingredients: [poolishFlour, poolishWater, poolishYeast])
        
        let flour = Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil)
        
        let waterTemp = Temperature(value: 95, measurement: .fahrenheit)
        let water = Ingredient(name: "Water", isFlour: false, defaultPercentage: 56, temperature: waterTemp)
        let salt = Ingredient(name: "Fine Sea Salt", isFlour: false, defaultPercentage: 2.3, temperature: nil)
        let yeast = Ingredient(name: "Instant Yeast", isFlour: false, defaultPercentage: 0.66, temperature: nil)
        let malt = Ingredient(name: "Non-Diastatic Malt", isFlour: false, defaultPercentage: 4.6, temperature: nil)
        let ingredients = [flour, water, salt, yeast, malt]

        var instructions = [Instruction]()

        instructions.append(Instruction(step:
        "Make the poolish.\nCombine all the poolish ingredients into a bowl. Use your fingers or the handle of a wooden spoon to incorporate completely. Let this ferment for 12-18 hours. It should smell really strong and be bubbly when it's ready."))
        instructions.append(Instruction(step:
            "Mix the ingredients.\nPut the remaining flour into the bowl of a stand mixer. Put the remaining water and yeast into the poolish to help it release from the bowl. Pour the poolish, yeast, and water mixture into the mixing bowl. Add the malt powder or malt syrup into the bowl. Begin mixing on low-medium speed for 3 minutes. Then add the salt and continue mixing for another 7-12 minutes. The dough is ready when it's smooth and ideally it should pass the window pane test. You should be able to slowly stretch it so thin, you can see light through it. Once it's been mixed for 15 minutes, though, you don't want to mix any more."))
        instructions.append(Instruction(step:
            "Bulk ferment the dough.\nDump the dough on an unfloured work surface. Tighten the dough into a ball and place in a lightly-oiled bowl, seam-side down. Cover and let it rise for 1-1.5 hours, until it's doubled in size."))
        instructions.append(Instruction(step:
            "Divide and shape into balls.\nDivide the dough into 105-115 gram dough balls. Tighten them like you would a pizza, except these are much smaller. Let them rest for 10 minutes. To shape a bagel, you roll it out into a relatively round rectangle. Roll it up along the long side so you have a tube. Close up the seams by pinching, it doesn't have to be perfect Use the part of your hands above your palm to roll the tube and pull your hands apart to stretch out the tube until it's about 8 inches. Place that part of the hand on one end of the tube. Then grab it and with the other hand, grab the other end and wrap it around the knuckles. With the first hand, take both ends and squeeze them together. Roll this combined piece on the table to make it round and help close up the seams. Repeat this for all the bagels and place on a spray-oiled baking sheet. Wrap the baking sheet in plastic wrap and either let them proof for 1 hour, or rise in the fridge overnight."))
        instructions.append(Instruction(step:
            "Boil the bagels.\nPreheat the oven to 450º F. Then get the boiling water bath ready. You can use 2-3 quarts of water, 1 tbsp of baking soda, and 1.5 tbsp of malt syrup (not powder). Add the baking soda and malt syrup once the water is boiling. If you put the bagels in the fridge, make sure they have rest at room temp for 30-60 minutes before boiling. Boil the bagels in batches, making sure they aren't crowded. They should boil for 30-60 seconds per side and then removed to a drying rack so they can lose excess water. As soon as your done boiling all the bagels, get the desired toppings onto the bagels, such as everything seasoning, sesame seeds, dried garlic, or just flaky salt."))
        instructions.append(Instruction(step:
            "Bake the bagels.\nPlace the bagels into the oven on a baking sheet (or if you're fancy, you can bake these on a baking steel/stone). Baking at 450 for 16-18 minutes, turning the baking sheet 180º halfway through for even baking."))
        
        let name = "Bagels With Poolish"
        let collection = "Bagels"
        let defaultWeight = 113.0
        
        return PrefermentRecipe(name: name, collection: collection, defaultWeight: defaultWeight, ingredients: ingredients, preferment: poolish, instructions: instructions)
    }

}
