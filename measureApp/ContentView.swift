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
                    Text(arManager.captureStatus)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 10)
                }
                
                // Capture button
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
                        Text(arManager.isCapturing ? "Capturing..." : "Capture RGB and Depth")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(arManager.isCapturing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                .disabled(arManager.isCapturing)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    ContentView()
}
