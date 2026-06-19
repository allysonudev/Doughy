//
//  DismissViewHelper.swift
//  Doughy
//
//  Created by urickg on 3/29/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class AlertViewHelper: NSObject {
    
    static func createDismissAlert(discardCompletion: ((UIAlertAction) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(
            title: String(localized: "alert.discard_changes.title", defaultValue: "Discard changes?"),
            message: String(localized: "alert.discard_changes.message", defaultValue: "Your changes will be lost"),
            preferredStyle: .actionSheet
        )
        
        let discardAction = UIAlertAction(
            title: String(localized: "action.discard", defaultValue: "Discard"),
            style: .destructive,
            handler: discardCompletion
        )
        let keepEditing = UIAlertAction(
            title: String(localized: "action.keep_editing", defaultValue: "Keep Editing"),
            style: .default,
            handler: nil
        )
        alert.addAction(discardAction)
        alert.addAction(keepEditing)
        return alert
    }
    
    static func createErrorAlert(title: String, message: String, completion: ((UIAlertAction) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: String(localized: "action.ok", defaultValue: "OK"), style: .default, handler: completion)
        alert.addAction(okAction)
        return alert
    }

}
