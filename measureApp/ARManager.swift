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
    @Published var isCapturing = false
    @Published var captureStatus = ""
    
    var arView: ARView?
    var currentFrame: ARFrame?
    
    func captureRGBAndDepth() {
        guard let frame = currentFrame else {
            captureStatus = "Error: Unable to get AR frame"
            return
        }
        
        isCapturing = true
        captureStatus = "Capturing..."
        
        // Capture RGB image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            captureStatus = "Error: Unable to create RGB image"
            isCapturing = false
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
        saveRGBImageAndDepthData(rgbImage: rgbImage, depthData: depthData, width: depthWidth, height: depthHeight)
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
    
    private func saveRGBImageAndDepthData(rgbImage: UIImage, depthData: [Float]?, width: Int, height: Int) {
        // Request photo library permission for RGB image
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self?.captureStatus = "Error: Photo library permission required"
                    self?.isCapturing = false
                }
                return
            }
            
            // Save RGB image
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: rgbImage)
            }) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        // Save depth data to file
                        if let depthData = depthData, width > 0, height > 0 {
                            if self?.saveDepthDataToFile(depthData: depthData, width: width, height: height) == true {
                                self?.captureStatus = "RGB image and depth data saved"
                            } else {
                                self?.captureStatus = "RGB saved, but depth data save failed"
                            }
                        } else {
                            self?.captureStatus = "RGB saved (no depth data)"
                        }
                        self?.isCapturing = false
                    } else {
                        self?.captureStatus = "Save failed: \(error?.localizedDescription ?? "Unknown error")"
                        self?.isCapturing = false
                    }
                }
            }
        }
    }
    
    private func saveDepthDataToFile(depthData: [Float], width: Int, height: Int) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "depth_data_\(timestamp).csv"
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

