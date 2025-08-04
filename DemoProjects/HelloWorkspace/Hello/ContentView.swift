//
//  ContentView.swift
//  Hello
//
//  Created by wang.lun on 2025/08/03.
//

import SwiftUI
import Foundation
import CoreFoundation
import CoreGraphics

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
