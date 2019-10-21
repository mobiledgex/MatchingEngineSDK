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
    
    private func getUsernameAndGameID(_ textField: UITextField) {
        if textField == userNameField {
            Swift.print("end editing username")
            userName = textField.text
        } else {
            Swift.print("end editing gameid")
            gameID = textField.text
        }
        textField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        getUsernameAndGameID(textField)
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        getUsernameAndGameID(textField)
        return true
    }
}


