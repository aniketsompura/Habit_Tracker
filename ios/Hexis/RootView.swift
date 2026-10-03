import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
                .tag(AppTab.today)
            HabitsView()
                .tabItem { Label("Habits", systemImage: "list.bullet.circle") }
                .tag(AppTab.habits)
            JourneyView()
                .tabItem { Label("Journey", systemImage: "circle.hexagongrid") }
                .tag(AppTab.journey)
            WisdomView()
                .tabItem { Label("Wisdom", systemImage: "book.closed") }
                .tag(AppTab.wisdom)
        }
        .overlay(alignment: .top) { ToastHost() }
        .overlay { CelebrationOverlay() }
        .sheet(item: sheetRoute) { route in
            Group {
                switch route {
                case .sankalpa: SankalpaSheet()
                case .review: ReviewSheet()
                case .newHabit: HabitEditorView(habit: nil, today: store.today)
                case .editHabit(let id): HabitEditorView(habit: store.habit(id), today: store.today)
                case .timer: EmptyView()
                }
            }
            .environment(store)
            .environment(TimerController.shared)
        }
        .fullScreenCover(item: timerRoute) { route in
            if case .timer(let habitID, let slotID) = route {
                TimerView(habitID: habitID, slotID: slotID)
                    .environment(store)
                    .environment(TimerController.shared)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !store.prefs.onboarded }, set: { _ in })) {
            OnboardingView()
                .environment(store)
        }
    }

    private var sheetRoute: Binding<Route?> {
        Binding(
            get: { if case .timer = store.route { return nil } else { return store.route } },
            set: { store.route = $0 }
        )
    }

    private var timerRoute: Binding<Route?> {
        Binding(
            get: { if case .timer = store.route { return store.route } else { return nil } },
            set: { store.route = $0 }
        )
    }
}

/// Shows the store's toast for a few seconds, sliding in from the top.
struct ToastHost: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if let toast = store.toast {
                ToastView(toast: toast, showOriginal: store.prefs.showSanskrit)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation(.snappy) { store.toast = nil } }
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: toast.quote == nil ? 2_800_000_000 : 5_500_000_000)
                        withAnimation(.snappy) { if store.toast?.id == toast.id { store.toast = nil } }
                    }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.toast)
        .padding(.top, 4)
    }
}

/// When the last habit of the day is done: confetti falls and a line of wisdom appears.
struct CelebrationOverlay: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var startedAt = Date()

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .onTapGesture { withAnimation { visible = false } }
                if !reduceMotion {
                    ConfettiField(start: startedAt).ignoresSafeArea().allowsHitTesting(false)
                }
                VStack(spacing: 14) {
                    DoneRow(count: 5, size: 38)
                    Text("All done for today").font(.heading(28, weight: .bold)).foregroundStyle(Palette.ink)
                    QuoteBlock(quote: store.quote(.dayComplete), showOriginal: false, size: 15)
                }
                .padding(22)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.card))
                .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
                .padding(28)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .onTapGesture { withAnimation { visible = false } }
            }
        }
        .sensoryFeedback(.success, trigger: store.celebration)
        .onChange(of: store.celebration) { _, _ in
            startedAt = Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { visible = true }
            Task {
                try? await Task.sleep(nanoseconds: 4_200_000_000)
                withAnimation(.easeOut(duration: 0.5)) { visible = false }
            }
        }
    }
}

/// Confetti in the habit colors, falling and tumbling.
struct ConfettiField: View {
    var start: Date

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(start)
                let colors = HabitColor.allCases.map(\.color)
                for i in 0..<90 {
                    let seed = Double(i) * 12.9898
                    let rx = abs((sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1))
                    let delay = abs(sin(seed * 2.3)) * 0.6
                    let life = t - delay
                    guard life > 0 else { continue }
                    let speed = 260 + abs(sin(seed * 1.7)) * 320
                    let x = size.width * rx + sin(life * 3 + seed) * 26
                    let y = -30 + life * speed
                    guard y < size.height + 30 else { continue }
                    let fade = max(0, 1 - life / 3.4)
                    let w = 6 + abs(sin(seed * 3.1)) * 6
                    var piece = ctx
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(life * (2 + abs(sin(seed)) * 4) + seed))
                    let rect = CGRect(x: -w / 2, y: -w * 0.3, width: w, height: w * 0.6)
                    piece.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(colors[i % colors.count].opacity(fade)))
                }
            }
        }
    }
}
