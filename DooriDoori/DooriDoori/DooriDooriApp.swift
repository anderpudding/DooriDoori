//
//  DooriDooriApp.swift
//  DooriDoori
//
//  Created by Sungjun Lee on 2026-05-04.
//

import SwiftUI

@main
struct DooriDooriApp: App {
    init() {
        #if DEBUG
        AppFont.validateRegisteredFonts()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
