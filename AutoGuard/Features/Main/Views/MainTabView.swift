//
//  MainTabView.swift
//  AutoGuard
//
//  Containerul principal de navigare cu TabView nativ iOS.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .garage
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showingOnboarding: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.garage.titleKey, systemImage: AppTab.garage.iconName, value: .garage) {
                GarageView()
            }

            Tab(AppTab.service.titleKey, systemImage: AppTab.service.iconName, value: .service) {
                ServiceHubView()
            }

            Tab(AppTab.assistant.titleKey, systemImage: AppTab.assistant.iconName, value: .assistant) {
                AssistantView()
            }

            Tab(AppTab.settings.titleKey, systemImage: AppTab.settings.iconName, value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(onFinish: {
                hasCompletedOnboarding = true
                showingOnboarding = false
            })
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleWidgetDeepLink"))) { _ in
            selectedTab = .garage
        }
    }
}

#Preview {
    MainTabView()
}
