import SwiftUI
import UniformTypeIdentifiers
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()

    @State private var allReadings: [BloodGlucoseReading] = []
    @State private var healthKitReadings: [BloodGlucoseReading] = []
    @State private var status: SyncStatus = .idle
    @State private var limitTo50Rows: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var selectedTab: TabSelection = .csvPreview

    enum TabSelection: String, CaseIterable, Identifiable {
        case csvPreview = "CSV Preview"
        case healthKit = "Apple Health"

        var id: String { rawValue }
    }

    /// Preview up to 100 items to keep SwiftUI list rendering lightning fast
    private var previewReadings: [BloodGlucoseReading] {
        Array(allReadings.prefix(100))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Sync Control Card
                VStack(spacing: 14) {
                    healthKitStatusHeader

                    Divider()

                    // Action buttons
                    VStack(spacing: 10) {
                        Button {
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                Text("Choose CSV File from iPhone...")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(status.isProcessing || !healthKitManager.isHealthKitAvailable)

                        Button {
                            Task {
                                await syncBundledReferenceData()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Sync Sample (First 50 Rows)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .disabled(status.isProcessing || !healthKitManager.isHealthKitAvailable)

                        Toggle(isOn: $limitTo50Rows) {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.secondary)
                                Text("Limit import to first 50 rows")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Progress indicator / Status banner
                    statusBanner
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 8)

                // Segmented picker between CSV loaded data and Apple Health synced data
                Picker("View", selection: $selectedTab) {
                    ForEach(TabSelection.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // Readings list
                if selectedTab == .csvPreview {
                    csvReadingsList
                } else {
                    healthKitReadingsList
                }
            }
            .navigationTitle("Blood Glucose Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            healthKitManager.updateAuthorizationStatus()
                            await refreshHealthKitSamples()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                healthKitManager.updateAuthorizationStatus()
                loadBundledSampleData()
                await refreshHealthKitSamples()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text, UTType(filenameExtension: "csv") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var healthKitStatusHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.headline)

                    if !healthKitManager.isHealthKitAvailable {
                        Text("HealthKit is not supported on this device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if healthKitManager.isAuthorized {
                        Label("Access Granted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if healthKitManager.authorizationDenied {
                        Label("Access Denied in Settings", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Label("Permission Not Requested", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                if healthKitManager.isHealthKitAvailable && !healthKitManager.isAuthorized && !healthKitManager.authorizationDenied {
                    Button("Authorize") {
                        Task {
                            try? await healthKitManager.requestAuthorization()
                        }
                    }
                    .font(.footnote)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

            if healthKitManager.authorizationDenied {
                HStack {
                    Text("Please enable Blood Glucose in iPhone Settings > Health > Data Access > MyApp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Settings", destination: url)
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .idle:
            EmptyView()

        case .loadingFile:
            HStack(spacing: 8) {
                ProgressView()
                Text("Reading & parsing CSV file...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .requestingPermission:
            HStack(spacing: 8) {
                ProgressView()
                Text("Requesting Apple Health permissions...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .syncing(let progress, let current, let total):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(.red)
                Text("Syncing \(current) of \(total) samples (\(Int(progress * 100))%)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

        case .success(let count):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Successfully synced \(count) readings to Apple Health!")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 4)

        case .failure(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var csvReadingsList: some View {
        if allReadings.isEmpty {
            ContentUnavailableView(
                "No CSV Readings",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose a CSV file to import and sync blood glucose data.")
            )
        } else {
            List {
                Section {
                    ForEach(previewReadings) { reading in
                        BloodGlucoseRow(reading: reading)
                    }
                } header: {
                    if allReadings.count > 100 {
                        Text("Previewing first 100 of \(allReadings.count) loaded records")
                    } else {
                        Text("Loaded Records (\(allReadings.count))")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var healthKitReadingsList: some View {
        if healthKitReadings.isEmpty {
            ContentUnavailableView(
                "No HealthKit Records",
                systemImage: "heart.slash",
                description: Text("Tap sync to save readings, then pull or tap refresh to view.")
            )
        } else {
            List {
                Section {
                    ForEach(healthKitReadings) { reading in
                        BloodGlucoseRow(reading: reading)
                    }
                } header: {
                    Text("Recent HealthKit Records (\(healthKitReadings.count))")
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Actions

    private func loadBundledSampleData() {
        self.allReadings = BloodGlucoseCSVParser.parse(
            text: BloodGlucoseCSVParser.referenceSampleCSV,
            limit: 50,
            sourceFileName: "sample_blood_glucose.csv"
        )
    }

    private func syncBundledReferenceData() async {
        let referenceReadings = BloodGlucoseCSVParser.parse(
            text: BloodGlucoseCSVParser.referenceSampleCSV,
            limit: 50,
            sourceFileName: "combined_blood_glucose.csv"
        )
        self.allReadings = referenceReadings
        await syncGivenReadings(referenceReadings)
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            let limit = limitTo50Rows ? 50 : nil

            Task {
                // Request security-scoped access inside the task and keep it open while reading
                let accessGranted = selectedURL.startAccessingSecurityScopedResource()
                defer {
                    if accessGranted {
                        selectedURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    status = .loadingFile

                    // Read file data while holding security-scoped access
                    let data = try Data(contentsOf: selectedURL)
                    let text = String(decoding: data, as: UTF8.self)
                    let fileName = selectedURL.lastPathComponent

                    // Parse off the main actor to keep UI responsive for 100k+ rows
                    let parsed = await Task.detached(priority: .userInitiated) {
                        BloodGlucoseCSVParser.parse(text: text, limit: limit, sourceFileName: fileName)
                    }.value

                    self.allReadings = parsed

                    guard !parsed.isEmpty else {
                        status = .failure(message: "No valid blood glucose rows found in CSV.")
                        return
                    }

                    await syncGivenReadings(parsed)
                } catch {
                    status = .failure(message: "Failed reading file: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            status = .failure(message: "Failed to open file: \(error.localizedDescription)")
        }
    }

    private func syncGivenReadings(_ readingsToSync: [BloodGlucoseReading]) async {
        do {
            status = .requestingPermission
            try await healthKitManager.requestAuthorization()

            status = .syncing(progress: 0.0, current: 0, total: readingsToSync.count)
            let totalSaved = try await healthKitManager.syncReadings(readingsToSync) { current, total in
                let progress = Double(current) / Double(total)
                self.status = .syncing(progress: progress, current: current, total: total)
            }

            status = .success(count: totalSaved)
            await refreshHealthKitSamples()

        } catch {
            status = .failure(message: error.localizedDescription)
        }
    }

    private func refreshHealthKitSamples() async {
        guard healthKitManager.isHealthKitAvailable else { return }
        do {
            let samples = try await healthKitManager.fetchRecentSamples(limit: 25)
            self.healthKitReadings = samples
        } catch {
            print("Could not query HealthKit samples: \(error)")
        }
    }
}

// MARK: - Row View

struct BloodGlucoseRow: View {
    let reading: BloodGlucoseReading

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(reading.formattedMmolL)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(glucoseColor(for: reading.glucoseMmolL))

                    Text("(\(reading.formattedMgDl))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(reading.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(reading.readingType)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                if !reading.sourceFile.isEmpty {
                    Text(reading.sourceFile)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func glucoseColor(for mmolL: Double) -> Color {
        switch mmolL {
        case ..<3.9:
            return .red
        case 3.9...10.0:
            return .primary
        case 10.0...13.9:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    ContentView()
}
