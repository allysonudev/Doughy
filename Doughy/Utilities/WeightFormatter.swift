//
//  WeightFormatter.swift
//  Doughy
//
//  Created by urickg on 3/29/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import Foundation

class WeightFormatter: NSObject {

    static let shared = WeightFormatter()

    private override init() {}

    /// Formats a gram weight, localized to the current locale: "350g" in
    /// English, "٣٥٠ غ" in Arabic. Fewer decimals as the magnitude grows, with
    /// thousands grouping. `.providedUnit` keeps the value in grams (it never
    /// auto-promotes to kg), and `.autoupdatingCurrent` tracks the live locale.
    func format(weight: Double, minimumFraction: Int = 0) -> String {
        let minFraction = max(minimumFraction, 0)
        let maxFraction: Int
        if abs(weight) > 100 {
            maxFraction = 0
        } else if abs(weight) > 10 {
            maxFraction = 1
        } else {
            maxFraction = 2
        }

        let formatter = MeasurementFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        formatter.numberFormatter.usesGroupingSeparator = true
        formatter.numberFormatter.groupingSize = 3
        formatter.numberFormatter.minimumFractionDigits = minFraction
        formatter.numberFormatter.maximumFractionDigits = maxFraction
        return formatter.string(from: Measurement(value: weight, unit: UnitMass.grams))
    }
}
