//
//  InstructionConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class InstructionConverter: NSObject {
    
    let objectFactory = ObjectFactory.shared
    
    static let shared = InstructionConverter()
    
    private override init() { }
    
    func convertToCoreData(instruction: Instruction) -> XCInstruction {
        let coreData = objectFactory.createInstruction()
        
        coreData.step = instruction.step
        
        return coreData
    }
    
    /// - Parameter localize: When true, a default-recipe instruction step is
    ///   resolved to the user's language. Only set for the app's built-in
    ///   default recipes, so user-written steps are preserved as entered.
    func convertToExternal(instruction: XCInstruction, localize: Bool = false) -> Instruction {
        let storedStep = instruction.step!
        let step = localize ? DefaultLocalization.instructionStep(storedStep) : storedStep

        return Instruction(step: step)
    }

}
