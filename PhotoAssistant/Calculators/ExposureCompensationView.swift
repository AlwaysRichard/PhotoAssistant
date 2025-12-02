//
//  ExposureCompensationView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import SwiftUI

// MARK: - Exposure Compensation View

struct ExposureCompensationView: View {
    // MARK: - Base Settings
    @State private var selectedAperture: FStop
    @State private var selectedShutterSpeed: ShutterSpeed
    @State private var selectedISO: ISOSetting
    @State private var selectedFilm: FilmReciprocity?

    // MARK: - Filter Settings
    @State private var attachedFilters: [AttachedFilter] = []
    @State private var showFiltersView = false

    // MARK: - EV Compensation
    @State private var evCompensation: Double = 0.0

    // MARK: - Data
    private let fStops = FStop.scale(stepMode: .third)
    private let shutterSpeeds = ShutterSpeed.scale(stepMode: .third)
    private let isos = ISOSetting.thirdStopScale
    private let films: [FilmReciprocity]

    // MARK: - Computed Result
    private var calculatedExposure: ExposureResult {
        calculateExposure()
    }

    // MARK: - Computed EV
    private var exposureValue: Double {
        selectedAperture.evOffset + selectedShutterSpeed.evOffset + selectedISO.evOffset
    }

    // MARK: - UserDefaults Keys
    private let kSelectedFilmID = "ExposureComp.selectedFilmID"
    private let kSelectedAperture = "ExposureComp.selectedAperture"
    private let kSelectedShutterSpeed = "ExposureComp.selectedShutterSpeed"
    private let kSelectedISO = "ExposureComp.selectedISO"
    private let kEVCompensation = "ExposureComp.evCompensation"
    private let kAttachedFilters = "ExposureComp.attachedFilters"
    
