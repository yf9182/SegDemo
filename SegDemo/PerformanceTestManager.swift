//
//  PerformanceTestManager.swift
//  SegDemo
//
//  Created by yf on 2025/11/4.
//

import Foundation
import Vision
import CoreImage
import UIKit
import Combine
import ImageIO

extension VNGeneratePersonSegmentationRequest.QualityLevel {
    var displayName: String {
        switch self {
        case .fast:
            return "Fast"
        case .balanced:
            return "Balanced"
        case .accurate:
            return "Accurate"
        @unknown default:
            return "Unknown"
        }
    }
}

struct PerformanceTestResult {
    let resolution: CGSize
    let qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel
    let singleFrameTimeMs: Double  // 单帧处理时间（毫秒）
    let minFrameTimeMs: Double
    let maxFrameTimeMs: Double
    
    // 基于单帧时间推算视频处理时间
    var estimated5SecondVideoTime: Double {
        // 5秒视频 = 150帧（30FPS）
        Double(150) * singleFrameTimeMs / 1000.0
    }
    
    var estimated15SecondVideoTime: Double {
        // 15秒视频 = 450帧（30FPS）
        Double(450) * singleFrameTimeMs / 1000.0
    }
    
    // 总分割耗时（对于5秒视频）
    var totalSegmentationTime5s: Double {
        estimated5SecondVideoTime
    }
    
    // 总分割耗时（对于15秒视频）
    var totalSegmentationTime15s: Double {
        estimated15SecondVideoTime
    }
}

@MainActor
class PerformanceTestManager: ObservableObject {
    @Published var isRunning = false
    @Published var testResults: PerformanceTestResult?
    
    private let testRepeatCount = 10 // 重复测试次数，取平均值以获得更稳定的结果
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
    
    func runTest(image: UIImage, quality: VNGeneratePersonSegmentationRequest.QualityLevel) async {
        isRunning = true
        defer { isRunning = false }
        
        // 修正图片方向
        let correctedImage = getCorrectOrientationUIImage(uiImage: image)
        
        // 获取图片的实际分辨率
        let imageSize = CGSize(width: correctedImage.size.width, height: correctedImage.size.height)
        
        // 预热：先执行几次以稳定性能
        print("预热中...")
        for _ in 0..<3 {
            do {
                try await performSegmentation(image: correctedImage, quality: quality)
            } catch {
                print("预热失败: \(error)")
                return
            }
        }
        
        // 对同一张图片进行多次测试，取平均值
        var frameTimes: [Double] = []
        
        print("开始测试单帧处理时间...")
        for i in 0..<testRepeatCount {
            let frameStartTime = CFAbsoluteTimeGetCurrent()
            
            // 执行分割请求（处理同一张图片）
            do {
                try await performSegmentation(image: correctedImage, quality: quality)
            } catch {
                print("分割失败: \(error)")
                return
            }
            
            let frameEndTime = CFAbsoluteTimeGetCurrent()
            let frameTime = (frameEndTime - frameStartTime) * 1000.0 // 转换为毫秒
            frameTimes.append(frameTime)
            
            print("第 \(i + 1)/\(testRepeatCount) 次测试: \(String(format: "%.2f", frameTime)) ms")
        }
        
        // 计算统计信息
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let minFrameTime = frameTimes.min() ?? 0
        let maxFrameTime = frameTimes.max() ?? 0
        
        // 创建结果（基于单帧时间）
        let results = PerformanceTestResult(
            resolution: imageSize,
            qualityLevel: quality,
            singleFrameTimeMs: avgFrameTime,
            minFrameTimeMs: minFrameTime,
            maxFrameTimeMs: maxFrameTime
        )
        
        testResults = results
        
        // 打印详细结果
        print("\n=== 性能测试结果 ===")
        print("图片分辨率: \(Int(imageSize.width))×\(Int(imageSize.height))")
        print("质量级别: \(quality.displayName)")
        print("单帧处理时间: \(String(format: "%.2f", avgFrameTime)) ms")
        print("最小帧时间: \(String(format: "%.2f", minFrameTime)) ms")
        print("最大帧时间: \(String(format: "%.2f", maxFrameTime)) ms")
        print("\n=== 推算视频处理时间（30FPS）===")
        print("5秒视频 (150帧):")
        print("  总分割耗时: \(String(format: "%.2f", results.estimated5SecondVideoTime)) 秒")
        print("  总处理耗时: \(String(format: "%.2f", results.estimated5SecondVideoTime)) 秒")
        print("15秒视频 (450帧):")
        print("  总分割耗时: \(String(format: "%.2f", results.estimated15SecondVideoTime)) 秒")
        print("  总处理耗时: \(String(format: "%.2f", results.estimated15SecondVideoTime)) 秒")
    }
    
    private func performSegmentation(
        image: UIImage,
        quality: VNGeneratePersonSegmentationRequest.QualityLevel
    ) async throws {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取CGImage"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNPixelBufferObservation] else {
                    continuation.resume(throwing: NSError(domain: "TestError", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的结果"]))
                    return
                }
                
                continuation.resume()
            }
            
            request.qualityLevel = quality
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

