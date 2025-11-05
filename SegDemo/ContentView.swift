//
//  ContentView.swift
//  SegDemo
//
//  Created by yf on 2025/11/4.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PerformanceTestView()
                .tabItem {
                    Label("性能测试", systemImage: "speedometer")
                }
            
            MaskGeneratorView()
                .tabItem {
                    Label("人物抠图测试", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    ContentView()
}
