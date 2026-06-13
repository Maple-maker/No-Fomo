import SwiftUI

struct ComposeIdeaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ticker = ""
    @State private var bodyText = ""
    @State private var direction = "long"
    @State private var targetPrice = ""
    @State private var timeframeDays = "30"
    @State private var errorMessage: String?

    let token: String
    let onPost: (String, String, String, Double, Int) async throws -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Ticker (e.g. MRVL)", text: $ticker)
                            .textInputAutocapitalization(.characters)
                            .font(DS.Font.mono(16))
                            .padding(12)
                            .background(DS.Color.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Picker("Direction", selection: $direction) {
                            Text("Long").tag("long")
                            Text("Short").tag("short")
                        }
                        .pickerStyle(.segmented)

                        TextField("Target price", text: $targetPrice)
                            .keyboardType(.decimalPad)
                            .font(DS.Font.mono(16))
                            .padding(12)
                            .background(DS.Color.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        TextField("Timeframe (days)", text: $timeframeDays)
                            .keyboardType(.numberPad)
                            .font(DS.Font.mono(16))
                            .padding(12)
                            .background(DS.Color.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        TextEditor(text: $bodyText)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(DS.Color.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                Group {
                                    if bodyText.isEmpty {
                                        Text("Your thesis and alpha…")
                                            .foregroundColor(DS.Color.textMuted)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 18)
                                    }
                                }, alignment: .topLeading
                            )

                        Text("Community discussion for education. Not investment advice.")
                            .font(.system(size: 11))
                            .foregroundColor(DS.Color.textMuted)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(DS.Color.bear)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Post Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(ticker.isEmpty || bodyText.isEmpty || targetPrice.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        guard let target = Double(targetPrice), target > 0 else {
            errorMessage = "Enter a valid target price"
            return
        }
        let days = Int(timeframeDays) ?? 30
        do {
            try await onPost(
                ticker.uppercased(),
                String(bodyText.prefix(500)),
                direction,
                target,
                max(1, days)
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
