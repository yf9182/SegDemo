//
//  MaskGeneratorView.swift
//  SegDemo
//
//  Created by yf on 2025/11/4.
//

import SwiftUI
import Vision
import UIKit
import Photos
import CoreImage
import Combine

struct MaskGeneratorView: View {
    @StateObject private var maskGenerator = MaskGenerator()
    @State private var selectedImage: UIImage?
    @State private var maskImage: UIImage?
    @State private var segmentedImage: UIImage? // 抠图效果（白底）
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 图片选择区域
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择图片")
                            .font(.headline)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(8)
                                .overlay(
                                    Button(action: {
                                        selectedImage = nil
                                        maskImage = nil
                                        segmentedImage = nil
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
                            .onChange(of: selectedImage) { _ in
                                maskImage = nil
                                segmentedImage = nil
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 质量级别选择
                    if selectedImage != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("处理配置")
                                .font(.headline)
                            
                            Picker("质量级别", selection: $maskGenerator.selectedQuality) {
                                Text("Fast").tag(VNGeneratePersonSegmentationRequest.QualityLevel.fast)
                                Text("Balanced").tag(VNGeneratePersonSegmentationRequest.QualityLevel.balanced)
                                Text("Accurate").tag(VNGeneratePersonSegmentationRequest.QualityLevel.accurate)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: maskGenerator.selectedQuality) { _ in
                                // 切换质量级别时自动重新生成
                                if selectedImage != nil {
                                    Task {
                                        await processImage()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // 处理按钮（只在首次生成时显示）
                    if selectedImage != nil && maskImage == nil {
                        Button(action: {
                            Task {
                                await processImage()
                            }
                        }) {
                            HStack {
                                if maskGenerator.isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(maskGenerator.isProcessing ? "处理中..." : "生成 Mask")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(maskGenerator.isProcessing ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(maskGenerator.isProcessing)
                    }
                    
                    // Mask 图片显示
                    if let mask = maskImage {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("处理结果")
                                .font(.headline)
                            
                            // Mask 效果
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mask 效果")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Image(uiImage: mask)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .cornerRadius(8)
                                    .background(Color.black)
                            }
                            
                            Divider()
                            
                            // 抠图效果（白底）
                            if let segmented = segmentedImage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("抠图效果（白底）")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Image(uiImage: segmented)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 250)
                                        .cornerRadius(8)
                                        .background(Color.white)
                                }
                            }
                            
                            Divider()
                            
                            // 保存按钮
                            HStack(spacing: 12) {
                                Button(action: {
                                    saveToPhotoLibrary(image: mask, isMask: true)
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("保存 Mask")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                if let segmented = segmentedImage {
                                    Button(action: {
                                        saveToPhotoLibrary(image: segmented, isMask: false)
                                    }) {
                                        HStack {
                                            Image(systemName: "square.and.arrow.down")
                                            Text("保存抠图")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("人物抠图（测试）")
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func processImage() async {
        guard let image = selectedImage else { return }
        
        // 修正图片方向
        let correctedImage = maskGenerator.getCorrectOrientationUIImage(uiImage: image)
        
        maskImage = await maskGenerator.generateMask(from: correctedImage)
        
        if let mask = maskImage {
            // 生成抠图效果（白底）
            segmentedImage = maskGenerator.createSegmentedImage(original: correctedImage, mask: mask)
        } else {
            alertMessage = "处理失败，请重试"
            showAlert = true
        }
    }
    
    private func saveToPhotoLibrary(image: UIImage, isMask: Bool) {
        // 检查当前权限状态
        let status = PHPhotoLibrary.authorizationStatus()
        
        if status == .authorized || status == .limited {
            // 已有权限，直接保存
            saveImage(image: image, isMask: isMask)
        } else if status == .notDetermined {
            // 请求权限
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    self.saveImage(image: image, isMask: isMask)
                } else {
                    DispatchQueue.main.async {
                        self.alertMessage = "需要相册访问权限，请在设置中开启"
                        self.showAlert = true
                    }
                }
            }
        } else {
            // 已拒绝权限
            DispatchQueue.main.async {
                alertMessage = "需要相册访问权限，请在设置中开启"
                showAlert = true
            }
        }
    }
    
    private func saveImage(image: UIImage, isMask: Bool) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    alertMessage = isMask ? "Mask 已保存到相册" : "抠图已保存到相册"
                } else {
                    alertMessage = "保存失败: \(error?.localizedDescription ?? "未知错误")"
                }
                showAlert = true
            }
        }
    }
}

@MainActor
class MaskGenerator: ObservableObject {
    @Published var isProcessing = false
    @Published var selectedQuality: VNGeneratePersonSegmentationRequest.QualityLevel = .balanced
    
    private let ciContext = CIContext()
    
    // 修正图片方向
    func getCorrectOrientationUIImage(uiImage: UIImage) -> UIImage {
        var newImage = UIImage()
        
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else {
                return uiImage
            }
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else {
                return uiImage
            }
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        
        return newImage
    }
    
    func generateMask(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        return await withCheckedContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { request, error in
                if let error = error {
                    print("生成 mask 失败: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observation = request.results?.first as? VNPixelBufferObservation else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // 将 pixel buffer 转换为 UIImage
                let pixelBuffer = observation.pixelBuffer
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                let context = CIContext()
                
                guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
            
            request.qualityLevel = selectedQuality
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("执行请求失败: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    // 生成抠图效果（白底）
    func createSegmentedImage(original: UIImage, mask: UIImage) -> UIImage? {
        guard let originalCIImage = CIImage(image: original),
              let maskCIImage = CIImage(image: mask) else {
            return nil
        }
        
        let size = original.size
        let scale = original.scale
        
        // 确保 mask 和原图尺寸匹配
        let maskScaled = maskCIImage.transformed(by: CGAffineTransform(
            scaleX: size.width / maskCIImage.extent.width,
            y: size.height / maskCIImage.extent.height
        ))
        
        // 创建白色背景
        let whiteColor = CIColor.white
        let whiteBackground = CIImage(color: whiteColor)
            .cropped(to: originalCIImage.extent)
        
        // 使用 CoreImage 的 blendWithMask 滤镜来应用 mask
        // 首先将原图和 mask 组合
        let filter = CIFilter(name: "CIBlendWithMask")
        filter?.setValue(originalCIImage, forKey: kCIInputImageKey)
        filter?.setValue(whiteBackground, forKey: kCIInputBackgroundImageKey)
        filter?.setValue(maskScaled, forKey: kCIInputMaskImageKey)
        
        guard let outputCIImage = filter?.outputImage else {
            // 如果滤镜失败，使用传统方法
            return createSegmentedImageFallback(original: original, mask: mask)
        }
        
        // 将 CIImage 转换为 UIImage
        guard let cgImage = ciContext.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
    
    // 备用方法：使用 CoreGraphics（带坐标系修正）
    private func createSegmentedImageFallback(original: UIImage, mask: UIImage) -> UIImage? {
        guard let originalCGImage = original.cgImage,
              let maskCGImage = mask.cgImage else {
            return nil
        }
        
        let size = original.size
        let scale = original.scale
        
        // 创建绘图上下文
        UIGraphicsBeginImageContextWithOptions(size, true, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        // 翻转坐标系（CoreGraphics 坐标系原点在左下角）
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 绘制白色背景
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // 保存上下文状态
        context.saveGState()
        
        // 使用 mask 作为裁剪蒙版
        context.clip(to: CGRect(origin: .zero, size: size), mask: maskCGImage)
        
        // 绘制原图（只在 mask 区域内）
        context.draw(originalCGImage, in: CGRect(origin: .zero, size: size))
        
        // 恢复上下文状态
        context.restoreGState()
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