    // MARK - Define Custom Control State for CameraDisplayView
    let customControlState = CameraDisplayControlState(
        aperturePicker: PickerControl(
            enabled: true,
            disabledTextLabel: "f/--",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        shutterPicker: PickerControl(
            enabled: true,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        ISOPicker: PickerControl(
            enabled: true,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        EVPicker: PickerControl(
            enabled: true,
            disabledTextLabel: "-.-",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        EVValuePicker: PickerControl(
            enabled: true,
            disabledTextLabel: "-.-",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        displayCameraSettings: true
    )

    init() {
        // Load films from JSON
        if let filmURL = Bundle.main.url(forResource: "FilmReciprocityConversionFactors", withExtension: "json"),
           let filmData = try? Data(contentsOf: filmURL),
           let loadedFilms = try? JSONDecoder().decode([FilmReciprocity].self, from: filmData) {
            self.films = loadedFilms.sorted { $0.name < $1.name }
        } else {
            self.films = []
        }

        // Load saved values from UserDefaults or use defaults
        let savedAperture = UserDefaults.standard.double(forKey: kSelectedAperture)
        let savedShutter = UserDefaults.standard.double(forKey: kSelectedShutterSpeed)
        let savedISO = UserDefaults.standard.double(forKey: kSelectedISO)
        let savedEV = UserDefaults.standard.double(forKey: kEVCompensation)

        // Initialize aperture
        if savedAperture > 0, let aperture = fStops.first(where: { abs($0.value - savedAperture) < 0.1 }) {
            _selectedAperture = State(initialValue: aperture)
        } else {
            _selectedAperture = State(initialValue: fStops.first(where: { abs($0.value - 5.6) < 0.1 }) ?? fStops[0])
        }

        // Initialize shutter speed
        if savedShutter > 0, let shutter = shutterSpeeds.first(where: { abs($0.seconds - savedShutter) < 0.0001 }) {
            _selectedShutterSpeed = State(initialValue: shutter)
        } else {
            _selectedShutterSpeed = State(initialValue: shutterSpeeds.first(where: { abs($0.seconds - 1.0/125.0) < 0.0001 }) ?? shutterSpeeds[0])
        }

        // Initialize ISO
        if savedISO > 0, let iso = isos.first(where: { $0.value == savedISO }) {
            _selectedISO = State(initialValue: iso)
        } else {
            _selectedISO = State(initialValue: isos.first(where: { $0.value == 100 }) ?? isos[0])
        }

        // Initialize EV compensation
        _evCompensation = State(initialValue: savedEV)

        // Load saved film
        if let savedFilmID = UserDefaults.standard.string(forKey: kSelectedFilmID),
           let savedFilm = films.first(where: { $0.id == savedFilmID }) {
            _selectedFilm = State(initialValue: savedFilm)
        }

        // Load saved filters
        if let filtersData = UserDefaults.standard.data(forKey: kAttachedFilters),
           let savedFilters = try? JSONDecoder().decode([AttachedFilter].self, from: filtersData) {
            _attachedFilters = State(initialValue: savedFilters)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Replaced cameraDisplaySection with CameraDisplayView
            CameraDisplayView(
                selectedAperture: $selectedAperture,
                selectedShutterSpeed: $selectedShutterSpeed,
                selectedISO: $selectedISO,
                selectedFilm: $selectedFilm,
                selectedCamera: .constant(nil),
                evCompensation: $evCompensation,
                allowFilmSelection: true,
                allowCameraSelection: false,
                controlState: customControlState,
                exposureValue: exposureValue,
                fStops: fStops,
                shutterSpeeds: shutterSpeeds,
                isos: isos,
                films: films,
                cameras: []
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Filter button
            FilterButtonSection(
                totalFilterStops: totalFilterStops,
                onTap: { showFiltersView = true }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            // Results section - fixed at bottom
            resultSection
        }
        .onChange(of: selectedFilm) { oldValue, newValue in
            saveFilm(newValue)
            updateISOForFilm(newValue)
        }
        .onChange(of: selectedAperture) { oldValue, newValue in
            saveAperture(newValue)
        }
        .onChange(of: selectedShutterSpeed) { oldValue, newValue in
            saveShutterSpeed(newValue)
        }
        .onChange(of: selectedISO) { oldValue, newValue in
            saveISO(newValue)
        }
        .onChange(of: evCompensation) { oldValue, newValue in
            saveEVCompensation(newValue)
        }
        .onChange(of: attachedFilters) { oldValue, newValue in
            saveFilters(newValue)
        }
        .sheet(isPresented: $showFiltersView) {
            AttachedFiltersView(attachedFilters: $attachedFilters)
        }
        .navigationTitle("Exposure Compensation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var totalFilterStops: Double {
        attachedFilters.reduce(0) { $0 + $1.stops }
    }

    private let maxShutterSeconds = 28800.0 // 8 hours

    private func isOutOfRange(_ seconds: Double) -> Bool {
        seconds > maxShutterSeconds
    }
    
    // MARK: - Helper Methods
    
    private var showReciprocityInfo: Bool {
        calculatedExposure.reciprocityInfo != nil
    }
    
    private var baseShutterSpeedDisplay: String {
        isOutOfRange(calculatedExposure.calculatedSeconds)
            ? "Out of Range"
            : calculatedExposure.calculatedShutterSpeed.label
    }
    
    private var correctedShutterSpeedDisplay: String {
        isOutOfRange(calculatedExposure.correctedSeconds)
            ? "Out of Range"
            : calculatedExposure.shutterSpeed.label
    }
    
    private func updateISOForFilm(_ film: FilmReciprocity?) {
        if let film = film {
            // Convert film.iso (Int) to Double for comparison
            let filmISOValue = Double(film.iso)
            
            // Find the ISO setting that matches the film's ISO value
            if let filmISO = isos.first(where: { $0.value == filmISOValue }) {
                selectedISO = filmISO
            } else {
                // If exact match not found, find closest ISO
                var closestISO: ISOSetting? = nil
                var smallestDifference = Double.infinity
                
                for iso in isos {
                    let difference = abs(iso.value - filmISOValue)
                    if difference < smallestDifference {
                        smallestDifference = difference
                        closestISO = iso
                    }
                }
                
                if let closest = closestISO {
                    selectedISO = closest
                }
            }
        } else {
            // When "Digital" is selected, reset ISO to 100 if it's not already
            if selectedISO.value != 100 {
                if let iso100 = isos.first(where: { $0.value == 100 }) {
                    selectedISO = iso100
                } else {
                    selectedISO = isos[0]
                }
            }
        }
    }

    // MARK: - Result Section (KEPT)

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 2) {

            // ┌───────────────────────────────────────────────┐
            // │ Title Header                                  │
            // └───────────────────────────────────────────────┘
            HStack {
                Image(systemName: "camera.shutter.button")
                    .font(.system(size: 22))
                    .foregroundColor(.white)

                Spacer()

                Text("Adjustments")
                    .font(.custom("American Typewriter", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)


            // ┌───────────────────────────────────────────────┐
            // │ Base Exposure (After Filters, Before Reciprocity) │
            // └───────────────────────────────────────────────┘
            VStack(alignment: .leading, spacing: 4) {
                ResultRow(label: "Aperture", value: calculatedExposure.aperture.label)
                ResultRow(
                    label: "Shutter Speed",
                    value: isOutOfRange(calculatedExposure.calculatedSeconds)
                        ? "Out of Range"
                        : calculatedExposure.calculatedShutterSpeed.label
                )
                ResultRow(label: "ISO", value: calculatedExposure.iso.label)

                if isOutOfRange(calculatedExposure.calculatedSeconds) {
                    Text("⚠️ Exceeds 8 hour maximum")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                }
            }
            .padding(12)


            // ┌───────────────────────────────────────────────┐
            // │ Reciprocity Section (Height-Stabilized)       │
            // └───────────────────────────────────────────────┘
            ZStack(alignment: .topLeading) {

                // Hidden template to reserve full height
                reciprocityTemplate()
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                // Actual visible reciprocity box
                if let info = calculatedExposure.reciprocityInfo {
                    reciprocityBox(
                        filmName: info.filmName,
                        meteredSeconds: info.meteredSeconds
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showReciprocityInfo)
        }
        .background(Color(white: 0.25))
        .cornerRadius(8)
        .padding()
    }

    @ViewBuilder
    private func reciprocityTemplate() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("With Film reciprocity").font(.caption)
            ResultRow(label: "Aperture", value: "f/8")
            ResultRow(label: "Shutter Speed", value: "1s")
            ResultRow(label: "ISO", value: "100")
            Text("Note: Includes Film Reciprocity 0.0s")
                .font(.caption2)
                .padding(.top, 2)
        }
        .padding(12)
    }


    @ViewBuilder
    private func reciprocityBox(filmName: String, meteredSeconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {

            // Title
            Text("With \(filmName) reciprocity")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.9))

            // Divider under title
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(height: 1)
                .padding(.vertical, 2)

            ResultRow(label: "Aperture", value: calculatedExposure.aperture.label)
            ResultRow(
                label: "Shutter Speed",
                value: isOutOfRange(calculatedExposure.correctedSeconds)
                    ? "Out of Range"
                    : calculatedExposure.shutterSpeed.label
            )
            ResultRow(label: "ISO", value: calculatedExposure.iso.label)

            if isOutOfRange(calculatedExposure.correctedSeconds) {
                Text("⚠️ Exceeds 8 hour maximum")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 2)
            } else if calculatedExposure.reciprocityInfo?.beyondDocumentedRange == true {
                Text("⚠️ Beyond \(filmName) documented reciprocity range")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Calculation Logic (KEPT)

    private func calculateExposure() -> ExposureResult {
        // Start with base EV
        var baseEV = selectedAperture.evOffset + selectedShutterSpeed.evOffset + selectedISO.evOffset

        // Apply EV compensation (positive = more exposure, negative = less exposure)
        baseEV += evCompensation

        // Filters reduce light, so we need MORE exposure (longer shutter/wider aperture/higher ISO)
        // Subtracting filter stops from EV means we need to compensate elsewhere
        let totalFilterStops = calculateFilterStops()
        baseEV -= totalFilterStops  // Filters darken, reducing total EV

        // Use the same aperture and ISO
        let targetAperture = selectedAperture
        let targetISO = selectedISO

        // Calculate required shutter speed to maintain exposure
        // EV = evAperture + evShutter + evISO
        // evShutter = EV - evAperture - evISO
        let requiredShutterEV = baseEV - targetAperture.evOffset - targetISO.evOffset
        let requiredSeconds = pow(2.0, -requiredShutterEV)

        // Find the calculated shutter speed (before reciprocity)
        let calculatedShutter = findClosestShutterSpeed(requiredSeconds)

        // Determine final shutter speed (with or without reciprocity)
        var finalShutterSpeed: ShutterSpeed
        var correctedSeconds = requiredSeconds  // Track actual corrected seconds
        var reciprocityInfo: ReciprocityInfo?

        if let film = selectedFilm {
            // Apply film reciprocity if needed
            let reciprocityResult = applyReciprocity(
                meteredSeconds: requiredSeconds,
                film: film
            )
            correctedSeconds = reciprocityResult.correctedSeconds
            finalShutterSpeed = findClosestShutterSpeed(reciprocityResult.correctedSeconds)

            if reciprocityResult.correctionApplied {
                reciprocityInfo = ReciprocityInfo(
                    filmName: film.name,
                    meteredSeconds: reciprocityResult.meteredSeconds,
                    beyondDocumentedRange: reciprocityResult.beyondDocumentedRange
                )
            }
        } else {
            // Digital - use calculated shutter speed
            finalShutterSpeed = calculatedShutter
        }

        return ExposureResult(
            aperture: targetAperture,
            calculatedShutterSpeed: calculatedShutter,
            calculatedSeconds: requiredSeconds,
            shutterSpeed: finalShutterSpeed,
            correctedSeconds: correctedSeconds,
            iso: targetISO,
            reciprocityInfo: reciprocityInfo
        )
    }

    private func calculateFilterStops() -> Double {
        attachedFilters.reduce(0) { $0 + $1.stops }
    }

    private func applyReciprocity(meteredSeconds: Double, film: FilmReciprocity) -> ReciprocityResult {
        switch film.model {
        case .none(let model):
            // No reciprocity failure
            if meteredSeconds >= model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false,
                    beyondDocumentedRange: false
                )
            }
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: meteredSeconds,
                correctionApplied: false,
                beyondDocumentedRange: false
            )

        case .powerLaw(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false,
                    beyondDocumentedRange: false
                )
            }
            // Power law models don't have an upper bound, so never beyond range
            let corrected = pow(meteredSeconds, model.factor)
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true,
                beyondDocumentedRange: false
            )

        case .lookupTable(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false,
                    beyondDocumentedRange: false
                )
            }
            // Check if beyond documented range
            let maxMetered = model.dataPoints.map { $0.metered }.max() ?? 0.0
            let beyondRange = meteredSeconds > maxMetered

            let corrected = interpolateLookupTable(
                metered: meteredSeconds,
                dataPoints: model.dataPoints
            )
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true,
                beyondDocumentedRange: beyondRange
            )

        case .stopCorrection(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false,
                    beyondDocumentedRange: false
                )
            }
            // Check if beyond documented range
            let maxMetered = model.dataPoints.map { $0.metered }.max() ?? 0.0
            let beyondRange = meteredSeconds > maxMetered

            let stopAdjustment = interpolateStopCorrection(
                metered: meteredSeconds,
                dataPoints: model.dataPoints
            )
            let corrected = meteredSeconds * pow(2.0, stopAdjustment)
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true,
                beyondDocumentedRange: beyondRange
            )
        }
    }

    private func interpolateLookupTable(metered: Double, dataPoints: [LookupTableModel.DataPoint]) -> Double {
        // Find surrounding points
        guard !dataPoints.isEmpty else { return metered }

        // Before first point: return first corrected value
        if metered <= dataPoints.first!.metered {
            return dataPoints.first!.corrected
        }

        // After last point: extrapolate using the slope of the last segment
        if metered >= dataPoints.last!.metered {
            if dataPoints.count >= 2 {
                let p1 = dataPoints[dataPoints.count - 2]
                let p2 = dataPoints[dataPoints.count - 1]
                let slope = (p2.corrected - p1.corrected) / (p2.metered - p1.metered)
                let extrapolated = p2.corrected + slope * (metered - p2.metered)
                return extrapolated
            }
            return dataPoints.last!.corrected
        }

        // Within table: interpolate
        for i in 0..<(dataPoints.count - 1) {
            let p1 = dataPoints[i]
            let p2 = dataPoints[i + 1]

            if metered >= p1.metered && metered <= p2.metered {
                // Linear interpolation
                let ratio = (metered - p1.metered) / (p2.metered - p1.metered)
                return p1.corrected + ratio * (p2.corrected - p1.corrected)
            }
        }

        return metered
    }

    private func interpolateStopCorrection(metered: Double, dataPoints: [StopCorrectionModel.DataPoint]) -> Double {
        guard !dataPoints.isEmpty else { return 0.0 }

        if metered <= dataPoints.first!.metered {
            return dataPoints.first!.stopAdjustment
        }
        if metered >= dataPoints.last!.metered {
            return dataPoints.last!.stopAdjustment
        }

        for i in 0..<(dataPoints.count - 1) {
            let p1 = dataPoints[i]
            let p2 = dataPoints[i + 1]

            if metered >= p1.metered && metered <= p2.metered {
                let ratio = (metered - p1.metered) / (p2.metered - p1.metered)
                return p1.stopAdjustment + ratio * (p2.stopAdjustment - p1.stopAdjustment)
            }
        }

        return 0.0
    }

    private func findClosestShutterSpeed(_ seconds: Double) -> ShutterSpeed {
        shutterSpeeds.min(by: { abs($0.seconds - seconds) < abs($1.seconds - seconds) }) ?? shutterSpeeds[0]
    }

    // MARK: - UserDefaults Save Methods (KEPT)

    private func saveFilm(_ film: FilmReciprocity?) {
        if let film = film {
            UserDefaults.standard.set(film.id, forKey: kSelectedFilmID)
        } else {
            UserDefaults.standard.removeObject(forKey: kSelectedFilmID)
        }
    }

    private func saveAperture(_ aperture: FStop) {
        UserDefaults.standard.set(aperture.value, forKey: kSelectedAperture)
    }

    private func saveShutterSpeed(_ speed: ShutterSpeed) {
        UserDefaults.standard.set(speed.seconds, forKey: kSelectedShutterSpeed)
    }

    private func saveISO(_ iso: ISOSetting) {
        UserDefaults.standard.set(iso.value, forKey: kSelectedISO)
    }

    private func saveEVCompensation(_ ev: Double) {
        UserDefaults.standard.set(ev, forKey: kEVCompensation)
    }

    private func saveFilters(_ filters: [AttachedFilter]) {
        if let encoded = try? JSONEncoder().encode(filters) {
            UserDefaults.standard.set(encoded, forKey: kAttachedFilters)
        }
    }
}

// MARK: - Result Row (KEPT)

struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Supporting Types (KEPT)
// NOTE: Color extension and PlusMinusDiagonalIcon were moved to CameraDisplayView to ensure it compiles independently.

struct ExposureResult {
    let aperture: FStop
    let calculatedShutterSpeed: ShutterSpeed  // Before reciprocity
    let calculatedSeconds: Double              // Actual calculated seconds (may exceed max)
    let shutterSpeed: ShutterSpeed            // After reciprocity (if applicable)
    let correctedSeconds: Double               // Actual corrected seconds (may exceed max)
    let iso: ISOSetting
    let reciprocityInfo: ReciprocityInfo?
}

struct ReciprocityInfo {
    let filmName: String
    let meteredSeconds: Double
    let beyondDocumentedRange: Bool
}

struct ReciprocityResult {
    let meteredSeconds: Double
    let correctedSeconds: Double
    let correctionApplied: Bool
    let beyondDocumentedRange: Bool
}
