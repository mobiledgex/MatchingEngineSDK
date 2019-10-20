//
//  Player.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/3/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import UIKit

class Player {
    
    var color: UIColor
    var score: Int
    var username: String
    var gameID: String
    
    init (color: UIColor, username: String, gameID: String) {
        self.color = color
        self.username = username
        self.gameID = gameID
        score = 0
    }
}
