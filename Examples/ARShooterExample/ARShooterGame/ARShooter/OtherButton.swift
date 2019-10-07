//
//  OtherButton.swift
//  ARShooter
//
//  Created by Daniel Kim on 8/12/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import UIKit

@IBDesignable
class OtherButton: UIButton {
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder){
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup(){
        backgroundColor = tintColor
        layer.cornerRadius = 8
        clipsToBounds = true
        setTitleColor(.white, for: [])
        titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }
    
    override var isEnabled: Bool{
        didSet{
            backgroundColor = isEnabled ? tintColor : .gray
        }
    }
}
