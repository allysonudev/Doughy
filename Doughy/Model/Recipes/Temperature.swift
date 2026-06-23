//
//  Temperature.swift
//  Doughy
//
//  Created by urickg on 4/2/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

public class Temperature: NSObject {
    
    let value: Double
    let measurement: Measurement
    
    init(value: Double, measurement: Measurement) {
        self.value = value
        self.measurement = measurement
    }

    public enum Measurement: String {
        case celsius
        case fahrenheit
        
        static func allValues() -> [Measurement] {
            return [.celsius, .fahrenheit]
        }
        
        var shortValue: String {
            get {
                switch self {
                case .celsius:
                    return "C"
                case .fahrenheit:
                    return "F"
                }
            }
        }
        
        var longValue: String {
            get {
                switch self {
                case .celsius:
                    return String(localized: "temperature.celsius", defaultValue: "Celsius")
                case .fahrenheit:
                    return String(localized: "temperature.fahrenheit", defaultValue: "Fahrenheit")
                }
            }
        }

        /// The Foundation unit this maps to, for locale-aware formatting.
        var unit: UnitTemperature {
            switch self {
            case .celsius: return .celsius
            case .fahrenheit: return .fahrenheit
            }
        }

        /// The localized degree symbol on its own — "°C"/"°F" in English,
        /// "°م"/"°ف" in Arabic — matching how `TemperatureFormatter` renders the
        /// unit (including RTL marks). Derived from `MeasurementFormatter` so it
        /// stays in sync with inline temperatures rather than hardcoding glyphs.
        var localizedSymbol: String {
            let formatter = MeasurementFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.unitOptions = .providedUnit
            formatter.unitStyle = .medium
            let formatted = formatter.string(from: Foundation.Measurement(value: 0, unit: unit))
            let zero = formatter.numberFormatter.string(from: NSNumber(value: 0)) ?? "0"
            return formatted
                .replacingOccurrences(of: zero, with: "")
                .trimmingCharacters(in: .whitespaces)
        }
    }
    
    public override func copy() -> Any {
        return Temperature(value: value, measurement: measurement)
    }
}
