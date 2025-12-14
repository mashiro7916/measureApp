//
//  ARManager.swift
//  measureApp
//
//  Created by jacky72503 on 2025/12/15.
//

import Foundation
import ARKit
import RealityKit
import UIKit
import Photos

class ARManager: ObservableObject {
    @Published var isContinuousCapture = false
    @Published var captureStatus = ""
    @Published var captureCount = 0
    
    var arView: ARView?
    var currentFrame: ARFrame?
    private var captureTimer: Timer?
    private let captureInterval: TimeInterval = 0.1 // Capture every 0.1 seconds (10 FPS)
    private var hasPhotoLibraryPermission = false
    
    func startContinuousCapture() {
        guard !isContinuousCapture else { return }
        
        // Check photo library permission first
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.captureStatus = "Error: Photo library permission required"
                    return
                }
                
                self?.hasPhotoLibraryPermission = true
                self?.isContinuousCapture = true
                self?.captureCount = 0
                self?.captureStatus = "Continuous capture started"
                
                // Start timer to capture at regular intervals
                self?.captureTimer = Timer.scheduledTimer(withTimeInterval: self?.captureInterval ?? 0.1, repeats: true) { [weak self] _ in
                    self?.captureCurrentFrame()
                }
            }
        }
    }
    
    func stopContinuousCapture() {
        guard isContinuousCapture else { return }
        
        isContinuousCapture = false
        captureTimer?.invalidate()
        captureTimer = nil
        captureStatus = "Continuous capture stopped. Total: \(captureCount) frames"
    }
    
    private func captureCurrentFrame() {
        guard let frame = currentFrame else {
            return
        }
        
        // Capture RGB image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let rgbImage = UIImage(cgImage: cgImage)
        
        // Extract depth data
        var depthData: [Float]? = nil
        var depthWidth: Int = 0
        var depthHeight: Int = 0
        if let depthMap = frame.sceneDepth?.depthMap ?? frame.smoothedSceneDepth?.depthMap {
            depthWidth = CVPixelBufferGetWidth(depthMap)
            depthHeight = CVPixelBufferGetHeight(depthMap)
            depthData = extractDepthData(depthMap: depthMap)
        }
        
        // Save RGB image and depth data
        saveRGBImageAndDepthData(rgbImage: rgbImage, depthData: depthData, width: depthWidth, height: depthHeight, frameNumber: captureCount)
    }
    
    private func extractDepthData(depthMap: CVPixelBuffer) -> [Float]? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let pixelFormat = CVPixelBufferGetPixelFormatType(depthMap)
        
        var depthValues: [Float] = []
        
        if pixelFormat == kCVPixelFormatType_DepthFloat32 {
            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self)
            
            guard let floatBuffer = floatBuffer else {
                return nil
            }
            
            // Extract all depth values
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * (bytesPerRow / MemoryLayout<Float32>.size) + x
                    let depth = Float(floatBuffer[offset])
                    depthValues.append(depth)
                }
            }
        } else if pixelFormat == kCVPixelFormatType_DisparityFloat32 {
            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let floatBuffer = baseAddress?.assumingMemoryBound(to: Float32.self)
            
            guard let floatBuffer = floatBuffer else {
                return nil
            }
            
            // Convert disparity to depth
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * (bytesPerRow / MemoryLayout<Float32>.size) + x
                    let disparity = Float(floatBuffer[offset])
                    let depth = disparity > 0 && disparity.isFinite ? 1.0 / disparity : 0.0
                    depthValues.append(depth)
                }
            }
        } else {
            return nil
        }
        
        return depthValues
    }
    
    private func saveRGBImageAndDepthData(rgbImage: UIImage, depthData: [Float]?, width: Int, height: Int, frameNumber: Int) {
        // Continuous capture - permission already checked
        guard hasPhotoLibraryPermission else {
            return
        }
        performSave(rgbImage: rgbImage, depthData: depthData, width: width, height: height, frameNumber: frameNumber)
    }
    
    private func performSave(rgbImage: UIImage, depthData: [Float]?, width: Int, height: Int, frameNumber: Int) {
        // Save RGB image
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: rgbImage)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // Save depth data to file
                    if let depthData = depthData, width > 0, height > 0 {
                        _ = self?.saveDepthDataToFile(depthData: depthData, width: width, height: height, frameNumber: frameNumber)
                    }
                    
                    // Update status
                    if let self = self {
                        self.captureCount += 1
                        self.captureStatus = "Capturing... Frame \(self.captureCount)"
                    }
                }
            }
        }
    }
    
    private func saveDepthDataToFile(depthData: [Float], width: Int, height: Int, frameNumber: Int) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // Use milliseconds for better precision
        let fileName = "depth_data_\(frameNumber)_\(timestamp).csv"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Create CSV content
        var csvContent = "x,y,depth\n"
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if index < depthData.count {
                    let depth = depthData[index]
                    csvContent += "\(x),\(y),\(depth)\n"
                }
            }
        }
        
        // Write to file
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error saving depth data: \(error)")
            return false
        }
    }
}

