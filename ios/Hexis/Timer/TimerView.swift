import SwiftUI

/// A calm, full-screen session for a timed habit, with a breathing guide.
struct TimerView: View {
    let habitID: UUID
    let slotID: UUID?

    @Environment(AppStore.self) private var store
    @Environment(TimerController.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let habit = store.habit(habitID)
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0E1230), Color(hex: 0x231B3D), (habit?.color.color ?? Palette.accent).opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let habit {
                if timer.finished == habitID {
                    completion(habit)
                } else if let session = timer.session, session.habitID == habitID {
                    running(habit, session: session)
                } else {
                    ready(habit)
                }
            }
        }
        .foregroundStyle(.white)
        .overlay(alignment: .topTrailing) {
            Button {
                if timer.session?.habitID == habitID && timer.finished != habitID { timer.cancel() }
                timer.acknowledgeFinish()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .glassBackground(in: Circle())
            }
            .foregroundStyle(.white)
            .padding()
            .accessibilityLabel(timer.session?.habitID == habitID ? "Cancel session" : "Close")
        }
        .task(id: taskKey) { await waitForEnd() }
    }

    private var taskKey: String {
        guard let s = timer.session else { return "none" }
        return "\(s.end.timeIntervalSince1970)-\(s.isPaused)"
    }

    private func waitForEnd() async {
        guard let session = timer.session, session.habitID == habitID, !session.isPaused else { return }
        let delay = session.end.timeIntervalSinceNow
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        guard !Task.isCancelled, let current = timer.session, current == session, current.end <= Date() else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { timer.finish(store: store) }
    }

    // MARK: States

    private func ready(_ habit: Habit) -> some View {
        let quote = store.quote(.timer)
        return VStack(spacing: 28) {
            Spacer()
            HabitMark(color: habit.color.color, symbol: habit.symbol, state: .open(progress: 0), size: 110, animated: false)
            VStack(spacing: 6) {
                Text(habit.name).font(.display(32, weight: .bold))
                Text("\(habit.target) minutes").font(.title3).opacity(0.8)
            }
            Text("“\(quote.text)”\n— \(quote.cite)")
                .font(.quote(16))
                .multilineTextAlignment(.center)
                .opacity(0.8)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    timer.start(habit: habit, slotID: slotID, day: store.today)
                }
            } label: {
                Text("Begin")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(habit.color.color))
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private func running(_ habit: Habit, session: TimerController.Session) -> some View {
        VStack(spacing: 24) {
            Spacer()
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: session.isPaused)) { context in
                let remaining = session.remaining(at: context.date)
                let elapsed = context.date.timeIntervalSince(session.start)
                // Breathe in for 4 seconds, out for 4.
                let phase = (1 - cos(2 * .pi * elapsed / 8)) / 2
                let breathingIn = elapsed.truncatingRemainder(dividingBy: 8) < 4
                ZStack {
                    Circle()
                        .fill(habit.color.color.opacity(0.18))
                        .scaleEffect(reduceMotion || session.isPaused ? 0.9 : 0.72 + 0.28 * phase)
                    Ring(fraction: 1 - remaining / session.total, color: habit.color.color, lineWidth: 6)
                        .padding(-8)
                    VStack(spacing: 8) {
                        Text(clock(remaining))
                            .font(.rounded(56, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                        Text(session.isPaused ? "Paused" : (breathingIn ? "Breathe in" : "Breathe out"))
                            .font(.headline)
                            .opacity(0.8)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.6), value: breathingIn)
                    }
                }
                .frame(width: 260, height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(clock(remaining)) left")
            }
            Text(habit.name).font(.display(24, weight: .semibold)).opacity(0.9)
            Spacer()
            HStack(spacing: 14) {
                Button {
                    withAnimation(.snappy) { timer.togglePause() }
                } label: {
                    Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassBackground(in: Capsule())
                }
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { timer.finish(store: store, early: true) }
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(habit.color.color))
                }
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, 24)
            Text("Finishing early still counts as your minimum.")
                .font(.footnote)
                .opacity(0.7)
                .padding(.bottom, 20)
        }
    }

    private func completion(_ habit: Habit) -> some View {
        let quote = store.quote(.timer, salt: 5)
        return VStack(spacing: 24) {
            Spacer()
            HabitMark(color: habit.color.color, symbol: habit.symbol, state: .done, size: 130)
                .transition(.scale.combined(with: .opacity))
            Text("Session complete").font(.display(34, weight: .bold))
            Text("“\(quote.text)”\n— \(quote.cite)")
                .font(.quote(16))
                .multilineTextAlignment(.center)
                .opacity(0.85)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                timer.acknowledgeFinish()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(habit.color.color))
            }
            .buttonStyle(PressStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .sensoryFeedback(.success, trigger: timer.finished)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
