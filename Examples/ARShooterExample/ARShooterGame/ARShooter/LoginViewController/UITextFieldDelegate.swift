//
//  UITextFieldDelegate.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/3/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import UIKit

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userNameField {
            Swift.print("end editing username")
            userName = textField.text
        } else {
            Swift.print("end editing gameid")
            gameID = textField.text
        }
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if textField == userNameField {
            Swift.print("end editing username")
            userName = textField.text
        } else {
            Swift.print("end editing gameid")
            gameID = textField.text
        }
        textField.resignFirstResponder()
        return true
    }
}


