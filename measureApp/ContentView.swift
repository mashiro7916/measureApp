//
//  ContentView.swift
//  measureApp
//
//  Created by jacky72503 on 2025/12/15.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var arManager = ARManager()
    
    var body: some View {
        ZStack {
            // AR view
            ARViewContainer(arManager: arManager)
                .edgesIgnoringSafeArea(.all)
            
            // Control buttons and status
            VStack {
                Spacer()
                
                // Status display
                if !arManager.captureStatus.isEmpty {
                    VStack(spacing: 4) {
                        Text(arManager.captureStatus)
                        if arManager.isContinuousCapture {
                            Text("Frame count: \(arManager.captureCount)")
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 10)
                }
                
                // Continuous capture button
                Button(action: {
                    if arManager.isContinuousCapture {
                        arManager.stopContinuousCapture()
                    } else {
                        arManager.startContinuousCapture()
                    }
                }) {
                    HStack {
                        Image(systemName: arManager.isContinuousCapture ? "stop.circle.fill" : "play.circle.fill")
                        Text(arManager.isContinuousCapture ? "Stop Continuous Capture" : "Start Continuous Capture")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(arManager.isContinuousCapture ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                // Single capture button
                Button(action: {
                    arManager.captureRGBAndDepth()
                }) {
                    HStack {
                        if arManager.isCapturing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "camera.fill")
                        }
                        Text(arManager.isCapturing ? "Capturing..." : "Capture Single Frame")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(arManager.isCapturing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .disabled(arManager.isCapturing || arManager.isContinuousCapture)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    ContentView()
}
