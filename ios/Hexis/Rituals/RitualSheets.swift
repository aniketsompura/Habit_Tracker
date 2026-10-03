import SwiftUI

/// Morning Sankalpa: one intention and one habit that can't slip.
struct SankalpaSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var intention = ""
    @State private var focus: UUID?
    @State private var lit = false
    @FocusState private var intentionFocused: Bool

    var body: some View {
        let items = store.engine.agenda(on: store.today)
        let habitIDs = items.reduce(into: [UUID]()) { ids, item in if !ids.contains(item.habitID) { ids.append(item.habitID) } }
        let todaysHabits = habitIDs.compactMap { store.habit($0) }
        let quote = store.quote(.morning)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 8) {
                        DiyaView(color: Palette.saffron, glow: lit ? 1 : 0, size: 84)
                        Text("Sankalpa").font(.serif(32, weight: .bold)).foregroundStyle(Palette.ink)
                        Text("A small, clear resolve for today.").font(.subheadline).foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Today I will…")
                        TextField("be patient in every conversation", text: $intention, axis: .vertical)
                            .font(.serif(19, weight: .regular))
                            .lineLimit(1...4)
                            .focused($intentionFocused)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.rule))
                    }

                    if !todaysHabits.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "The one habit that can't slip")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(todaysHabits) { habit in
                                    let chosen = focus == habit.id
                                    Button {
                                        withAnimation(.snappy) { focus = chosen ? nil : habit.id }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: chosen ? "star.fill" : habit.symbol)
                                                .contentTransition(.symbolEffect(.replace))
                                            Text(habit.name).lineLimit(1)
                                        }
                                        .font(.footnote.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Capsule().fill(chosen ? habit.color.color : habit.color.color.opacity(0.12)))
                                        .foregroundStyle(chosen ? Color.white : habit.color.color)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(chosen ? .isSelected : [])
                                }
                            }
                            Text("It gets a star on Today. Choosing one thing in advance makes it far more likely to happen.")
                                .font(.footnote).foregroundStyle(Palette.ink2)
                        }
                    }

                    Card { QuoteBlock(quote: quote, showOriginal: store.prefs.showSanskrit, size: 16) }

                    Button(action: commit) {
                        Text(lit ? "Sankalpa set" : "Set Sankalpa")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Palette.saffron))
                            .foregroundStyle(Palette.onSaffron)
                    }
                    .buttonStyle(LampPressStyle())
                    .disabled(lit)
                }
                .padding(20)
            }
            .background(Palette.paper)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sensoryFeedback(.success, trigger: lit)
        }
        .onAppear {
            let record = store.data.record(for: store.today)
            intention = record.intention ?? ""
            focus = record.focusHabitID
        }
    }

    private func commit() {
        intentionFocused = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { lit = true }
        store.setSankalpa(intention: intention, focus: focus)
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        }
    }
}

/// Seneca's nightly review (On Anger 3.36), plus a free log.
struct ReviewSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cured = ""
    @State private var resisted = ""
    @State private var better = ""
    @State private var note = ""

    var body: some View {
        let summary = store.engine.summary(on: store.today)
        let senecaQuote = store.quotes.quote(id: "seneca-anger-3-36-questions")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "moon.stars.fill").font(.largeTitle).foregroundStyle(HabitColor.indigo.color)
                            .symbolEffect(.pulse, options: .nonRepeating)
                        Text("Evening review").font(.serif(32, weight: .bold)).foregroundStyle(Palette.ink)
                        Text("\(summary.done) of \(summary.total) lamps lit today. However the day went, look at it honestly and kindly.")
                            .font(.subheadline).foregroundStyle(Palette.ink2)
                    }
                    if let senecaQuote {
                        Card { QuoteBlock(quote: senecaQuote, showOriginal: false, size: 16) }
                    }
                    prompt("Which bad habit did I cure today?", placeholder: "Didn't check my phone before breakfast", text: $cured)
                    prompt("Which fault did I resist?", placeholder: "Stayed calm in traffic", text: $resisted)
                    prompt("In what way am I better?", placeholder: "Read even though I was tired", text: $better)
                    prompt("Anything else to log", placeholder: "Notes for future you", text: $note)
                    Button(action: save) {
                        Text("Save review")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(HabitColor.indigo.color))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(LampPressStyle())
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            let record = store.data.record(for: store.today)
            cured = record.review?.cured ?? ""
            resisted = record.review?.resisted ?? ""
            better = record.review?.better ?? ""
            note = record.note ?? ""
        }
    }

    private func prompt(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.serif(17, weight: .semibold)).foregroundStyle(Palette.ink)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...6)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.rule))
        }
    }

    private func save() {
        store.saveReview(Review(cured: cured.trimmed, resisted: resisted.trimmed, better: better.trimmed), note: note)
        dismiss()
    }
}
