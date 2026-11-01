//
//  TextRecognitionService.swift
//  AutoGuard
//
//  Serviciu pentru analiza și extragerea automată a datelor auto (VIN, Număr de înmatriculare, Dată expirare)
//  folosind Apple Vision și expresii regulate optimizate pentru documentele din România.
//

import Foundation
import UIKit
import Vision

final class TextRecognitionService {
    static let shared = TextRecognitionService()

    private init() {}

    // MARK: - Extragere Serie Șasiu (VIN)
    /// Extrage un cod VIN valid de 17 caractere conform standardului internațional ISO 3779
    func extractVin(from text: String) -> String? {
        // Înlocuim spațiile sau cratimele accidentale apărute la OCR
        let cleanText = text.uppercased()

        // 1. Căutare directă a secvenței de 17 caractere alfanumerice (fără I, O, Q conform ISO)
        let vinPattern = #"\b[A-HJ-NPR-Z0-9]{17}\b"#
        if let regex = try? NSRegularExpression(pattern: vinPattern) {
            let range = NSRange(location: 0, length: cleanText.utf16.count)
            if let match = regex.firstMatch(in: cleanText, range: range),
               let matchRange = Range(match.range, in: cleanText) {
                return String(cleanText[matchRange])
            }
        }

        // 2. Fallback tolerant: eliminăm spații și cratime între blocuri de caractere
        let collapsed = cleanText.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        if let regex = try? NSRegularExpression(pattern: #"[A-HJ-NPR-Z0-9]{17}"#) {
            let range = NSRange(location: 0, length: collapsed.utf16.count)
            if let match = regex.firstMatch(in: collapsed, range: range),
               let matchRange = Range(match.range, in: collapsed) {
                return String(collapsed[matchRange])
            }
        }

        return nil
    }

    // MARK: - Extragere Număr de Înmatriculare
    /// Extrage un număr de înmatriculare românesc (ex: B 123 ABC, CJ 01 XYZ)
    func extractPlateNumber(from text: String) -> String? {
        let cleanText = text.uppercased()

        // Model: București (B 12 ABC / B 123 ABC) sau Județe (ex: CJ 12 ABC, IS 01 ABC)
        let platePattern = #"\b(B|AB|AR|AG|BC|BH|BN|BT|BV|BR|BZ|CS|CL|CJ|CT|CV|DB|DJ|GL|GR|GJ|HR|HD|IL|IS|IF|MM|MH|MS|NT|OT|PH|SM|SJ|SB|SV|TR|TM|TL|VS|VL|VN)[\s-]?(\d{2,3})[\s-]?([A-Z]{3})\b"#

        if let regex = try? NSRegularExpression(pattern: platePattern) {
            let range = NSRange(location: 0, length: cleanText.utf16.count)
            if let match = regex.firstMatch(in: cleanText, range: range) {
                if let countyRange = Range(match.range(at: 1), in: cleanText),
                   let numberRange = Range(match.range(at: 2), in: cleanText),
                   let lettersRange = Range(match.range(at: 3), in: cleanText) {
                    let county = cleanText[countyRange]
                    let number = cleanText[numberRange]
                    let letters = cleanText[lettersRange]
                    return "\(county) \(number) \(letters)"
                }
            }
        }

        return nil
    }

    // MARK: - Extragere Date de Expirare
    /// Găsește toate datele din text și o returnează pe cea mai probabilă ca dată de expirare (cea mai îndepărtată în viitor)
    func extractExpirationDate(from text: String) -> Date? {
        let dates = extractAllDates(from: text)
        guard !dates.isEmpty else { return nil }

        // Preferăm o dată din viitor (expirare)
        let now = Date()
        let futureDates = dates.filter { $0 >= now }
        if let maxFuture = futureDates.max() {
            return maxFuture
        }

        // Dacă toate sunt în trecut, returnăm data cea mai recentă
        return dates.max()
    }

    /// Extrage toate datele dintr-un text în formatele dd.MM.yyyy, dd/MM/yyyy sau dd-MM-yyyy
    func extractAllDates(from text: String) -> [Date] {
        let datePattern = #"\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: datePattern) else { return [] }

        var results: [Date] = []
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, range: range)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")

        for match in matches {
            guard let fullRange = Range(match.range, in: text) else { continue }
            let dateStr = String(text[fullRange])

            for sep in [".", "/", "-"] {
                formatter.dateFormat = "dd\(sep)MM\(sep)yyyy"
                if let date = formatter.date(from: dateStr) {
                    // Validăm un an rezonabil pentru documente auto (2020 - 2040)
                    let year = Calendar.current.component(.year, from: date)
                    if year >= 2020 && year <= 2040 {
                        results.append(date)
                        break
                    }
                }
            }
        }

        return results
    }

    // MARK: - Recunoaștere Text dintr-o Imagine (Offline Apple Vision)
    /// Rulează VNRecognizeTextRequest pe o imagine locală și returnează tot textul extras
    func recognizeText(from image: UIImage) async -> String {
        // Obținem un CGImage valid chiar dacă imaginea provine din CIImage sau alt format
        let cgImage: CGImage?
        if let directCg = image.cgImage {
            cgImage = directCg
        } else if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        } else {
            let format = UIGraphicsImageRendererFormat.default()
            let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
            let renderedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            cgImage = renderedImage.cgImage
        }

        guard let validCgImage = cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: "")
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let fullText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["ro", "en"]

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let handler = VNImageRequestHandler(cgImage: validCgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}

// MARK: - Mapare Orientare UIImage -> CGImagePropertyOrientation
private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
