import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var importing = false
    @State private var pendingImport: ImportedBackup?
    @State private var exportURL: URL?

    var body: some View {
        Form {
            remindersSection
            ritualsSection
            wisdomSection
            freshStartSection
            if !DataFile.isShared { widgetSection }
            backupSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
        .navigationTitle("Settings")
        .task { notificationStatus = await ReminderScheduler.authorizationStatus() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try Backup.read(Data(contentsOf: url))
            } catch {
                store.toast = Toast(message: BackupError.unreadable.errorDescription ?? "Couldn't read that file.", symbol: "exclamationmark.triangle")
            }
        }
        .confirmationDialog(importTitle, isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
            Button(importButton, role: importIsReplace ? .destructive : nil) {
                if let pendingImport { store.restore(pendingImport) }
                pendingImport = nil
            }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: {
            Text(importIsReplace ? "This replaces every habit, check-in and reflection in Hexis with the backup." : "These habits and their check-ins are added alongside what you already have.")
        }
        .onAppear { exportURL = try? store.exportBackup() }
    }

    // MARK: Sections

    private var remindersSection: some View {
        Section {
            switch notificationStatus {
            case .denied:
                Label("Reminders are off in iPhone Settings.", systemImage: "bell.slash").foregroundStyle(Palette.danger)
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .notDetermined:
                Button("Turn on reminders") {
                    Task {
                        _ = await ReminderScheduler.requestAuthorization()
                        notificationStatus = await ReminderScheduler.authorizationStatus()
                        store.scheduleReminders()
                    }
                }
            default:
                Label("Reminders are on", systemImage: "bell.badge").foregroundStyle(Palette.success)
            }
            Toggle("Gentle follow-up", isOn: pref(\.followUps))
            if store.prefs.followUps {
                Picker("Follow up after", selection: pref(\.followUpMinutes)) {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("If a habit is still open after its time, one follow-up suggests the minimum version. Reminders for things you've already done are cancelled.")
        }
        .listRowBackground(Palette.card)
    }

    private var ritualsSection: some View {
        Section {
            Toggle("Morning Sankalpa", isOn: pref(\.morningRitual))
            if store.prefs.morningRitual {
                DatePicker("Remind me at", selection: timePref(\.morningTime), displayedComponents: .hourAndMinute)
            }
            Toggle("Evening review", isOn: pref(\.eveningReview))
            if store.prefs.eveningReview {
                DatePicker("Remind me at", selection: timePref(\.eveningTime), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Daily rituals")
        } footer: {
            Text("Marcus Aurelius prepared each morning; Seneca reviewed each night. Both take under two minutes.")
        }
        .listRowBackground(Palette.card)
    }

    private var wisdomSection: some View {
        Section("Wisdom") {
            Picker("Quotes from", selection: pref(\.tradition)) {
                Text("Stoic and Hindu").tag(Tradition.both)
                Text("Stoic").tag(Tradition.stoic)
                Text("Hindu").tag(Tradition.hindu)
            }
            Toggle("Show Sanskrit and Hindi originals", isOn: pref(\.showSanskrit))
        }
        .listRowBackground(Palette.card)
    }

    private var freshStartSection: some View {
        Section {
            Toggle("Mark my birthday", isOn: Binding(
                get: { store.prefs.birthdayMonth != nil },
                set: { on in store.updatePreferences { p in
                    if on { p.birthdayMonth = store.today.month; p.birthdayDay = store.today.day } else { p.birthdayMonth = nil; p.birthdayDay = nil }
                } }
            ))
            if let month = store.prefs.birthdayMonth, let day = store.prefs.birthdayDay {
                DatePicker("Birthday", selection: Binding(
                    get: { DayKey(year: store.today.year, month: month, day: day).date(at: TimeOfDay(12, 0)) },
                    set: { date in let key = DayKey(date); store.updatePreferences { $0.birthdayMonth = key.month; $0.birthdayDay = key.day } }
                ), displayedComponents: .date)
            }
        } header: {
            Text("Fresh starts")
        } footer: {
            Text("Mondays, the 1st of each month and your birthday get a fresh-start card. New beginnings make it easier to recommit.")
        }
        .listRowBackground(Palette.card)
    }

    private var widgetSection: some View {
        Section("Widgets") {
            Label("Widgets can't see your habits because the App Group isn't set up for this build. The app works normally; see the README to turn widgets on.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .listRowBackground(Palette.card)
    }

    private var backupSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) { Label("Save a backup", systemImage: "square.and.arrow.up") }
            }
            Button { importing = true } label: { Label("Restore or import a backup", systemImage: "square.and.arrow.down") }
        } header: {
            Text("Backup")
        } footer: {
            Text("Your data lives on this iPhone. Save a backup to Files or iCloud Drive now and then. You can also import a backup from the Habit Chain web tracker.")
        }
        .listRowBackground(Palette.card)
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Quotes", value: "\(store.quotes.quotes.count) Stoic and Hindu")
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
        }
        .listRowBackground(Palette.card)
    }

    // MARK: Helpers

    private func pref<T>(_ keyPath: WritableKeyPath<Preferences, T>) -> Binding<T> {
        Binding(get: { store.prefs[keyPath: keyPath] }, set: { value in store.updatePreferences { $0[keyPath: keyPath] = value } })
    }

    private func timePref(_ keyPath: WritableKeyPath<Preferences, TimeOfDay>) -> Binding<Date> {
        Binding(get: { store.prefs[keyPath: keyPath].asDate }, set: { date in store.updatePreferences { $0[keyPath: keyPath] = TimeOfDay(date) } })
    }

    private var importIsReplace: Bool {
        if case .hexis = pendingImport { return true }
        return false
    }

    private var importTitle: String {
        switch pendingImport {
        case .hexis(let data): return "Restore \(data.habits.count) habits from this backup?"
        case .habitChain(let habits, _): return "Import \(habits.count) habits from Habit Chain?"
        case .none: return ""
        }
    }

    private var importButton: String { importIsReplace ? "Replace everything" : "Import" }
}
