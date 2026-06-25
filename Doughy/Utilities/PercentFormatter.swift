//
//  PercentFormatter.swift
//  Doughy
//
//  Created by urickg on 3/29/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class PercentFormatter: NSObject {
    
    private let formatter = NumberFormatter()
    
    static let shared = PercentFormatter()
    
    private override init() {
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
    }

    func format(percent: Double) -> String {
        "\(formatNumber(percent: percent))\(percentSymbol)"
    }

    /// Just the locale-formatted number, without the percent symbol.
    func formatNumber(percent: Double) -> String {
        formatter.string(from: NSNumber(floatLiteral: percent)) ?? "\(percent)"
    }

    /// The locale's percent symbol (e.g. "٪" in Arabic, "%" in Latin locales).
    var percentSymbol: String { formatter.percentSymbol ?? "%" }

}
