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
            GarageView()
                .tabItem {
                    Label(AppTab.garage.titleKey, systemImage: AppTab.garage.iconName)
                }
                .tag(AppTab.garage)

            ServiceHubView()
                .tabItem {
                    Label(AppTab.service.titleKey, systemImage: AppTab.service.iconName)
                }
                .tag(AppTab.service)

            AssistantView()
                .tabItem {
                    Label(AppTab.assistant.titleKey, systemImage: AppTab.assistant.iconName)
                }
                .tag(AppTab.assistant)

            SettingsView()
                .tabItem {
                    Label(AppTab.settings.titleKey, systemImage: AppTab.settings.iconName)
                }
                .tag(AppTab.settings)
        }
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
    }
}

#Preview {
    MainTabView()
}
