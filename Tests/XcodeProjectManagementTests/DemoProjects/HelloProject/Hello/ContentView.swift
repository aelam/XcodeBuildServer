//
//  ContentView.swift
//  Hello
//
//  Created by wang.lun on 2025/08/03.
//

import CoreFoundation
import CoreGraphics
import Foundation
import SwiftUI
import UIKit

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
