//
//  PerformanceTestView.swift
//  SegDemo
//
//  Created by yf on 2025/11/4.
//

import SwiftUI
import Vision
import AVFoundation
import CoreImage
import Darwin

struct PerformanceTestView: View {
    @StateObject private var testManager = PerformanceTestManager()
    @State private var selectedQuality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 设备信息
                    DeviceInfoView()
                    
                    // 图片选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择测试图片")
                            .font(.headline)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                                .overlay(
                                    Button(action: {
                                        selectedImage = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(8),
                                    alignment: .topTrailing
                                )
                        } else {
                            Button(action: {
                                showImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("选择图片")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .sheet(isPresented: $showImagePicker) {
                                ImagePicker(selectedImage: $selectedImage)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 配置选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("测试配置")
                            .font(.headline)
                        
                        Picker("质量级别", selection: $selectedQuality) {
                            Text("Fast").tag(VNGeneratePersonSegmentationRequest.QualityLevel.fast)
                            Text("Balanced").tag(VNGeneratePersonSegmentationRequest.QualityLevel.balanced)
                            Text("Accurate").tag(VNGeneratePersonSegmentationRequest.QualityLevel.accurate)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 测试按钮
                    Button(action: {
                        guard let image = selectedImage else {
                            return
                        }
                        Task {
                            await testManager.runTest(
                                image: image,
                                quality: selectedQuality
                            )
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(testManager.isRunning ? "测试中..." : "开始测试")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((testManager.isRunning || selectedImage == nil) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(testManager.isRunning || selectedImage == nil)
                    
                    // 测试结果
                    if testManager.testResults != nil {
                        TestResultsView(results: testManager.testResults!)
                    }
                }
                .padding()
            }
            .navigationTitle("性能测试")
        }
    }
}

struct DeviceInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设备信息")
                .font(.headline)
            
            HStack {
                Text("设备型号:")
                Spacer()
                Text(UIDevice.current.modelName)
            }
            
            HStack {
                Text("芯片:")
                Spacer()
                Text(UIDevice.current.processor)
            }
            
            HStack {
                Text("系统版本:")
                Spacer()
                Text(UIDevice.current.systemVersion)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TestResultsView: View {
    let results: PerformanceTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试结果")
                .font(.headline)
            
            Divider()
            
            HStack {
                Text("分辨率:")
                Spacer()
                Text("\(Int(results.resolution.width))×\(Int(results.resolution.height))")
            }
            
            HStack {
                Text("质量级别:")
                Spacer()
                Text(results.qualityLevel.displayName)
            }
            
            Divider()
            
            HStack {
                Text("单帧处理时间:")
                Spacer()
                Text(String(format: "%.2f ms", results.singleFrameTimeMs))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("最小帧时间:")
                Spacer()
                Text(String(format: "%.2f ms", results.minFrameTimeMs))
            }
            
            HStack {
                Text("最大帧时间:")
                Spacer()
                Text(String(format: "%.2f ms", results.maxFrameTimeMs))
            }
            
            Divider()
            
            // 推算视频处理时间
            VStack(alignment: .leading, spacing: 12) {
                Text("推算视频处理时间 (30FPS):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("5秒视频 (150帧)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("总分割耗时:")
                        Spacer()
                        Text(String(format: "%.2f 秒", results.estimated5SecondVideoTime))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("总处理耗时:")
                        Spacer()
                        Text(String(format: "%.2f 秒", results.estimated5SecondVideoTime))
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("15秒视频 (450帧)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("总分割耗时:")
                        Spacer()
                        Text(String(format: "%.2f 秒", results.estimated15SecondVideoTime))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("总处理耗时:")
                        Spacer()
                        Text(String(format: "%.2f 秒", results.estimated15SecondVideoTime))
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return identifier
    }
    
    var processor: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // 根据设备标识符返回芯片型号
        switch identifier {
        case "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4":
            return "A17 Pro"
        case "iPhone16,1", "iPhone16,2":
            return "A18 Pro"
        case "iPhone15,2", "iPhone15,3":
            return "A16 Bionic"
        case "iPhone14,7", "iPhone14,8":
            return "A15 Bionic"
        case "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4":
            return "A14 Bionic"
        case "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8":
            return "A13 Bionic"
        default:
            return identifier
        }
        #endif
    }
}

#Preview {
    PerformanceTestView()
}

