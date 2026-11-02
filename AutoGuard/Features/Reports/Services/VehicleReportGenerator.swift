//
//  VehicleReportGenerator.swift
//  AutoGuard
//
//  Serviciu pentru randarea și salvarea raportului "Carte de Service" în format PDF nativ.
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class VehicleReportGenerator {
    static let shared = VehicleReportGenerator()

    private init() {}

    /// Generează fișierul PDF A4 pentru vehiculul specificat și returnează URL-ul local temporar
    func generatePdf(for vehicle: Vehicle) -> URL? {
        let template = VehicleReportPdfTemplate(vehicle: vehicle)
            .environment(\.locale, AppLanguage.current.locale)
            .frame(width: 595.2, height: 841.8)

        let renderer = ImageRenderer(content: template)
        renderer.scale = 2.0 // Rezoluție Retina pentru claritate maximă la printare

        let sanitizedPlate = vehicle.plateNumber
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let prefix = AppLanguage.tr("Carte_Service", "Service_Report")
        let fallbackPlate = AppLanguage.tr("Vehicul", "Vehicle")
        let fileName = "\(prefix)_\(sanitizedPlate.isEmpty ? fallbackPlate : sanitizedPlate).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        do {
            try pdfRenderer.writePDF(to: tempURL) { context in
                context.beginPage()
                let cgContext = context.cgContext
                // UIGraphicsPDFRenderer inversează axa Y pentru UIKit (origine sus-stânga),
                // în timp ce ImageRenderer.render se așteaptă la coordonate CoreGraphics standard (origine jos-stânga).
                // Inversăm înapoi axa Y pentru ca PDF-ul să fie randat drept, nu cu susul în jos.
                cgContext.translateBy(x: 0, y: pageBounds.height)
                cgContext.scaleBy(x: 1.0, y: -1.0)
                renderer.render { _, renderContext in
                    renderContext(cgContext)
                }
            }
            return tempURL
        } catch {
            print("Eroare la scrierea fișierului PDF: \(error)")
            return nil
        }
    }
}
