import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class DictadoFrida {
    enum Estado: Equatable { case listo, permisos, escuchando, terminando }

    private(set) var estado: Estado = .listo
    private(set) var transcripcion = ""
    private(set) var mensaje: String?

    private let motor = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var solicitud: SFSpeechAudioBufferRecognitionRequest?
    private var tarea: SFSpeechRecognitionTask?
    private var esperaFinal: Task<Void, Never>?
    private var sesionID: UUID?
    private var audioActivo = false
    private var tieneTap = false

    func iniciar() async {
        guard estado == .listo else { return }
        mensaje = nil
        transcripcion = ""

        let id = UUID()
        sesionID = id
        estado = .permisos
        let autorizacion = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard sesionID == id else { return }
        guard autorizacion == .authorized else {
            fallar("Habilita Reconocimiento de voz en Ajustes o escribe tu consulta.")
            return
        }

        let microfono = await AVAudioApplication.requestRecordPermission()
        guard sesionID == id else { return }
        guard microfono else {
            fallar("Habilita el micrófono en Ajustes o escribe tu consulta.")
            return
        }

        // Las consultas pueden contener nombres y datos de salud.
        let recognizers = ["es_MX", "es_ES"].compactMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) }
        guard let recognizer = recognizers.first(where: { $0.supportsOnDeviceRecognition && $0.isAvailable }) else {
            fallar("El dictado en español sin conexión no está disponible. Puedes escribir tu consulta.")
            return
        }
        self.recognizer = recognizer

        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement)
            try audio.setActive(true)
            audioActivo = true

            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0, formato.channelCount > 0 else {
                fallar("El micrófono no está disponible. Puedes escribir tu consulta.")
                return
            }

            let solicitud = SFSpeechAudioBufferRecognitionRequest()
            solicitud.requiresOnDeviceRecognition = true
            solicitud.shouldReportPartialResults = true
            self.solicitud = solicitud
            tarea = recognizer.recognitionTask(with: solicitud) { @Sendable [weak self] resultado, error in
                let texto = resultado?.bestTranscription.formattedString
                let final = resultado?.isFinal == true
                let fallo = error != nil
                guard let self else { return }
                Task { @MainActor in
                    self.recibir(texto: texto, final: final, fallo: fallo, id: id)
                }
            }
            Self.instalarTap(en: entrada, formato: formato, solicitud: solicitud)
            tieneTap = true
            motor.prepare()
            try motor.start()
            estado = .escuchando
        } catch {
            fallar("No pudimos iniciar el micrófono. Intenta de nuevo o escribe tu consulta.")
        }
    }

    func terminar() {
        guard estado == .escuchando else { return }
        estado = .terminando
        detenerAudio()
        solicitud?.endAudio()
        esperaFinal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, self.estado == .terminando else { return }
            self.recibir(texto: nil, final: true, fallo: false, id: self.sesionID)
        }
    }

    func cancelar() {
        sesionID = nil
        esperaFinal?.cancel()
        esperaFinal = nil
        detenerAudio()
        tarea?.cancel()
        tarea = nil
        solicitud = nil
        recognizer = nil
        estado = .listo
    }

    private func recibir(texto: String?, final: Bool, fallo: Bool, id: UUID?) {
        guard let id, id == sesionID else { return }
        if let texto, !texto.isEmpty { transcripcion = texto }
        guard final || fallo else { return }
        if transcripcion.isEmpty {
            mensaje = "No entendí el audio. Puedes dictar de nuevo o escribir."
        }
        cancelar()
    }

    private func fallar(_ mensaje: String) {
        self.mensaje = mensaje
        cancelar()
    }

    private func detenerAudio() {
        if motor.isRunning { motor.stop() }
        if tieneTap {
            motor.inputNode.removeTap(onBus: 0)
            tieneTap = false
        }
        if audioActivo {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioActivo = false
        }
    }

    nonisolated private static func instalarTap(
        en entrada: AVAudioInputNode, formato: AVAudioFormat, solicitud: SFSpeechAudioBufferRecognitionRequest
    ) {
        entrada.installTap(onBus: 0, bufferSize: 1024, format: formato) { buffer, _ in
            solicitud.append(buffer)
        }
    }
}
