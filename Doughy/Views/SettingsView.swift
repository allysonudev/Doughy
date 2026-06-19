//
//  SettingsView.swift
//  Doughy

import SwiftUI

private struct AppLanguage: Identifiable {
    let code: String
    let nativeName: String
    var id: String { code }

    static let all: [AppLanguage] = [
        .init(code: "de",    nativeName: "Deutsch"),
        .init(code: "en",    nativeName: "English"),
        .init(code: "es",    nativeName: "Español"),
        .init(code: "fr",    nativeName: "Français"),
        .init(code: "is",    nativeName: "Íslenska"),
        .init(code: "it",    nativeName: "Italiano"),
        .init(code: "ja",    nativeName: "日本語"),
        .init(code: "ko",    nativeName: "한국어"),
        .init(code: "pt-BR", nativeName: "Português (Brasil)"),
    ]
}

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedTemp: Temperature.Measurement = Settings.shared.preferredTemp()
    @State private var selectedVolumeSystem: VolumeSystem = Settings.shared.preferredVolumeSystem()
    @State private var selectedLanguage: String = Settings.shared.preferredLanguageCode() ?? ""
    @State private var tempUpdateError: String?
    @State private var showRestartAlert = false

    private var isUSRegion: Bool {
        Locale.current.region?.identifier == "US"
    }

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

                Picker("Volume Units", selection: $selectedVolumeSystem) {
                    Text("Metric").tag(VolumeSystem.metric)
                    Text("Imperial").tag(VolumeSystem.imperial)
                }
                .onChange(of: selectedVolumeSystem) { _, new in
                    Settings.shared.setPreferredVolumeSystem(new)
                }

                Picker("Language", selection: $selectedLanguage) {
                    Text("System Default").tag("")
                    ForEach(AppLanguage.all) { lang in
                        Text(lang.nativeName).tag(lang.code)
                    }
                }
                .onChange(of: selectedLanguage) { _, new in
                    Settings.shared.setPreferredLanguageCode(new.isEmpty ? nil : new)
                    showRestartAlert = true
                }
            }

            Section {
                NavigationLink(String(localized: "conversions.title", defaultValue: "Ingredient Conversions")) {
                    IngredientConversionsView()
                }
                .accessibilityIdentifier("ingredientConversionsLink")
            }

            Section("About") {
                Link("Source Code on GitHub",
                     destination: URL(string: "https://github.com/georgie-codes/Doughy")!)
                if isUSRegion {
                    Link(destination: URL(string: "https://www.feedingamerica.org/find-your-local-foodbank")!) {
                        VStack(alignment: .leading) {
                            Text("Donate to your local food bank.")
                            Text("Go to feedingamerica.org")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please close and reopen Doughy to apply the language change.")
        }
    }
}
