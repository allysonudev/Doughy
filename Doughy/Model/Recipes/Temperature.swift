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
                    return "Celsius"
                case .fahrenheit:
                    return "Fahrenheit"
                }
            }
        }
    }
    
    public override func copy() -> Any {
        return Temperature(value: value, measurement: measurement)
    }
}
