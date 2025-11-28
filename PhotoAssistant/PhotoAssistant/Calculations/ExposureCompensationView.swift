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
    
    // MARK: - UserDefaults Keys
    private let kSelectedFilmID = "ExposureComp.selectedFilmID"
    private let kSelectedAperture = "ExposureComp.selectedAperture"
    private let kSelectedShutterSpeed = "ExposureComp.selectedShutterSpeed"
    private let kSelectedISO = "ExposureComp.selectedISO"
    private let kEVCompensation = "ExposureComp.evCompensation"
    private let kAttachedFilters = "ExposureComp.attachedFilters"
    
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
        .navigationTitle("Exposure Compensation")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedFilm) { oldValue, newValue in
            saveFilm(newValue)
            if let film = newValue {
                if let filmISO = isos.first(where: { $0.value == Double(film.iso) }) {
                    selectedISO = filmISO
                }
            }
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
    
    private let maxShutterSeconds = 28800.0 // 8 hours
    
    private func isOutOfRange(_ seconds: Double) -> Bool {
        seconds > maxShutterSeconds
    }
    
    private func formatShutterOrOutOfRange(_ speed: ShutterSpeed, _ actualSeconds: Double) -> String {
        if isOutOfRange(actualSeconds) {
            return "> 8h"
        }
        return speed.label
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
    
    // MARK: - UserDefaults Save Methods
    
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
