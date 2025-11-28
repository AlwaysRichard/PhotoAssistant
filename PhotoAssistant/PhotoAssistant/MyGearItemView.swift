import SwiftUI

struct CapturePlane: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let width: Double
    let height: Double
    let diagonal: Double
    
    static func == (lhs: CapturePlane, rhs: CapturePlane) -> Bool {
        lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct MyGearItemView: View {
    @State var gear: MyGearModel
    var onUpdate: (MyGearModel) -> Void
    var onDelete: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var showAddLens = false
    @State private var showCapturePlaneSheet = false
    @State private var editingLens: Lens?
    @State private var capturePlanes: [CapturePlane] = []
    @State private var selectedPlaneIndex: Int = 0
    @State private var lenses: [Lens] = []

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Camera")) {
                    HStack {
                        TextField("Camera Name", text: $gear.cameraName)
                    }
                    Picker("Capture Plane:", selection: $selectedPlaneIndex) {
                        ForEach(Array(capturePlanes.enumerated()), id: \.offset) { index, plane in
                            Text(plane.name).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedPlaneIndex) { oldValue, newValue in
                        print("Picker index changed from \(oldValue) to \(newValue)")
                        guard newValue < capturePlanes.count else { return }
                        let plane = capturePlanes[newValue]
                        print("Selected plane: \(plane.name)")
                        gear.capturePlane = plane.name
                        gear.capturePlaneWidth = plane.width
                        gear.capturePlaneHeight = plane.height
                        gear.capturePlaneDiagonal = plane.diagonal
                    }
                }
                Section(header: Text("Lenses")) {
                    // Sort primes first by focal length, then zooms by their min focal length
                    let sortedLenses = lenses.sorted { lhs, rhs in
                        if lhs.type == .prime, rhs.type == .prime {
                            return (lhs.primeFocalLength ?? 0) < (rhs.primeFocalLength ?? 0)
                        } else if lhs.type == .prime {
                            return true
                        } else if rhs.type == .prime {
                            return false
                        } else {
                            // Both are zooms
                            return (lhs.zoomRange?.min ?? 0) < (rhs.zoomRange?.min ?? 0)
                        }
                    }
                    ForEach(sortedLenses) { lens in
                        Button(action: {
                            editingLens = lens
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(lens.name).font(.headline)
                                        .foregroundColor(.primary)
                                    if lens.type == .prime, let focal = lens.primeFocalLength {
                                        Text("Prime: \(focal)mm")
                                            .foregroundColor(.secondary)
                                    } else if lens.type == .zoom, let range = lens.zoomRange {
                                        Text("Zoom: \(range.min)-\(range.max)mm")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    if let index = lenses.firstIndex(where: { $0.id == lens.id }) {
                                        lenses.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete { indexSet in
                        lenses.remove(atOffsets: indexSet)
                    }
                    Button("Add Lens") { showAddLens = true }
                }
                Section {
                    Button(action: {
                        onDelete?()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Camera")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        gear.lenses = lenses
                        onUpdate(gear)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadCapturePlanes()
                lenses = gear.lenses
            }
            .sheet(isPresented: $showAddLens) {
                AddLensView { lens in
                    print("Adding lens: \(lens.name)")
                    lenses.append(lens)
                    print("Total lenses now: \(lenses.count)")
                }
            }
            .sheet(item: $editingLens) { lens in
                AddLensView(lens: lens) { updatedLens in
                    if let index = lenses.firstIndex(where: { $0.id == lens.id }) {
                        lenses[index] = updatedLens
                    }
                }
            }
            .sheet(isPresented: $showCapturePlaneSheet) {
                NavigationView {
                    Group {
                        if capturePlanes.isEmpty {
                            Text("No film/sensor options available.")
                                .padding()
                        } else {
                            List(capturePlanes) { plane in
                                Button(action: {
                                    gear.capturePlane = plane.name
                                    showCapturePlaneSheet = false
                                }) {
                                    HStack {
                                        Text(plane.name)
                                        if gear.capturePlane == plane.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Select Film / Sensor")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCapturePlaneSheet = false }
                        }
                    }
                }
            }
        }
    }

    func loadCapturePlanes() {
        if let url = Bundle.main.url(forResource: "CapturePlane", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let planes = try? JSONDecoder().decode([CapturePlane].self, from: data) {
            capturePlanes = planes
            
            // Find the index of the current capturePlane
            if let index = planes.firstIndex(where: { $0.name == gear.capturePlane }) {
                selectedPlaneIndex = index
                // Update dimensions if they're missing
                if gear.capturePlaneWidth == 0 || gear.capturePlaneHeight == 0 || gear.capturePlaneDiagonal == 0 {
                    let plane = planes[index]
                    gear.capturePlaneWidth = plane.width
                    gear.capturePlaneHeight = plane.height
                    gear.capturePlaneDiagonal = plane.diagonal
                }
            } else if let first = planes.first {
                // Set default if current selection doesn't exist
                selectedPlaneIndex = 0
                gear.capturePlane = first.name
                gear.capturePlaneWidth = first.width
                gear.capturePlaneHeight = first.height
                gear.capturePlaneDiagonal = first.diagonal
            }
        } else {
            print("Could not load CapturePlane.json from bundle. Check file inclusion and structure.")
        }
    }
}

struct AddLensView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var lensType: Lens.LensType
    @State private var name: String
    @State private var primeFocal: String
    @State private var zoomMin: String
    @State private var zoomMax: String
    var onSave: (Lens) -> Void
    let isEditing: Bool
    
    init(lens: Lens? = nil, onSave: @escaping (Lens) -> Void) {
        self.onSave = onSave
        self.isEditing = lens != nil
        _lensType = State(initialValue: lens?.type ?? .prime)
        _name = State(initialValue: lens?.name ?? "")
        _primeFocal = State(initialValue: lens?.primeFocalLength.map(String.init) ?? "")
        _zoomMin = State(initialValue: lens?.zoomRange?.min.description ?? "")
        _zoomMax = State(initialValue: lens?.zoomRange?.max.description ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("Name:")
                        TextField("e.g. Nikkor 50 f/1.4", text: $name)
                    }
                    
                    HStack {
                        Text("Type:")
                        Picker("Type", selection: $lensType) {
                            ForEach(Lens.LensType.allCases) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if lensType == .prime {
                        HStack {
                            Text("Focal Length:")
                            Spacer()
                            TextField("50", text: $primeFocal)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("mm")
                        }
                    } else {
                        HStack {
                            Text("Focal Length:")
                            Spacer()
                            TextField("24", text: $zoomMin)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("-")
                            TextField("70", text: $zoomMax)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("mm")
                        }
                    }
                }
            }
            .navigationTitle("Lens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        let lens: Lens
                        if lensType == .prime, let focal = Int(primeFocal) {
                            lens = Lens(name: name, type: .prime, primeFocalLength: focal, zoomRange: nil)
                        } else if lensType == .zoom, let min = Int(zoomMin), let max = Int(zoomMax) {
                            lens = Lens(name: name, type: .zoom, primeFocalLength: nil, zoomRange: ZoomRange(min: min, max: max))
                        } else {
                            return
                        }
                        onSave(lens)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
