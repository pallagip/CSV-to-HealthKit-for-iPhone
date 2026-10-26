import Foundation

/// Represents a single blood glucose reading parsed from CSV or recorded in HealthKit.
nonisolated struct BloodGlucoseReading: Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let glucoseMmolL: Double
    let readingType: String
    let sourceFile: String

    init(
        id: UUID = UUID(),
        date: Date,
        glucoseMmolL: Double,
        readingType: String = "Sensor glucose",
        sourceFile: String = ""
    ) {
        self.id = id
        self.date = date
        self.glucoseMmolL = glucoseMmolL
        self.readingType = readingType
        self.sourceFile = sourceFile
    }

    /// Value converted to mg/dL for reference (1 mmol/L ≈ 18.0182 mg/dL)
    var glucoseMgDl: Double {
        glucoseMmolL * 18.0182
    }

    /// Formatted glucose display in mmol/L
    var formattedMmolL: String {
        String(format: "%.2f mmol/L", glucoseMmolL)
    }

    /// Formatted glucose display in mg/dL
    var formattedMgDl: String {
        String(format: "%.0f mg/dL", glucoseMgDl)
    }

    /// Formatted timestamp display
    var formattedDate: String {
        Self.displayDateFormatter.string(from: date)
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

/// Status of the HealthKit synchronization process.
enum SyncStatus: Equatable {
    case idle
    case loadingFile
    case requestingPermission
    case syncing(progress: Double, current: Int, total: Int)
    case success(count: Int)
    case failure(message: String)

    var isProcessing: Bool {
        switch self {
        case .loadingFile, .requestingPermission, .syncing:
            return true
        default:
            return false
        }
    }
}
