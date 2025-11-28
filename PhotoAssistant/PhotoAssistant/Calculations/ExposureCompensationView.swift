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
    @State private var showEVPicker = false
    
    // MARK: - Picker presentation
    @State private var showingFilmPicker = false
    @State private var showingAperturePicker = false
    @State private var showingShutterPicker = false
    @State private var showingISOPicker = false
    
    // MARK: - Data
    private let fStops = FStop.thirdStopScale
    private let shutterSpeeds = ShutterSpeed.thirdStopScale
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
    
    init() {
        // Load films from JSON
        if let filmURL = Bundle.main.url(forResource: "FilmReciprocityConversionFactors", withExtension: "json"),
           let filmData = try? Data(contentsOf: filmURL),
           let loadedFilms = try? JSONDecoder().decode([FilmReciprocity].self, from: filmData) {
            self.films = loadedFilms.sorted { $0.name < $1.name }
        } else {
            self.films = []
        }
        
        // Initialize default values
        _selectedAperture = State(initialValue: fStops.first(where: { abs($0.value - 5.6) < 0.1 }) ?? fStops[0])
        _selectedShutterSpeed = State(initialValue: shutterSpeeds.first(where: { abs($0.seconds - 1.0/125.0) < 0.0001 }) ?? shutterSpeeds[0])
        _selectedISO = State(initialValue: isos.first(where: { $0.value == 100 }) ?? isos[0])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Camera-style display box
            cameraDisplaySection
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // Filter button
            filterButtonSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            Spacer()
            
            // Results section - fixed at bottom
            resultSection
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilmPicker) {
            filmPickerSheet
        }
        .sheet(isPresented: $showingAperturePicker) {
            aperturePickerSheet
        }
        .sheet(isPresented: $showingShutterPicker) {
            shutterPickerSheet
        }
        .sheet(isPresented: $showingISOPicker) {
            isoPickerSheet
        }
        .sheet(isPresented: $showFiltersView) {
            AttachedFiltersView(attachedFilters: $attachedFilters)
        }
        .sheet(isPresented: $showEVPicker) {
            evPickerSheet
        }
    }
    
    // MARK: - Camera Display Section
    
    private var cameraDisplaySection: some View {
        VStack(spacing: 0) {
            // Film/Sensor name with camera icon
            HStack(spacing: 12) {
                // Camera icon - force left aligned
                Image(systemName: "camera.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                
                Spacer(minLength: 8)
                
                // Film/Sensor name - right aligned with better shrinking
                Button(action: { showingFilmPicker = true }) {
                    Text(selectedFilm?.name ?? "Digital")
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Horizontal line
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, 20)
            
            // F-Stop and Shutter Speed
            HStack(alignment: .center, spacing: 20) {
                // F-Stop
                Button(action: { showingAperturePicker = true }) {
                    Text(selectedAperture.label)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Shutter Speed
                Button(action: { showingShutterPicker = true }) {
                    Text(selectedShutterSpeed.label)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            //.padding(.vertical, 12)
            .padding(.top, 8)
            .padding(.bottom, 0) // was 4
            
            // ISO
            HStack {
                Spacer()
                
                if selectedFilm == nil {
                    Button(action: { showingISOPicker = true }) {
                        (
                            Text("ISO ")
                                .font(.custom("American Typewriter", size: 24))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                          +
                            Text(selectedISO.label)
                                .font(.custom("American Typewriter", size: 38))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                        )
                        .lineLimit(1)
                    }
                } else {
                    (
                        Text("ISO ")
                            .font(.custom("American Typewriter", size: 24))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                      +
                        Text(selectedISO.label)
                            .font(.custom("American Typewriter", size: 38))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    )
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            //.padding(.bottom, 8)
            .padding(.top, 0)
            .padding(.bottom, 0) // was 4
            
            // EV and compensation
            HStack {
                Text(String(format: "EV %.1f", exposureValue))
                    .font(.custom("American Typewriter", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: { showEVPicker = true }) {
                    HStack(spacing: 4) {
                        Text(String(format: "%+.1f", evCompensation))
                            .font(.custom("American Typewriter", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                        PlusMinusDiagonalIcon(size: 18, backgroundColor: .black, textColor: .white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            // Bottom horizontal line
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            // Instructional text
            Text("Tap any setting to adjust")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)
        }
        .background(Color(hex: "b8b8b8"))
        .cornerRadius(8)
    }
    
    // MARK: - Filter Button Section
    
    private var filterButtonSection: some View {
        Button(action: { showFiltersView = true }) {
            HStack {
                Image(systemName: "camera.filters")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("Filters")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if totalFilterStops > 0 {
                    Text(String(format: "Stops +%.1f", totalFilterStops))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var totalFilterStops: Double {
        attachedFilters.reduce(0) { $0 + $1.stops }
    }
    
    // MARK: - Result Section
    
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
            // │ Base Exposure                                 │
            // └───────────────────────────────────────────────┘
            VStack(alignment: .leading, spacing: 4) {
                ResultRow(label: "Aperture", value: calculatedExposure.aperture.label)
                ResultRow(label: "Shutter Speed", value: calculatedExposure.calculatedShutterSpeed.label)
                ResultRow(label: "ISO", value: calculatedExposure.iso.label)
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
            .animation(.easeInOut(duration: 0.25),
                       value: calculatedExposure.reciprocityInfo != nil)
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
            ResultRow(label: "Shutter Speed", value: calculatedExposure.shutterSpeed.label)
            ResultRow(label: "ISO", value: calculatedExposure.iso.label)

            /*
            Text(String(format: "Note: Includes Film Reciprocity %.1fs",
                        meteredSeconds))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 2)
            */
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




    
    // MARK: - Picker Sheets
    
    private var filmPickerSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedFilm = nil
                    showingFilmPicker = false
                }) {
                    HStack {
                        Text("Digital")
                        Spacer()
                        if selectedFilm == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(films) { film in
                    Button(action: {
                        selectedFilm = film
                        if let filmISO = isos.first(where: { $0.value == Double(film.iso) }) {
                            selectedISO = filmISO
                        }
                        showingFilmPicker = false
                    }) {
                        HStack {
                            Text(film.name)
                            Spacer()
                            if selectedFilm?.id == film.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sensor/Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilmPicker = false
                    }
                }
            }
        }
    }
    
    private var aperturePickerSheet: some View {
        NavigationView {
            List {
                ForEach(fStops) { fStop in
                    Button(action: {
                        selectedAperture = fStop
                        showingAperturePicker = false
                    }) {
                        HStack {
                            Text(fStop.label)
                            Spacer()
                            if selectedAperture.value == fStop.value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Aperture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAperturePicker = false
                    }
                }
            }
        }
    }
    
    private var shutterPickerSheet: some View {
        NavigationView {
            List {
                ForEach(shutterSpeeds) { speed in
                    Button(action: {
                        selectedShutterSpeed = speed
                        showingShutterPicker = false
                    }) {
                        HStack {
                            Text(speed.label)
                            Spacer()
                            if selectedShutterSpeed.seconds == speed.seconds {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shutter Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingShutterPicker = false
                    }
                }
            }
        }
    }
    
    private var isoPickerSheet: some View {
        NavigationView {
            List {
                ForEach(isos) { iso in
                    Button(action: {
                        selectedISO = iso
                        showingISOPicker = false
                    }) {
                        HStack {
                            Text(iso.label)
                            Spacer()
                            if selectedISO.value == iso.value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ISO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingISOPicker = false
                    }
                }
            }
        }
    }
    
    private var evPickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EV Compensation")
                    .font(.headline)
                    .padding(.top)
                
                Text(String(format: "%+.1f", evCompensation))
                    .font(.system(size: 60, weight: .bold))
                    .monospacedDigit()
                
                Picker("EV", selection: $evCompensation) {
                    ForEach(Array(stride(from: -10.0, through: 10.0, by: 1.0/3.0)), id: \.self) { ev in
                        let rounded = (ev * 10).rounded() / 10.0
                        Text(String(format: "%+.1f", rounded))
                            .tag(rounded)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showEVPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        evCompensation = 0.0
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Calculation Logic
    
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
        var reciprocityInfo: ReciprocityInfo?
        
        if let film = selectedFilm {
            // Apply film reciprocity if needed
            let reciprocityResult = applyReciprocity(
                meteredSeconds: requiredSeconds,
                film: film
            )
            finalShutterSpeed = findClosestShutterSpeed(reciprocityResult.correctedSeconds)
            
            if reciprocityResult.correctionApplied {
                reciprocityInfo = ReciprocityInfo(
                    filmName: film.name,
                    meteredSeconds: reciprocityResult.meteredSeconds
                )
            }
        } else {
            // Digital - use calculated shutter speed
            finalShutterSpeed = calculatedShutter
        }
        
        return ExposureResult(
            aperture: targetAperture,
            calculatedShutterSpeed: calculatedShutter,
            shutterSpeed: finalShutterSpeed,
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
                    correctionApplied: false
                )
            }
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: meteredSeconds,
                correctionApplied: false
            )
            
        case .powerLaw(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false
                )
            }
            let corrected = pow(meteredSeconds, model.factor)
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true
            )
            
        case .lookupTable(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false
                )
            }
            let corrected = interpolateLookupTable(
                metered: meteredSeconds,
                dataPoints: model.dataPoints
            )
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true
            )
            
        case .stopCorrection(let model):
            if meteredSeconds < model.cutoffTime {
                return ReciprocityResult(
                    meteredSeconds: meteredSeconds,
                    correctedSeconds: meteredSeconds,
                    correctionApplied: false
                )
            }
            let stopAdjustment = interpolateStopCorrection(
                metered: meteredSeconds,
                dataPoints: model.dataPoints
            )
            let corrected = meteredSeconds * pow(2.0, stopAdjustment)
            return ReciprocityResult(
                meteredSeconds: meteredSeconds,
                correctedSeconds: corrected,
                correctionApplied: true
            )
        }
    }
    
    private func interpolateLookupTable(metered: Double, dataPoints: [LookupTableModel.DataPoint]) -> Double {
        // Find surrounding points
        guard !dataPoints.isEmpty else { return metered }
        
        if metered <= dataPoints.first!.metered {
            return dataPoints.first!.corrected
        }
        if metered >= dataPoints.last!.metered {
            return dataPoints.last!.corrected
        }
        
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
}

// MARK: - Result Row

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

// MARK: - Supporting Types

struct ExposureResult {
    let aperture: FStop
    let calculatedShutterSpeed: ShutterSpeed  // Before reciprocity
    let shutterSpeed: ShutterSpeed            // After reciprocity (if applicable)
    let iso: ISOSetting
    let reciprocityInfo: ReciprocityInfo?
}

struct ReciprocityInfo {
    let filmName: String
    let meteredSeconds: Double
}

struct ReciprocityResult {
    let meteredSeconds: Double
    let correctedSeconds: Double
    let correctionApplied: Bool
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
