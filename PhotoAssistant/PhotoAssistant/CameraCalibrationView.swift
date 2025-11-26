import SwiftUI

struct CameraCalibrationView: View {
    @StateObject private var manager = CameraCalibrationManager.shared
    @StateObject private var session = CalibrationSession()
    @State private var showingCalibrationFlow = false
    @State private var selectedCalibration: CameraCalibration?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Main list view
            if showingCalibrationFlow {
                CalibrationFlowView(session: session, isPresented: $showingCalibrationFlow)
            } else {
                calibrationListView
            }
        }
        .navigationTitle("Camera Calibration")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var calibrationListView: some View {
        VStack(spacing: 0) {
            // Header info
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "iphone")
                    Text(manager.deviceModel)
                        .font(.headline)
                }
                .padding(.top)
                
                Text("Calibrate each lens for maximum accuracy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom)
            
            // Start new calibration button
            Button(action: {
                session.reset()
                showingCalibrationFlow = true
            }) {
                Label("Start New Calibration", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            // Existing calibrations list
            if manager.calibrations.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Calibrations Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Calibrate your camera lenses for accurate crop mark sizing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(groupedCalibrations().keys.sorted(), id: \.self) { lensType in
                        Section(header: Text(lensType + " Camera")) {
                            ForEach(groupedCalibrations()[lensType] ?? []) { calibration in
                                CalibrationRow(calibration: calibration)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedCalibration = calibration
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            showingDeleteConfirmation = true
                                            selectedCalibration = calibration
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                            selectedCalibration = nil
                        }) {
                            Label("Delete All Calibrations", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .alert("Delete Calibration?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedCalibration = nil
            }
            Button("Delete", role: .destructive) {
                if let calibration = selectedCalibration {
                    manager.deleteCalibration(calibration)
                } else {
                    manager.deleteAllCalibrations()
                }
                selectedCalibration = nil
            }
        } message: {
            if selectedCalibration != nil {
                Text("Are you sure you want to delete this calibration?")
            } else {
                Text("Are you sure you want to delete all calibrations? This cannot be undone.")
            }
        }
        .sheet(item: $selectedCalibration) { calibration in
            CalibrationDetailView(calibration: calibration)
        }
    }
    
    func groupedCalibrations() -> [String: [CameraCalibration]] {
        Dictionary(grouping: manager.calibrations) { $0.lensType }
    }
}

// MARK: - Calibration Row

struct CalibrationRow: View {
    let calibration: CameraCalibration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(calibration.capturePlane)
                    .font(.headline)
                Spacer()
                accuracyBadge
            }
            
            HStack {
                Label("\(calibration.focalLength)mm", systemImage: "camera.aperture")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(calibration.calibrationDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    var accuracyBadge: some View {
        let percentage = calibration.accuracyPercentage
        let absPercentage = abs(percentage)
        let color: Color = absPercentage < 2 ? .green : absPercentage < 5 ? .orange : .red
        
        return Text("\(percentage > 0 ? "+" : "")\(String(format: "%.1f", percentage))%")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Calibration Detail View

struct CalibrationDetailView: View {
    let calibration: CameraCalibration
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Camera") {
                    DetailRow(label: "Device", value: calibration.deviceModel)
                    DetailRow(label: "Lens", value: calibration.lensType)
                    DetailRow(label: "Zoom Factor", value: String(format: "%.1fx", calibration.zoomFactor))
                }
                
                Section("Format") {
                    DetailRow(label: "Capture Plane", value: calibration.capturePlane)
                    DetailRow(label: "Focal Length", value: "\(calibration.focalLength)mm")
                }
                
                Section("Measurements") {
                    DetailRow(label: "Object Size", value: String(format: "%.2f in", calibration.measuredObjectSize))
                    DetailRow(label: "Distance", value: String(format: "%.2f in", calibration.measuredDistance))
                    DetailRow(label: "Calculated Field", value: String(format: "%.2f in", calibration.calculatedFieldSize))
                }
                
                Section("Calibration Result") {
                    DetailRow(label: "Correction Factor", value: String(format: "%.4f", calibration.correctionFactor))
                    DetailRow(label: "Accuracy", value: "\(calibration.accuracyPercentage > 0 ? "+" : "")\(String(format: "%.1f", calibration.accuracyPercentage))%")
                }
                
                Section("Info") {
                    DetailRow(label: "Calibrated", value: calibration.calibrationDate.formatted(date: .long, time: .shortened))
                    if let notes = calibration.notes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(notes)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Calibration Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationView {
        CameraCalibrationView()
    }
}
