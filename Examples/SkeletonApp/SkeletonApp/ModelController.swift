//
//  ModelController.swift
//  MatchingEngine_Example
//
// Model controller to store app state.

import Foundation
import MatchingEngine

class MatchingEngineModelView {
    // Basic one instance of the App's MatchingEngine, just return.
    private var matchingEngines: [MatchingEngine];
    
    init() {
        matchingEngines = [MatchingEngine()]
    }
    
    public func getMatchingEngine(index: Int?=0) -> MatchingEngine? {
        guard let i = index else {
            return nil
        }
        
        if i < matchingEngines.count {
            return matchingEngines[i]
        }
        return nil
    }
}
