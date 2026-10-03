import SwiftUI
import UserNotifications

@main
struct SadhanaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = AppStore.shared
    @State private var timer = TimerController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(timer)
                .tint(Palette.saffron)
                .onOpenURL { store.handle(url: $0) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    store.refresh()
                    store.consumePendingRoute()
                    timer.resumeIfNeeded(store: store)
                    store.scheduleReminders()
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderScheduler.registerCategories()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let info = content.userInfo
        let action = response.actionIdentifier
        if action == ReminderScheduler.Action.snooze {
            await ReminderScheduler.snooze(content)
            return
        }
        if action == ReminderScheduler.Action.holding { return }
        let kind = info[ReminderScheduler.Key.kind] as? String
        let habit = info[ReminderScheduler.Key.habit] as? String
        let slot = info[ReminderScheduler.Key.slot] as? String
        let day = info[ReminderScheduler.Key.day] as? String
        await MainActor.run {
            AppStore.shared.handleNotification(action: action, kind: kind, habit: habit, slot: slot, day: day)
        }
    }
}
