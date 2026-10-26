import Foundation
import HealthKit
import Combine

/// Manages HealthKit permissions and writes blood glucose samples to Apple Health.
@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isHealthKitAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatusMessage: String = "Checking..."
    @Published var authorizationDenied: Bool = false

    private var glucoseType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bloodGlucose)
    }

    /// HealthKit unit for mmol/L using blood glucose molecular mass
    var mmolLUnit: HKUnit {
        HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
    }

    init() {
        checkHealthDataAvailability()
        updateAuthorizationStatus()
    }

    /// Checks if HealthKit is supported on this device.
    func checkHealthDataAvailability() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }

    /// Updates authorization state based on current HealthKit permissions.
    func updateAuthorizationStatus() {
        guard isHealthKitAvailable, let glucoseType = glucoseType else {
            isAuthorized = false
            authorizationStatusMessage = "HealthKit not supported"
            return
        }

        let status = healthStore.authorizationStatus(for: glucoseType)
        switch status {
        case .sharingAuthorized:
            isAuthorized = true
            authorizationDenied = false
            authorizationStatusMessage = "Authorized & Ready"
        case .sharingDenied:
            isAuthorized = false
            authorizationDenied = true
            authorizationStatusMessage = "Denied in iOS Settings"
        case .notDetermined:
            isAuthorized = false
            authorizationDenied = false
            authorizationStatusMessage = "Permission Required"
        @unknown default:
            isAuthorized = false
            authorizationDenied = false
            authorizationStatusMessage = "Unknown"
        }
    }

    /// Requests user authorization to read and write Blood Glucose data.
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        guard let glucoseType = glucoseType else {
            throw HealthKitError.glucoseTypeNotFound
        }

        let writeTypes: Set<HKSampleType> = [glucoseType]
        let readTypes: Set<HKObjectType> = [glucoseType]

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        updateAuthorizationStatus()
    }

    /// Saves an array of `BloodGlucoseReading` models to HealthKit as `HKQuantitySample`s in batches.
    /// - Parameters:
    ///   - readings: List of parsed blood glucose readings.
    ///   - progressHandler: Closure invoked with `(currentSyncedCount, totalCount)`.
    /// - Returns: Total number of samples saved.
    func syncReadings(
        _ readings: [BloodGlucoseReading],
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws -> Int {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailableOnDevice
        }

        guard let glucoseType = glucoseType else {
            throw HealthKitError.glucoseTypeNotFound
        }

        let unit = mmolLUnit
        var samplesToSave: [HKQuantitySample] = []
        samplesToSave.reserveCapacity(readings.count)

        // Guardian 4 CGM device info
        let device = HKDevice(
            name: "Guardian 4",
            manufacturer: "Medtronic",
            model: "CGM",
            hardwareVersion: nil,
            firmwareVersion: nil,
            softwareVersion: nil,
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )

        for reading in readings {
            let quantity = HKQuantity(unit: unit, doubleValue: reading.glucoseMmolL)

            // Deduplication via sync identifier: unique timestamp-based ID
            let syncKey = "bg_\(Int64(reading.date.timeIntervalSince1970))"
            var metadata: [String: Any] = [
                HKMetadataKeyWasUserEntered: false,
                HKMetadataKeySyncIdentifier: syncKey,
                HKMetadataKeySyncVersion: 1
            ]

            if !reading.readingType.isEmpty {
                metadata["ReadingType"] = reading.readingType
            }

            let sample = HKQuantitySample(
                type: glucoseType,
                quantity: quantity,
                start: reading.date,
                end: reading.date,
                device: device,
                metadata: metadata
            )
            samplesToSave.append(sample)
        }

        // Save in batches of 1,000 samples for high performance
        let batchSize = 1000
        var savedCount = 0

        for batchStart in stride(from: 0, to: samplesToSave.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, samplesToSave.count)
            let batch = Array(samplesToSave[batchStart..<batchEnd])

            try await healthStore.save(batch)
            savedCount += batch.count
            progressHandler?(savedCount, samplesToSave.count)

            // Yield cooperatively to keep UI responsive
            await Task.yield()
        }

        updateAuthorizationStatus()
        return savedCount
    }

    /// Fetches the most recent blood glucose samples recorded in HealthKit.
    func fetchRecentSamples(limit: Int = 25) async throws -> [BloodGlucoseReading] {
        guard let glucoseType = glucoseType else { return [] }
        let unit = self.mmolLUnit

        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = quantitySamples.map { sample in
                    let value = sample.quantity.doubleValue(for: unit)
                    let readingType = (sample.metadata?["ReadingType"] as? String) ?? "HealthKit"
                    return BloodGlucoseReading(
                        date: sample.startDate,
                        glucoseMmolL: value,
                        readingType: readingType,
                        sourceFile: "Apple Health"
                    )
                }
                continuation.resume(returning: results)
            }

            self.healthStore.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailableOnDevice
    case glucoseTypeNotFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .notAvailableOnDevice:
            return "HealthKit is not supported on this device."
        case .glucoseTypeNotFound:
            return "Blood glucose type identifier could not be initialized."
        case .parsingFailed:
            return "Failed to parse glucose data from the file."
        }
    }
}
