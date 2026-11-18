import Foundation
import UserNotifications

struct NotificationHandler {
    private let center = UNUserNotificationCenter.current()

    func actualizar(_ recordatorio: Recordatorio, nombre: String) async {
        cancelar(id: recordatorio.id)
        guard !recordatorio.completado, recordatorio.fecha > .now else { return }
        do {
            guard try await center.requestAuthorization(options: [.alert, .badge, .sound]) else { return }

            let content = UNMutableNotificationContent()
            content.title = "CruzContigo"
            content.body = "\(nombre): \(recordatorio.titulo)"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, recordatorio.fecha.timeIntervalSinceNow),
                repeats: false
            )
            try await center.add(UNNotificationRequest(
                identifier: recordatorio.id.uuidString, content: content, trigger: trigger
            ))
        } catch {
            // La notificación local es opcional. El recordatorio ya está guardado en la API.
            return
        }
    }

    func cancelar(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}
