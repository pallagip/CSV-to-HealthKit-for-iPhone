import Foundation

/// High-performance parser for Blood Glucose CSV exports.
nonisolated struct BloodGlucoseCSVParser: Sendable {

    /// Built-in reference sample data (first 50 rows)
    static let referenceSampleCSV: String = """
    Date;Time;Blood Glucose (mmol/L);Reading Type;Event Marker;Source File
    2025-07-01;00:02:20;6,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:07:20;6,60;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:12:20;6,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:17:20;7,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:22:20;7,50;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:27:20;8,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:32:20;8,40;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:37:20;8,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:42:20;9,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:47:20;9,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:52:20;9,60;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;00:57:20;9,50;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:02:20;9,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:07:20;9,90;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:12:20;9,90;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:17:20;10,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:22:20;10,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:27:20;9,90;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:32:20;9,80;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:37:20;9,80;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:42:20;10,10;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:47:20;10,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:52:20;10,40;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;01:57:20;10,40;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:02:20;10,60;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:07:20;10,70;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:12:20;10,90;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:17:20;11,10;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:22:20;11,40;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:27:20;11,50;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:32:20;11,80;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:37:20;12,20;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:42:20;12,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:47:20;12,60;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:52:20;12,80;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;02:57:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:02:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:07:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:12:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:17:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:22:20;13,10;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:27:20;13,40;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:32:20;13,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:37:20;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:42:21;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:47:21;13,00;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:52:21;13,10;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;03:57:21;13,20;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;04:02:21;13,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    2025-07-01;04:07:21;13,30;Sensor glucose;;Patrik Pallagi 2026.10.26.csv
    """

    /// Parses CSV content line-by-line efficiently.
    static func parse(text: String, limit: Int? = nil, sourceFileName: String = "") -> [BloodGlucoseReading] {
        var sanitized = text
        if sanitized.hasPrefix("\u{FEFF}") {
            sanitized.removeFirst()
        }

        guard !sanitized.isEmpty else { return [] }

        var readings: [BloodGlucoseReading] = []
        readings.reserveCapacity(limit ?? 105_000)

        let calendar = Calendar(identifier: .gregorian)
        var delimiter: Character = ";"
        var headerFound = false
        var dateCol = 0
        var timeCol = 1
        var glucoseCol = 2
        var readingTypeCol = 3
        var sourceFileCol = 5

        sanitized.enumerateLines { line, stop in
            if let maxLimit = limit, readings.count >= maxLimit {
                stop = true
                return
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("-------") || trimmed.hasPrefix("#") {
                return
            }

            // Header detection
            if !headerFound {
                delimiter = trimmed.contains(";") ? ";" : ","
                let parts = trimmed.split(separator: delimiter, omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\""))).lowercased() }

                if let dIdx = parts.firstIndex(where: { $0 == "date" || $0.contains("date") }),
                   let tIdx = parts.firstIndex(where: { $0 == "time" }) {
                    let gIdx = parts.firstIndex(where: {
                        $0.contains("blood glucose") ||
                        $0.contains("sensor glucose") ||
                        $0.contains("bg reading") ||
                        $0.contains("glucose")
                    })

                    if let gIdx = gIdx {
                        headerFound = true
                        dateCol = dIdx
                        timeCol = tIdx
                        glucoseCol = gIdx
                        readingTypeCol = parts.firstIndex(where: { $0.contains("reading type") }) ?? 3
                        sourceFileCol = parts.firstIndex(where: { $0.contains("source file") }) ?? 5
                        return
                    }
                }
                headerFound = true
                return
            }

            // Parse data row using substring split to avoid allocations
            let cols = line.split(separator: delimiter, omittingEmptySubsequences: false)
            let maxCol = max(dateCol, timeCol, glucoseCol)
            guard cols.count > maxCol else { return }

            let dateSub = cols[dateCol].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
            let timeSub = cols[timeCol].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
            let valSub = cols[glucoseCol].trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))

            let normalizedVal = valSub.replacingOccurrences(of: ",", with: ".")
            guard let glucoseValue = Double(normalizedVal), glucoseValue > 0 else {
                return
            }

            guard let date = fastParseDate(dateStr: dateSub, timeStr: timeSub, calendar: calendar) else {
                return
            }

            let readingType = (readingTypeCol < cols.count && !cols[readingTypeCol].isEmpty)
                ? String(cols[readingTypeCol]).trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
                : "Sensor glucose"

            let fileSource: String
            if !sourceFileName.isEmpty {
                fileSource = sourceFileName
            } else if sourceFileCol < cols.count && !cols[sourceFileCol].isEmpty {
                fileSource = String(cols[sourceFileCol]).trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"")))
            } else {
                fileSource = "CSV File"
            }

            readings.append(
                BloodGlucoseReading(
                    date: date,
                    glucoseMmolL: glucoseValue,
                    readingType: readingType,
                    sourceFile: fileSource
                )
            )
        }

        return readings
    }

    /// Fast integer-based date parsing for standard ISO/export date strings
    private static func fastParseDate(dateStr: String, timeStr: String, calendar: Calendar) -> Date? {
        let d = Array(dateStr.utf8)
        let t = Array(timeStr.utf8)
        guard d.count >= 10, t.count >= 5 else { return nil }

        // Supports "2025-07-01", "2025/07/01", "2025.07.01"
        let year = Int(d[0] - 48) * 1000 + Int(d[1] - 48) * 100 + Int(d[2] - 48) * 10 + Int(d[3] - 48)
        let month = Int(d[5] - 48) * 10 + Int(d[6] - 48)
        let day = Int(d[8] - 48) * 10 + Int(d[9] - 48)

        // Supports "00:02:20" or "00:02"
        let hour = Int(t[0] - 48) * 10 + Int(t[1] - 48)
        let minute = Int(t[3] - 48) * 10 + Int(t[4] - 48)
        let second = (t.count >= 8) ? (Int(t[6] - 48) * 10 + Int(t[7] - 48)) : 0

        guard year >= 2000 && year <= 2100,
              month >= 1 && month <= 12,
              day >= 1 && day <= 31,
              hour >= 0 && hour <= 23,
              minute >= 0 && minute <= 59 else {
            return nil
        }

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return calendar.date(from: comps)
    }
}
