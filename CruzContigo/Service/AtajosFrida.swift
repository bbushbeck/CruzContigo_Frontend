import AppIntents
import Foundation

nonisolated struct HablarConFridaIntent: AppIntent {
    static var title: LocalizedStringResource { "Hablar con Frida" }
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func perform() async throws -> some IntentResult {
        SolicitudesDeFrida.compartidas.abrir()
        return .result()
    }
}

struct PreguntarAFridaIntent: AppIntent {
    static var title: LocalizedStringResource { "Preguntar a Frida" }
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Pregunta", requestValueDialog: "¿Qué quieres preguntarle a Frida?")
    var pregunta: String

    static var parameterSummary: some ParameterSummary {
        Summary("Preguntar a Frida: \(\.$pregunta)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SolicitudesDeFrida.compartidas.abrir(pregunta: pregunta)
        return .result()
    }
}

nonisolated struct RecordatoriosDeHoyConFridaIntent: AppIntent {
    static var title: LocalizedStringResource { "Mis recordatorios de hoy con Frida" }
    static var supportedModes: IntentModes { .background }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard AuthTokenStore.shared.cargar() != nil else {
            return .result(dialog: "Inicia sesión en CruzContigo para consultar tus recordatorios.")
        }
        do {
            let recordatorios = try await RecordatoriosService().listar()
            let resumen = ResumenRecordatoriosFrida.paraSiri(recordatorios)
            return .result(dialog: "\(resumen)")
        } catch {
            try Task.checkCancellation()
            return .result(dialog: "No pude consultar tus recordatorios. Abre CruzContigo para revisar tu sesión y conexión.")
        }
    }
}

nonisolated struct AtajosFrida: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HablarConFridaIntent(),
            phrases: ["Hablar con Frida en \(.applicationName)", "Platicar con Frida en \(.applicationName)"],
            shortTitle: "Hablar con Frida",
            systemImageName: "bubble.left.and.bubble.right"
        )
        AppShortcut(
            intent: PreguntarAFridaIntent(),
            phrases: ["Pregúntale a Frida en \(.applicationName)", "Hacerle una pregunta a Frida en \(.applicationName)"],
            shortTitle: "Preguntar a Frida",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: RecordatoriosDeHoyConFridaIntent(),
            phrases: [
                "Pregúntale a Frida qué recordatorios tengo hoy en \(.applicationName)",
                "Mis recordatorios de hoy en \(.applicationName)"
            ],
            shortTitle: "Recordatorios de hoy",
            systemImageName: "bell"
        )
    }
}
