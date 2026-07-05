# Plan: Fermentation Planner (rise-time estimates)

## Summary of the feature

Add a fermentation planning surface that helps users reason from time and temperature, not only baker's percentages. The app could estimate how long a dough or preferment may take to mature, or solve for an adjusted yeast/starter amount when the user wants dough ready at a specific time.

This should be framed as an estimate with a confidence range, not a promise. Fermentation depends on flour, dough temperature, inoculation, hydration, salt, sugar, fat, starter health, handling, container shape, and what the user means by "ready."

## Problem

Doughy currently helps users scale and adjust recipes from chosen formulas. In practice, many bakers plan from schedule constraints:

- "I want this dough ready after work."
- "My kitchen is 68 degrees F today."
- "Can I use less yeast and let this poolish go overnight?"
- "How much starter would I need for a same-day dough?"

A simple planner could make the app feel more practical without turning it into a laboratory model.

## Modeling approach

There is no single universal equation for dough maturity, but a useful first approximation can combine inoculation and temperature.

Commercial yeast and preferments can start with a rate model:

```text
fermentationRate ~= inoculation * temperatureFactor * doughModifiers
timeToTarget ~= targetFermentation / fermentationRate
```

A common way to model temperature sensitivity is a Q10-style adjustment:

```text
temperatureFactor = q10 ^ ((doughTemperatureC - referenceTemperatureC) / 10)

adjustedTimeHours = referenceTimeHours
    * (referenceInoculationPercent / targetInoculationPercent)
    * q10 ^ ((referenceTemperatureC - doughTemperatureC) / 10)
```

Notes:

- The model should use dough temperature internally when available.
- Ambient temperature can be a fallback, but dough temperature lags ambient temperature.
- UI can show the user's preferred temperature unit even if the model stores Celsius.
- Q10 should likely default somewhere in the 2.0 to 3.0 range, then become adjustable or calibrated later.
- Hydration, salt, sugar, and fat can be modifiers after the first version.

## MVP scope

Start with commercial yeast doughs and commercial-yeast preferments:

- Straight dough
- Poolish
- Biga

Inputs:

- Desired ready time or desired fermentation duration
- Ambient or dough temperature
- Yeast type and current baker's percentage
- Recipe flour weight
- Preferment type and hydration, when applicable
- Optional modifiers for salt, sugar, fat, and hydration

Outputs:

- Estimated maturity window
- Suggested yeast percentage, if solving for a ready time
- Timeline hint, such as mix, bulk, divide, proof, bake
- Warnings when values are likely unreliable
- Visual signs to watch for

Planner modes:

- "How long will this take?"
- "Make this ready at..."

## Sourdough scope

Sourdough should probably come later because starter activity varies too much for a generic equation to be trustworthy.

A sourdough version should use calibration:

- Starter doubles in X hours at Y temperature after a known feeding ratio.
- This dough bulked in X hours at Y temperature with a known starter percentage.
- User stores one or more starter profiles.

The app could then estimate from the user's starter behavior instead of pretending all starters perform the same.

## UX concept

Add a fermentation planner sheet or card from create/edit and calculator-style surfaces.

Controls:

- Ready-time slider or date/time picker
- Temperature slider/input
- Toggle between estimating time and solving for yeast/starter amount
- Optional advanced controls for hydration, salt, sugar, fat, and preferment percentage

Display:

- Show a time range rather than a single exact time.
- Show confidence as plain language, for example "rough estimate" or "calibrated."
- Explain important watch cues without making the screen text-heavy.

Useful watch cues:

- Bulk dough: target volume increase, bubbles, jiggle, strength
- Poolish: domed surface, bubbles, possible slight recession at peak
- Biga: expanded, aerated, aromatic, not collapsed
- Final proof: dough expansion and poke-test behavior

Warnings:

- Very cold or very warm fermentation temperatures
- Extremely low or high yeast percentages
- Enriched doughs with high sugar or fat
- Heavy salt or unusual hydration
- Sourdough estimates without calibration

## Data model sketch

The first version can be non-persistent and calculator-like. A later version could attach an optional fermentation profile to a recipe.

```swift
struct FermentationProfile: Codable, Equatable {
    var target: FermentationTarget
    var referenceTemperatureC: Double
    var referenceInoculationPercent: Double
    var referenceTimeHours: Double
    var q10: Double
    var calibrationNotes: String?
}

enum FermentationTarget: Codable, Equatable {
    case straightDoughBulk
    case finalProof
    case poolishPeak
    case bigaMature
    case sourdoughBulk
}
```

Android should get the same behavior with native Kotlin models once the feature moves past design.

## Open questions

- Which maturity target should the planner optimize first: bulk readiness, final proof, preferment peak, flavor, or acidity?
- Should the first slider only adjust commercial yeast?
- How should the UI distinguish ambient temperature from dough temperature or desired dough temperature?
- Should starter calibration live in Settings, recipe details, or both?
- How wide should the estimated time range be before the output stops feeling useful?
- Should planner values ever mutate the recipe formula automatically, or should they stay as suggestions until accepted?

## Implementation phases

1. Design note and internal model research.
2. Add a local calculator helper for commercial yeast timing, with tests around the Q10 and inoculation math.
3. Add a UI prototype for straight dough and simple preferments.
4. Add optional recipe-linked fermentation profiles and reminders.
5. Add sourdough starter calibration and per-user adjustment.
6. Bring the same feature to Android with the same model behavior and Android-native UI.
