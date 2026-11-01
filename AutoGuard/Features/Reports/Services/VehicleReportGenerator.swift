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
            .frame(width: 595.2, height: 841.8)

        let renderer = ImageRenderer(content: template)
        renderer.scale = 2.0 // Rezoluție Retina pentru claritate maximă la printare

        let sanitizedPlate = vehicle.plateNumber
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let fileName = "Carte_Service_\(sanitizedPlate.isEmpty ? "Vehicul" : sanitizedPlate).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        do {
            try pdfRenderer.writePDF(to: tempURL) { context in
                context.beginPage()
                renderer.render { size, renderContext in
                    renderContext(context.cgContext)
                }
            }
            return tempURL
        } catch {
            print("Eroare la scrierea fișierului PDF: \(error)")
            return nil
        }
    }
}
