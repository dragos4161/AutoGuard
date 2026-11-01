//
//  AssistantView.swift
//  AutoGuard
//
//  Interfața asistentului inteligent On-Device ("Întreabă Torpedoul").
//

import SwiftData
import SwiftUI

struct AssistantView: View {
    @Query private var vehicles: [Vehicle]

    @State private var queryText: String = ""
    @State private var chatHistory: [ChatMessage] = []

    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let timestamp: Date = Date()
    }

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

                        let suggestions = [
                            String(localized: "assistant.prompt.oil"),
                            String(localized: "assistant.prompt.mileage"),
                            String(localized: "assistant.prompt.expirations")
                        ]

                        ForEach(suggestions, id: \.self) { prompt in
                            Button {
                                sendQuery(prompt)
                            } label: {
                                HStack {
                                    Text(prompt)
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
            return String(localized: "assistant.answer.no_vehicles")
        }

        if lower.contains("km") || lower.contains("kilometr") || lower.contains("mileage") {
            let summary = vehicles.map { vehicle in
                let km = vehicle.formattedMileage ?? String(localized: "mileage.card.empty")
                return "\(vehicle.displayName): \(km)"
            }.joined(separator: "\n")
            return "\(String(localized: "assistant.answer.mileage_header"))\n\(summary)"
        }

        if lower.contains("ulei") || lower.contains("oil") || lower.contains("revizi") || lower.contains("service") {
            let answers = vehicles.map { vehicle -> String in
                if let lastOil = vehicle.lastOilChangeRecord {
                    let dateStr = lastOil.date.formatted(.dateTime.day().month().year())
                    var response = "🚗 \(vehicle.displayName):\n• Ultimul schimb: \(dateStr) la \(lastOil.formattedMileage)."
                    if let status = vehicle.oilChangeStatus {
                        if status.isOverdue {
                            response += "\n• ⚠️ Termen depășit! Fă o programare în service."
                        } else {
                            let monthsLeft = max(0, status.remainingDays / 30)
                            response += "\n• Următorul schimb: peste aproximativ \(monthsLeft) luni (\(status.remainingKm) km rămași)."
                        }
                    }
                    return response
                } else {
                    return "🚗 \(vehicle.displayName): Nu ai înregistrat încă niciun schimb de ulei în tab-ul Service."
                }
            }.joined(separator: "\n\n")

            return answers
        }

        if lower.contains("expir") || lower.contains("rca") || lower.contains("itp") || lower.contains("roviniet") {
            let urgent = vehicles.compactMap { $0.mostUrgentDocument }
            if urgent.isEmpty {
                return String(localized: "assistant.answer.all_good")
            }
            let list = urgent.map { doc in
                "\(doc.vehicle?.displayName ?? "") • \(doc.type.rawValue): \(doc.daysRemaining) zile rămase"
            }.joined(separator: "\n")
            return "\(String(localized: "assistant.answer.expiring_header"))\n\(list)"
        }

        return String(localized: "assistant.answer.fallback")
    }
}

#Preview {
    AssistantView()
        .modelContainer(for: [Vehicle.self, VehicleDocument.self, MileageEntry.self], inMemory: true)
}
