//
//  AssistantView.swift
//  AutoGuard
//
//  Interfața asistentului inteligent On-Device ("Întreabă Torpedoul").
//

import SwiftData
import SwiftUI

struct AssistantView: View {
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .system
    @Query private var vehicles: [Vehicle]

    @State private var queryText: String = ""
    @State private var chatHistory: [ChatMessage] = []

    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let timestamp: Date = Date()
    }

    private struct QuickSuggestion: Identifiable {
        let id: String
        let titleKey: LocalizedStringKey
        let key: String
    }

    private let suggestions: [QuickSuggestion] = [
        QuickSuggestion(id: "oil", titleKey: "assistant.prompt.oil", key: "assistant.prompt.oil"),
        QuickSuggestion(id: "mileage", titleKey: "assistant.prompt.mileage", key: "assistant.prompt.mileage"),
        QuickSuggestion(id: "expirations", titleKey: "assistant.prompt.expirations", key: "assistant.prompt.expirations")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Zona de mesaje
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Mesaj de întâmpinare
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("assistant.welcome.title")
                                    .font(.subheadline.bold())
                                Text("assistant.welcome.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Sugestii rapide (Quick Prompts)
                        Text("assistant.suggestions.title")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        ForEach(suggestions) { item in
                            Button {
                                let promptText = appLanguage.string(item.key)
                                sendQuery(promptText)
                            } label: {
                                HStack {
                                    Text(item.titleKey)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }

                        // Mesaje trimise și primite
                        ForEach(chatHistory) { msg in
                            HStack {
                                if msg.isUser {
                                    Spacer()
                                }
                                Text(msg.text)
                                    .font(.subheadline)
                                    .padding(12)
                                    .background(msg.isUser ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(msg.isUser ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                if !msg.isUser {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color(uiColor: .systemGroupedBackground))

                Divider()

                // Câmp de tastare mesaj
                HStack(spacing: 8) {
                    TextField("assistant.input.placeholder", text: $queryText)
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        if !queryText.trimmingCharacters(in: .whitespaces).isEmpty {
                            sendQuery(queryText)
                            queryText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(queryText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                    }
                    .disabled(queryText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .navigationTitle("assistant.title")
        }
    }

    private func sendQuery(_ query: String) {
        let userMessage = ChatMessage(text: query, isUser: true)
        chatHistory.append(userMessage)

        // Răspuns on-device inteligent
        let answer = generateAnswer(for: query)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            chatHistory.append(ChatMessage(text: answer, isUser: false))
        }
    }

    private func generateAnswer(for query: String) -> String {
        let lower = query.lowercased()

        if vehicles.isEmpty {
            return appLanguage.string("assistant.answer.no_vehicles")
        }

        if lower.contains("km") || lower.contains("kilometr") || lower.contains("mileage") {
            let summary = vehicles.map { vehicle in
                let km = vehicle.formattedMileage ?? appLanguage.string("mileage.card.empty")
                return "\(vehicle.displayName): \(km)"
            }.joined(separator: "\n")
            return "\(appLanguage.string("assistant.answer.mileage_header"))\n\(summary)"
        }

        if lower.contains("ulei") || lower.contains("oil") || lower.contains("revizi") || lower.contains("service") {
            let answers = vehicles.map { vehicle -> String in
                if let lastOil = vehicle.lastOilChangeRecord {
                    let dateStr = lastOil.date.formatted(.dateTime.day().month().year().locale(appLanguage.locale))
                    let lastChangeLabel = appLanguage.string("assistant.answer.oil_last_change")
                    let atLabel = appLanguage.string("assistant.answer.oil_at")
                    var response = "🚗 \(vehicle.displayName):\n• \(lastChangeLabel)\(dateStr) \(atLabel) \(lastOil.formattedMileage)."
                    if let status = vehicle.oilChangeStatus {
                        if status.isOverdue {
                            let overdueMsg = appLanguage.string("assistant.answer.oil_overdue")
                            response += "\n• \(overdueMsg)"
                        } else {
                            let monthsLeft = max(0, status.remainingDays / 30)
                            let nextMsg = appLanguage.string("assistant.answer.oil_next")
                            let monthsUnit = appLanguage.string("assistant.answer.oil_months")
                            let kmLeftUnit = appLanguage.string("assistant.answer.oil_km_left")
                            response += "\n• \(nextMsg) \(monthsLeft) \(monthsUnit) (\(status.remainingKm) \(kmLeftUnit))."
                        }
                    }
                    return response
                } else {
                    let noRec = appLanguage.string("assistant.answer.oil_no_records")
                    return "🚗 \(vehicle.displayName): \(noRec)"
                }
            }.joined(separator: "\n\n")

            return answers
        }

        if lower.contains("expir") || lower.contains("rca") || lower.contains("itp") || lower.contains("roviniet") || lower.contains("doc") {
            let urgent = vehicles.compactMap { $0.mostUrgentDocument }
            if urgent.isEmpty {
                return appLanguage.string("assistant.answer.all_good")
            }
            let daysUnit = appLanguage.string("assistant.answer.days_left")
            let list = urgent.map { doc in
                "\(doc.vehicle?.displayName ?? "") • \(doc.type.rawValue): \(doc.daysRemaining) \(daysUnit)"
            }.joined(separator: "\n")
            return "\(appLanguage.string("assistant.answer.expiring_header"))\n\(list)"
        }

        return appLanguage.string("assistant.answer.fallback")
    }
}

#Preview {
    AssistantView()
        .modelContainer(for: [Vehicle.self, VehicleDocument.self, MileageEntry.self], inMemory: true)
}
