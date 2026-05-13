import Foundation
import UserNotifications

/// Manages scheduling and cancelling local reminder notifications for NoteCards.
final class ReminderManager {

    static let shared = ReminderManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func isAuthorized(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Schedule

    /// Schedules a reminder for the given card at the given date.
    /// Cancels any existing reminder for this card first.
    /// Calls completion with the new notification identifier, or nil on failure.
    func schedule(for card: NoteCard, at date: Date, completion: @escaping (String?) -> Void) {
        // Cancel existing notification if any
        cancel(for: card)

        requestPermission { [weak self] granted in
            guard let self, granted else {
                completion(nil)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = card.title.isEmpty ? L10n.reminder : card.title
            if card.comment.isEmpty {
                content.body = L10n.reminderDefaultBody
            } else {
                let body = card.comment
                content.body = body.count > 100 ? String(body.prefix(100)) : body
            }
            content.sound = .default
            content.categoryIdentifier = "DAYPIN_REMINDER"
            content.userInfo = [
                "cardID": card.id.uuidString,
                "cardType": card.type.rawValue
            ]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = UUID().uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            self.center.add(request) { error in
                DispatchQueue.main.async {
                    if error != nil {
                        completion(nil)
                    } else {
                        completion(identifier)
                    }
                }
            }
        }
    }

    // MARK: - Cancel

    func cancel(for card: NoteCard) {
        guard let notifID = card.reminderNotificationID else { return }
        center.removePendingNotificationRequests(withIdentifiers: [notifID])
    }
}
