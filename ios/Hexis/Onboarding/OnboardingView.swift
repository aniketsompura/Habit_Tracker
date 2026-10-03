import SwiftUI

/// Three short pages: what Hexis is, how it keeps you going, and your first habits with reminders.
struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0
    @State private var chosen: Set<String> = ["Meditate", "Read 20 minutes"]
    @State private var lit = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0F766E), Color(hex: 0x0E7490), Color(hex: 0x3730A3)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
            Image("Emblem")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .shadow(color: Palette.accent.opacity(lit ? 0.5 : 0), radius: 30, y: 8)
                .scaleEffect(lit ? 1 : 0.9)
                .opacity(lit ? 1 : 0)
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) { lit = true }
                }
            VStack(spacing: 8) {
                Text("Hexis").font(.heading(44, weight: .bold))
                Text("ἕξις · a habit, a settled way of being").font(.quote(16).italic()).opacity(0.8)
            }
            Text("“Every habit and faculty is maintained and increased by the corresponding actions.”\n— Epictetus, Discourses 2.18")
                .font(.quote(16))
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .padding(.horizontal, 30)
            Text("The word Epictetus uses for habit there is hexis.")
                .font(.footnote)
                .opacity(0.7)
            Spacer()
            nextButton("Begin") { page = 1 }
        }
        .padding(.bottom, 50)
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("How it keeps you going").font(.heading(30, weight: .bold))
            principle("clock.badge.checkmark", "A time for every habit", "“After I make coffee, I will read.” Plans tied to a time and a cue are followed far more often.")
            principle("arrow.uturn.up", "Never miss twice", "One missed day never breaks your chain. Two in a row does. So a bad day is only ever one day.")
            principle("leaf", "A minimum for hard days", "Every habit has a tiny version. Doing it keeps the chain alive.")
            principle("chart.line.uptrend.xyaxis", "Every check-in is a vote", "Each day you keep is a vote for who you're becoming. Milestones mark 21, 66 and 100 days; 66 is the average time for a habit to feel automatic.")
            Spacer()
            nextButton("Continue") { page = 2 }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 50)
    }

    private var firstHabits: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 30)
            Text("Choose your first habits").font(.heading(30, weight: .bold))
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
                .foregroundStyle(Palette.accent)
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
                .background(Capsule().fill(Palette.accent))
                .foregroundStyle(.white)
        }
        .buttonStyle(PressStyle())
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
