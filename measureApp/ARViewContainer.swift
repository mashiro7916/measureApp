//
//  ARViewContainer.swift
//  measureApp
//
//  Created by jacky72503 on 2025/12/15.
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arManager: ARManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        
        // Check if LiDAR is supported
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // Enable depth data
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        // Enable smoothed depth if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        arView.session.run(configuration)
        arView.session.delegate = context.coordinator
        
        // Set ARManager reference
        arManager.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(arManager: arManager)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var arManager: ARManager
        
        init(arManager: ARManager) {
            self.arManager = arManager
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Update current frame
            arManager.currentFrame = frame
        }
    }
}

