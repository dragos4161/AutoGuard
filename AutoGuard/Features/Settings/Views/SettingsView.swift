//
//  SettingsView.swift
//  AutoGuard
//
//  Ecranul de setări ale aplicației: selecție limbă, informații și preferințe.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system

    var body: some View {
        NavigationStack {
            Form {
                // Secțiunea 1: Limbă & Regional
                Section("settings.section.language") {
                    Picker("settings.language", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                // Secțiunea 2: Despre aplicație & Confidențialitate
                Section("settings.section.about") {
                    HStack {
                        Text("settings.app_name")
                        Spacer()
                        Text("Torpedou / GloveBox")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.version")
                        Spacer()
                        Text("1.0 (Build 1)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("settings.storage")
                        Spacer()
                        Text("settings.storage.local")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings.title")
        }
    }
}

#Preview {
    SettingsView()
}
