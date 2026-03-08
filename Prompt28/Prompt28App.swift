//
//  Prompt28App.swift
//  Prompt28
//
//  Created by Natalie Whipps on 3/7/26.
//

import SwiftUI

struct Prompt28App: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
        }
    }
}
