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

// MARK: - Structură Rezultat Scanare Bon Combustibil
struct FuelReceiptScanResult: Equatable {
    var liters: Double?
    var totalPrice: Double?
    var unitPrice: Double?
    var date: Date?
    var fuelType: FuelType?
    var stationName: String?
    var rawText: String

    init(
        liters: Double? = nil,
        totalPrice: Double? = nil,
        unitPrice: Double? = nil,
        date: Date? = nil,
        fuelType: FuelType? = nil,
        stationName: String? = nil,
        rawText: String = ""
    ) {
        self.liters = liters
        self.totalPrice = totalPrice
        self.unitPrice = unitPrice
        self.date = date
        self.fuelType = fuelType
        self.stationName = stationName
        self.rawText = rawText
    }

    var hasUsableData: Bool {
        liters != nil || totalPrice != nil
    }
}

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

    // MARK: - Extragere Date Bon Fiscal Combustibil
    /// Analizează textul scanat de pe un bon fiscal din benzinăriile din România și extrage:
    /// cantitatea în litri, totalul de plată (lei), tipul de carburant, stația peco și data.
    func extractFuelReceiptData(from text: String) -> FuelReceiptScanResult {
        let clean = text.uppercased()

        var result = FuelReceiptScanResult(rawText: text)

        func parseDouble(_ raw: String) -> Double? {
            let normalized = raw
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }

        // 1. Extragere Litri (cantitate) și Preț Unitar (lei/L)
        // Suportă 1–4 zecimale (ex. OMV/Petrom: "48,6002 L X 9,93", Rompetrol/MOL: "48.60 L * 9.93", sau "9,93 X 48,6002 L")
        let litersAndUnitPatterns: [(pattern: String, litersGroup: Int, unitGroup: Int?)] = [
            (#"(\d{1,3}[.,]\s?\d{1,4})\s*(?:L\b|LTR|LITRI|LITRE)?\s*(?:X|\*)\s*(\d{1,2}[.,]\s?\d{2,4})"#, 1, 2),
            (#"(\d{1,2}[.,]\s?\d{2,4})\s*(?:LEI|RON)?\s*(?:X|\*)\s*(\d{1,3}[.,]\s?\d{1,4})\s*(?:L\b|LTR|LITRI|LITRE)"#, 2, 1),
            (#"(?:CANTITATE|CANT\.?|VOLUM)?[\s:]*(\d{1,3}[.,]\s?\d{1,4})\s*(?:L\b|LTR|LITRI|LITRE)"#, 1, nil)
        ]

        for item in litersAndUnitPatterns {
            if let regex = try? NSRegularExpression(pattern: item.pattern) {
                let range = NSRange(location: 0, length: clean.utf16.count)
                if let match = regex.firstMatch(in: clean, range: range),
                   let litersRange = Range(match.range(at: item.litersGroup), in: clean),
                   let val = parseDouble(String(clean[litersRange])),
                   val > 1 && val < 300 {
                    result.liters = (val * 100).rounded() / 100
                    if let unitGroup = item.unitGroup,
                       match.numberOfRanges > unitGroup,
                       let unitRange = Range(match.range(at: unitGroup), in: clean),
                       let unitVal = parseDouble(String(clean[unitRange])),
                       unitVal > 2 && unitVal < 25 {
                        result.unitPrice = unitVal
                        // Calculăm și prețul total exact din cantitate * preț unitar (ex: 48.6002 * 9.93 = 482.60)
                        let computedTotal = (val * unitVal * 100).rounded() / 100
                        if computedTotal > 5 && computedTotal < 5000 {
                            result.totalPrice = computedTotal
                        }
                    }
                    break
                }
            }
        }

        // 2. Extragere Total (Preț Total în Lei) din liniile fiscale dacă nu a fost deja calculat sau pentru validare
        let totalPatterns: [(pattern: String, group: Int)] = [
            (#"(?:TOTAL\s*LEI|TOTAL\s*RON|VALOARE\s*TOTALA|TOTAL\s*DE\s*PLATA|DE\s*PLATA)[\s:.\-]*(\d{1,5}[.,]\s?\d{2})(?!\d)"#, 1),
            (#"(?:CARTE\s*CREDIT|CARD\s*BANCAR|PLATA\s*CARD|CONTACTLESS|CARD|NUMERAR)[\s:.\-]*(\d{1,5}[.,]\s?\d{2})(?!\d)"#, 1),
            (#"TOTAL\s*:(?!\s*TAXE)[\s\n\r]*(\d{1,5}[.,]\s?\d{2})(?!\d)"#, 1),
            (#"(?<!TAXE:\s)(?<!TVA\s)(\d{2,5}[.,]\s?\d{2})\s*[A-BА]\b"#, 1)
        ]

        if result.totalPrice == nil {
            for item in totalPatterns {
                if let regex = try? NSRegularExpression(pattern: item.pattern) {
                    let range = NSRange(location: 0, length: clean.utf16.count)
                    if let match = regex.firstMatch(in: clean, range: range),
                       let matchRange = Range(match.range(at: item.group), in: clean),
                       let val = parseDouble(String(clean[matchRange])),
                       val > 5 && val < 5000 {
                        result.totalPrice = val
                        break
                    }
                }
            }
        }

        // Dacă avem totalul și prețul unitar, dar nu am putut citi litrii, îi deducem matematic
        if result.liters == nil, let total = result.totalPrice, let unit = result.unitPrice, unit > 0 {
            result.liters = ((total / unit) * 100).rounded() / 100
        }

        // 3. Extragere Dată Bon
        let dates = extractAllDates(from: text)
        let now = Date()
        let pastDates = dates.filter { $0 <= now }
        result.date = pastDates.max() ?? dates.first

        // 4. Detecție Nume Benzinărie / Stație Peco
        let stations = [
            ("OMV", "OMV"),
            ("PETROM", "Petrom"),
            ("ROMPETROL", "Rompetrol"),
            ("MOL", "MOL"),
            ("LUKOIL", "Lukoil"),
            ("SOCAR", "Socar"),
            ("GAZPROM", "Gazprom"),
            ("TSV", "TSV")
        ]
        for (keyword, name) in stations {
            if clean.contains(keyword) {
                result.stationName = name
                break
            }
        }

        // 5. Detecție Tip Carburant (ordonat după denumiri specifice de produs pentru a evita potriviri false pe cifre din coduri fiscale)
        if clean.contains("OMVMAXX95") || clean.contains("MAXXMOTION 95") || clean.contains("MAXX 95")
            || clean.contains("EFECTA 95") || clean.contains("ECTO 95") || clean.contains("EVO 95")
            || clean.contains("BENZINA 95") || clean.contains("EUROSUPER 95") || clean.contains("FARA PLUMB 95") {
            result.fuelType = .petrol95
        } else if clean.contains("OMVMAXX100") || clean.contains("MAXXMOTION 100") || clean.contains("MAXX 100")
            || clean.contains("ECTO 100") || clean.contains("ECTO SPORT 98") || clean.contains("EVO 100")
            || clean.contains("EVO PLUS") || clean.contains("BENZINA 98") || clean.contains("BENZINA 100")
            || clean.contains("SUPER 100") || clean.contains("COR 98") || clean.contains("COR 100") {
            result.fuelType = .petrol98
        } else if clean.contains("EXTRA DIESEL") || clean.contains("MAXXMOTION DIESEL") || clean.contains("OMVMAXXDIESEL")
            || clean.contains("EVO DIESEL") || clean.contains("MOTORINA EXTRA") || clean.contains("ECTO DIESEL") {
            result.fuelType = .premiumDiesel
        } else if clean.contains("DIESEL") || clean.contains("MOTORINA") {
            result.fuelType = .diesel
        } else if clean.contains("BENZIN") {
            result.fuelType = .petrol95
        } else if clean.contains("GPL") || clean.contains("LPG") || clean.contains("AUTOGAS") {
            result.fuelType = .lpg
        } else if clean.contains("GNC") || clean.contains("CNG") {
            result.fuelType = .cng
        }

        return result
    }

    /// Extrage toate datele dintr-un text în formatele dd.MM.yyyy, dd/MM/yyyy, dd-MM-yyyy sau yyyy.MM.dd / yyyy-MM-dd
    func extractAllDates(from text: String) -> [Date] {
        var results: [Date] = []
        let range = NSRange(location: 0, length: text.utf16.count)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")

        // 1. Format dd.MM.yyyy / dd/MM/yyyy / dd-MM-yyyy (tolerant la caractere parazite lipite după an)
        let dmyPattern = #"(?<!\d)(\d{1,2})[./\-](\d{1,2})[./\-](20\d{2})(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: dmyPattern) {
            for match in regex.matches(in: text, range: range) {
                guard let fullRange = Range(match.range, in: text) else { continue }
                let dateStr = String(text[fullRange])
                for sep in [".", "/", "-"] {
                    formatter.dateFormat = "dd\(sep)MM\(sep)yyyy"
                    if let date = formatter.date(from: dateStr) {
                        let year = Calendar.current.component(.year, from: date)
                        if year >= 2020 && year <= 2040 {
                            results.append(date)
                            break
                        }
                    }
                }
            }
        }

        // 2. Format yyyy.MM.dd / yyyy/MM/dd / yyyy-MM-dd (utilizat frecvent pe bonurile OMV/Petrom POS: ex. "2026.11.06 13:47")
        let ymdPattern = #"(?<!\d)(20\d{2})[./\-](\d{1,2})[./\-](\d{1,2})(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: ymdPattern) {
            for match in regex.matches(in: text, range: range) {
                guard let fullRange = Range(match.range, in: text) else { continue }
                let dateStr = String(text[fullRange])
                for sep in [".", "/", "-"] {
                    formatter.dateFormat = "yyyy\(sep)MM\(sep)dd"
                    if let date = formatter.date(from: dateStr) {
                        let year = Calendar.current.component(.year, from: date)
                        if year >= 2020 && year <= 2040 {
                            results.append(date)
                            break
                        }
                    }
                }
            }
        }

        return results
    }

    // MARK: - Scanare Bon Fiscal Multi-Orientare (Rezistent la Fotografii Rotite 90°/180°)
    /// Scanează o imagine a unui bon fiscal încercând orientarea nativă și, dacă datele sunt incomplete,
    /// testează și orientările rotite (util când bonul este fotografiat pe orizontală / oblic).
    func scanFuelReceipt(from image: UIImage) async -> FuelReceiptScanResult {
        let primaryOrientation = CGImagePropertyOrientation(image.imageOrientation)
        let primaryText = await recognizeText(from: image, orientationOverride: primaryOrientation)
        var bestResult = extractFuelReceiptData(from: primaryText)
        var bestScore = score(for: bestResult)

        if bestScore >= 4 {
            return bestResult
        }

        let fallbackOrientations: [CGImagePropertyOrientation] = [.up, .right, .left, .down]
            .filter { $0 != primaryOrientation }

        for orientation in fallbackOrientations {
            let text = await recognizeText(from: image, orientationOverride: orientation)
            guard !text.isEmpty else { continue }
            let candidate = extractFuelReceiptData(from: text)
            let candidateScore = score(for: candidate)
            if candidateScore > bestScore {
                bestResult = candidate
                bestScore = candidateScore
                if bestScore >= 4 {
                    break
                }
            }
        }

        return bestResult
    }

    private func score(for result: FuelReceiptScanResult) -> Int {
        var points = 0
        if result.liters != nil { points += 2 }
        if result.totalPrice != nil { points += 2 }
        if result.unitPrice != nil { points += 1 }
        if result.date != nil { points += 1 }
        if result.stationName != nil { points += 1 }
        if result.fuelType != nil { points += 1 }
        return points
    }

    // MARK: - Recunoaștere Text dintr-o Imagine (Offline Apple Vision)
    /// Rulează VNRecognizeTextRequest pe o imagine locală și returnează tot textul extras
    func recognizeText(from image: UIImage, orientationOverride: CGImagePropertyOrientation? = nil) async -> String {
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

            let orientation = orientationOverride ?? CGImagePropertyOrientation(image.imageOrientation)
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
