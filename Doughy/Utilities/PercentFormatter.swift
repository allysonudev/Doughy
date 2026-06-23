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
        let percentString = formatter.string(from: NSNumber(floatLiteral: percent))!
        return "\(percentString)%"
    }

}
