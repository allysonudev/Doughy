//
//  SettingsView.swift
//  Doughy

import SwiftUI

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedTemp: Temperature.Measurement = Settings.shared.preferredTemp()
    @State private var tempUpdateError: String?

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    var body: some View {
        Form {
            Section {
                Picker("Temperature Unit", selection: $selectedTemp) {
                    Text("Fahrenheit").tag(Temperature.Measurement.fahrenheit)
                    Text("Celsius").tag(Temperature.Measurement.celsius)
                }
                .onChange(of: selectedTemp) { old, new in
                    if old != new {
                        Settings.shared.setPreferredTemp(measurement: new)
                        do {
                            try Settings.shared.updateRecipeTemps(original: old, target: new)
                            store.refresh()
                        } catch {
                            tempUpdateError = String(localized: "settings.error.convert_temperatures", defaultValue: "Could not convert recipe temperatures.")
                            selectedTemp = old
                        }
                    }
                }
            }

            Section {
                NavigationLink("Ingredient Conversions") {
                    IngredientConversionsView()
                }
                .accessibilityIdentifier("ingredientConversionsLink")
            } footer: {
                Text("Adjust the gram conversions Doughy uses for cup, tablespoon, and teaspoon measurements when scanning recipes.")
            }

            Section("About") {
                Link("Source Code on GitHub",
                     destination: URL(string: "https://github.com/georgie-codes/Doughy")!)
                Link(destination: URL(string: "https://www.feedingamerica.org/find-your-local-foodbank")!) {
                    VStack(alignment: .leading) {
                        Text("Donate to your local food bank.")
                        Text("Go to feedingamerica.org")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Link("Send Feedback",
                     destination: URL(string: "mailto:doughyapp@icloud.com")!)
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Error", isPresented: Binding(
            get: { tempUpdateError != nil },
            set: { if !$0 { tempUpdateError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tempUpdateError ?? "")
        }
    }
}
