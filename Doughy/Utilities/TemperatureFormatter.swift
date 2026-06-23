//
//  TemperatureFormatter.swift
//  Doughy
//
//  Created by urickg on 3/29/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import Foundation

class TemperatureFormatter: NSObject {

    static let shared = TemperatureFormatter()

    private let formatter: MeasurementFormatter

    private override init() {
        let formatter = MeasurementFormatter()
        // Track the live locale so an OS region / in-app language change is
        // reflected without caching a stale snapshot.
        formatter.locale = .autoupdatingCurrent
        // Keep the user's chosen scale; never convert between °C and °F.
        formatter.unitOptions = .providedUnit
        // `.medium` yields "165°C" / "350°F" / "١٦٥°م" / "٣٥٠°ف". (`.short`
        // renders Fahrenheit as a bare "°" with no scale letter — don't use it.)
        formatter.unitStyle = .medium
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.maximumFractionDigits = 2
        self.formatter = formatter
        super.init()
    }

    func format(temperature: Temperature) -> String {
        formatter.string(from: Measurement(value: temperature.value,
                                           unit: temperature.measurement.unit))
    }
}
