import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case icelandic = "is"
    case english   = "en"
    case spanish   = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .icelandic: return "Íslenska"
        case .english:   return "English"
        case .spanish:   return "Español"
        }
    }

    var code: String { rawValue.uppercased() }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "taxis.language") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "taxis.language") ?? "is"
        language = AppLanguage(rawValue: saved) ?? .icelandic
    }

    func t(_ key: LKey) -> String { key.string(language) }
}

// swiftlint:disable file_length
enum LKey {
    // Tabs
    case tabHome, tabExpenses, tabSettings, tabInsights, tabRevenue, tabPayslips
    // Actions
    case addEntry, cancel, save, close, scan, manual
    // Section names
    case drivingLog, income, settings
    case abendingar, spurningar
    // FærslurView
    case faerslaSubtitle, searchPlaceholder, questionReceived, questionReceivedBody
    // UtgjoldView / AkstursbokView
    case expenses, drivingLogFull, addDrive, totalKm, estimatedDeduction, rateNote
    case driveFrom, driveTo, driveKm, driveDate, drivePurpose, addTripBtn
    // HomeView
    case overview, noInsightsTitle, noInsightsBody, refresh
    // Common
    case noData, loading, errorGeneric

    // swiftlint:disable cyclomatic_complexity function_body_length
    func string(_ lang: AppLanguage) -> String {
        switch (self, lang) {

        // MARK: Tabs
        case (.tabHome, .english):   return "Home"
        case (.tabHome, .spanish):   return "Inicio"
        case (.tabHome, _):          return "Heim"

        case (.tabExpenses, .english): return "Expenses"
        case (.tabExpenses, .spanish): return "Gastos"
        case (.tabExpenses, _):        return "Útgjöld"

        case (.tabSettings, .english): return "Settings"
        case (.tabSettings, .spanish): return "Ajustes"
        case (.tabSettings, _):        return "Stillingar"

        case (.tabInsights, .english): return "Guide"
        case (.tabInsights, .spanish): return "Guía"
        case (.tabInsights, _):        return "Fræðsla"

        case (.tabRevenue, .english):  return "Revenue"
        case (.tabRevenue, .spanish):  return "Ingresos"
        case (.tabRevenue, _):         return "Tekjur"

        case (.tabPayslips, .english): return "Payslips"
        case (.tabPayslips, .spanish): return "Nóminas"
        case (.tabPayslips, _):        return "Launaseðlar"

        // MARK: Actions
        case (.addEntry, .english): return "Add entry"
        case (.addEntry, .spanish): return "Añadir"
        case (.addEntry, _):        return "Bæta við"

        case (.cancel, .english): return "Cancel"
        case (.cancel, .spanish): return "Cancelar"
        case (.cancel, _):        return "Hætta við"

        case (.save, .english): return "Save"
        case (.save, .spanish): return "Guardar"
        case (.save, _):        return "Vista"

        case (.close, .english): return "Close"
        case (.close, .spanish): return "Cerrar"
        case (.close, _):        return "Loka"

        case (.scan, .english): return "Scan"
        case (.scan, .spanish): return "Escanear"
        case (.scan, _):        return "Skanna"

        case (.manual, .english): return "Enter manually"
        case (.manual, .spanish): return "Ingresar manualmente"
        case (.manual, _):        return "Slá inn handvirkt"

        // MARK: Section names
        case (.drivingLog, .english): return "Driving Log"
        case (.drivingLog, .spanish): return "Diario de conducción"
        case (.drivingLog, _):        return "Akstursbók"

        case (.income, .english): return "Income"
        case (.income, .spanish): return "Ingresos"
        case (.income, _):        return "Tekjur"

        case (.settings, .english): return "Settings"
        case (.settings, .spanish): return "Ajustes"
        case (.settings, _):        return "Stillingar"

        case (.abendingar, .english): return "Tips"
        case (.abendingar, .spanish): return "Consejos"
        case (.abendingar, _):        return "Ábendingar"

        case (.spurningar, .english): return "Questions"
        case (.spurningar, .spanish): return "Preguntas"
        case (.spurningar, _):        return "Spurningar"

        // MARK: FærslurView
        case (.faerslaSubtitle, .english): return "Tax tips and questions for Iceland"
        case (.faerslaSubtitle, .spanish): return "Consejos y preguntas sobre impuestos islandeses"
        case (.faerslaSubtitle, _):        return "Ábendingar og spurningar um íslenska skatta"

        case (.searchPlaceholder, .english): return "e.g. vehicle allowance, VAT, pension..."
        case (.searchPlaceholder, .spanish): return "ej. subsidio vehículo, IVA, pensión..."
        case (.searchPlaceholder, _):        return "t.d. ökutækjastyrkur, VSK, lífeyrir..."

        case (.questionReceived, .english): return "Question received"
        case (.questionReceived, .spanish): return "Pregunta recibida"
        case (.questionReceived, _):        return "Spurning móttekin"

        case (.questionReceivedBody, .english):
            return "Your question has been saved. We will add an answer shortly. Try searching with a different keyword or browse the tips above."
        case (.questionReceivedBody, .spanish):
            return "Tu pregunta ha sido guardada. Añadiremos una respuesta pronto. Prueba buscar con otra palabra clave o revisa los consejos de arriba."
        case (.questionReceivedBody, _):
            return "Spurningin þín hefur verið vistuð. Við munum bæta svari við fljótlega. Prófaðu að leita að öðru lykilorði eða skoðaðu ábendingar að ofan."

        // MARK: Útgjöld / Akstur
        case (.expenses, .english): return "Expenses"
        case (.expenses, .spanish): return "Gastos"
        case (.expenses, _):        return "Útgjöld"

        case (.drivingLogFull, .english): return "Driving Log"
        case (.drivingLogFull, .spanish): return "Diario de conducción"
        case (.drivingLogFull, _):        return "Akstursbók"

        case (.addDrive, .english): return "Log drive"
        case (.addDrive, .spanish): return "Registrar viaje"
        case (.addDrive, _):        return "Skrá akstur"

        case (.totalKm, .english): return "Total km"
        case (.totalKm, .spanish): return "Total km"
        case (.totalKm, _):        return "Heildarkm"

        case (.estimatedDeduction, .english): return "Est. deduction"
        case (.estimatedDeduction, .spanish): return "Deducción est."
        case (.estimatedDeduction, _):        return "Áætlaður frádráttur"

        case (.rateNote, .english): return "66 ISK/km (first 5,000 km) · 40 ISK/km above"
        case (.rateNote, .spanish): return "66 ISK/km (primeros 5.000 km) · 40 ISK/km después"
        case (.rateNote, _):        return "66 kr/km (fyrstu 5.000 km) · 40 kr/km þar yfir"

        case (.driveFrom, .english): return "From"
        case (.driveFrom, .spanish): return "Desde"
        case (.driveFrom, _):        return "Frá"

        case (.driveTo, .english): return "To"
        case (.driveTo, .spanish): return "Hasta"
        case (.driveTo, _):        return "Til"

        case (.driveKm, .english): return "Kilometres"
        case (.driveKm, .spanish): return "Kilómetros"
        case (.driveKm, _):        return "Kílómetrar"

        case (.driveDate, .english): return "Date"
        case (.driveDate, .spanish): return "Fecha"
        case (.driveDate, _):        return "Dagsetning"

        case (.drivePurpose, .english): return "Purpose"
        case (.drivePurpose, .spanish): return "Propósito"
        case (.drivePurpose, _):        return "Erindi"

        case (.addTripBtn, .english): return "Add trip"
        case (.addTripBtn, .spanish): return "Añadir viaje"
        case (.addTripBtn, _):        return "Bæta við ferð"

        // MARK: HomeView
        case (.overview, .english): return "Overview"
        case (.overview, .spanish): return "Resumen"
        case (.overview, _):        return "Yfirlit"

        case (.noInsightsTitle, .english): return "No insights yet"
        case (.noInsightsTitle, .spanish): return "Sin información aún"
        case (.noInsightsTitle, _):        return "Engar ábendingar"

        case (.noInsightsBody, .english): return "Add income or expenses to get an AI-powered summary."
        case (.noInsightsBody, .spanish): return "Añade ingresos o gastos para obtener un resumen inteligente."
        case (.noInsightsBody, _):        return "Bættu við tekjum eða útgjöldum til að fá ábendingar."

        case (.refresh, .english): return "Refresh"
        case (.refresh, .spanish): return "Actualizar"
        case (.refresh, _):        return "Uppfæra"

        // MARK: Common
        case (.noData, .english): return "No data yet"
        case (.noData, .spanish): return "Sin datos aún"
        case (.noData, _):        return "Engin gögn"

        case (.loading, .english): return "Loading..."
        case (.loading, .spanish): return "Cargando..."
        case (.loading, _):        return "Hleð..."

        case (.errorGeneric, .english): return "Something went wrong. Please try again."
        case (.errorGeneric, .spanish): return "Algo salió mal. Por favor intenta de nuevo."
        case (.errorGeneric, _):        return "Eitthvað fór úrskeiðis. Reyndu aftur."
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
// swiftlint:enable file_length
