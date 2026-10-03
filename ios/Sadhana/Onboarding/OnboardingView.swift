import SwiftUI

/// Three short pages: what Sadhana is, how it keeps you going, and your first habits with reminders.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0
    @State private var chosen: Set<String> = ["Meditate", "Read 20 minutes"]
    @State private var lit = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x141A45), Color(hex: 0x3E3477), Color(hex: 0xEE9F5C)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            TabView(selection: $page) {
                welcome.tag(0)
                principles.tag(1)
                firstHabits.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .foregroundStyle(.white)
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        VStack(spacing: 26) {
            Spacer()
            DiyaView(color: HabitColor.saffron.color, glow: lit ? 1 : 0, size: 130)
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { lit = true }
                    }
                }
            VStack(spacing: 10) {
                Text("Sadhana").font(.serif(44, weight: .bold))
                Text("Daily practice, one lamp at a time.").font(.title3).opacity(0.85)
            }
            Text("“Every habit and faculty is maintained and increased by the corresponding actions.”\n— Epictetus, Discourses 2.18")
                .font(.serif(16, weight: .regular))
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .padding(.horizontal, 30)
            Spacer()
            nextButton("Begin") { page = 1 }
        }
        .padding(.bottom, 50)
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("How it keeps you going").font(.serif(30, weight: .bold))
            principle("clock.badge.checkmark", "A time for every habit", "“After I make coffee, I will read.” Plans tied to a time and a cue are followed far more often.")
            principle("arrow.uturn.up", "Never miss twice", "One missed day never breaks your chain. Two in a row does. So a bad day is only ever one day.")
            principle("leaf", "A minimum for hard days", "Every habit has a tiny version. Doing it keeps the chain alive.")
            principle("circle.hexagongrid", "Every check-in is a vote", "Each day fills a bead on a 108-bead mala, a vote for who you're becoming.")
            Spacer()
            nextButton("Continue") { page = 2 }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 50)
    }

    private var firstHabits: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 30)
            Text("Choose your first habits").font(.serif(30, weight: .bold))
            Text("Start with two or three. You can change times and add more later.").opacity(0.85)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(HabitTemplate.all) { template in
                        let on = chosen.contains(template.name)
                        Button {
                            withAnimation(.snappy) { if on { chosen.remove(template.name) } else { chosen.insert(template.name) } }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.symbol).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).font(.body.weight(.semibold))
                                    Text(template.times.map(\.displayText).joined(separator: " · ")).font(.caption).opacity(0.75)
                                }
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(on ? 0.22 : 0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            nextButton(chosen.isEmpty ? "Start with no habits" : "Start with \(chosen.count) \(chosen.count == 1 ? "habit" : "habits")") { finish() }
            Text("Next, iPhone will ask to allow reminders, so each habit can nudge you at its time.")
                .font(.footnote)
                .opacity(0.75)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }

    private func principle(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 34)
                .foregroundStyle(Palette.flameMid)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).opacity(0.85).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func nextButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Palette.flameOuter))
                .foregroundStyle(.white)
        }
        .buttonStyle(LampPressStyle())
        .padding(.horizontal, 4)
    }

    private func finish() {
        let today = store.today
        let picked = HabitTemplate.all.filter { chosen.contains($0.name) }
        store.mutate { data in
            for template in picked { data.upsert(template.makeHabit(createdOn: today)) }
            data.preferences.onboarded = true
        }
        Task {
            _ = await ReminderScheduler.requestAuthorization()
            store.scheduleReminders()
        }
    }
}
