//
//  Utilities.swift
//  ARShooter
//
//  Created by Daniel Kim on 8/9/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import simd
import ARKit

extension ARFrame.WorldMappingStatus: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .notAvailable:
            return "Not Available"
        case .limited:
            return "Limited"
        case .extending:
            return "Extending"
        case .mapped:
            return "Mapped"
        }
    }
}

extension float4x4 { // gives the layout of simdFloat4x4 used for rendering the bullet and sending it to the peer device 
    var translation: float3 {
        return float3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    init(translation vector: float3) {
        self.init(float4(1, 0, 0, 0),
                  float4(0, 1, 0, 0),
                  float4(0, 0, 1, 0),
                  float4(vector.x, vector.y, vector.z, 1))
    }
}

extension float4 {
    var xyz: float3 {
        return float3(x, y, z)
    }
}
