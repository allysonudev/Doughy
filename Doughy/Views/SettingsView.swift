//
//  SettingsView.swift
//  Doughy

import SwiftUI

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @State private var prefersCelsius: Bool = Settings.shared.preferredTemp() == .celsius
    @State private var tempUpdateError: String?

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    var body: some View {
        Form {
            Section("Temperature Unit") {
                Toggle("Use Celsius", isOn: $prefersCelsius)
                    .onChange(of: prefersCelsius) { _, newValue in
                        let current = Settings.shared.preferredTemp()
                        let target: Temperature.Measurement = newValue ? .celsius : .fahrenheit
                        if current != target {
                            Settings.shared.setPreferredTemp(measurement: target)
                            do {
                                try Settings.shared.updateRecipeTemps(original: current, target: target)
                                store.refresh()
                            } catch {
                                tempUpdateError = "Could not convert recipe temperatures."
                                prefersCelsius = !newValue
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
