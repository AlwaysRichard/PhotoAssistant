//  MyGearSelectionKeys.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/30/25.
//


// MyGearSelectionKeys.swift
import Foundation

enum MyGearSelectionKeys {
    // MARK: - Shared Gear Selection Keys
    // These keys are used across all views to maintain consistent camera/lens selection
    static let selectedGearName = "SelectedGearName"
    static let selectedLensName = "SelectedLensName"
    static let selectedZoom = "SelectedZoom"
    
    // MARK: - Depth of Field View Keys
    static let depthAperture = "DepthAperture"
    static let depthFeet = "DepthFeet"
    static let depthInches = "DepthInches"
    static let depthInfinity = "DepthInfinity"
    
    // MARK: - Field of View Keys
    static let fovAperture = "FovAperture"
    static let fovFeet = "FovFeet"
    static let fovInches = "FovInches"
    static let fovInfinity = "FovInfinity"
    
    // MARK: - Camera View Keys
    // Add camera-view specific keys here as needed
}
