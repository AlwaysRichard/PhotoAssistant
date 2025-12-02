//
//  AttachedFilter.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/28/25.
//

import SwiftUI

// MARK: - Attached Filter Model

struct AttachedFilter: Identifiable, Codable, Hashable {
    let id: UUID
    let filterType: String  // FilterType.id
    let filterName: String  // FilterType.name
    let variantId: String?  // FilterVariant.id if applicable
    let variantName: String?  // FilterVariant.name if applicable
    let stops: Double
    
    init(id: UUID = UUID(), filterType: String, filterName: String, variantId: String? = nil, variantName: String? = nil, stops: Double) {
        self.id = id
        self.filterType = filterType
        self.filterName = filterName
        self.variantId = variantId
        self.variantName = variantName
        self.stops = stops
    }
    
    var displayName: String {
        if let variantName = variantName {
            return "\(filterName) \(variantName)"
        }
        return filterName
    }
    
    var stopsLabel: String {
        String(format: "%.1f stop%@", stops, stops == 1.0 ? "" : "s")
    }
}

// MARK: - Attached Filters View

struct AttachedFiltersView: View {
    @Binding var attachedFilters: [AttachedFilter]
    @Environment(\.presentationMode) var presentationMode
    @State private var showAddFilter = false
    
    var totalStops: Double {
        attachedFilters.reduce(0) { $0 + $1.stops }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Attached Filters")) {
                    ForEach(attachedFilters) { filter in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(filter.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("(\(filter.stopsLabel))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                if let index = attachedFilters.firstIndex(where: { $0.id == filter.id }) {
                                    attachedFilters.remove(at: index)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onDelete { indexSet in
                        attachedFilters.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Filter") {
                        showAddFilter = true
                    }
                }
                
                if !attachedFilters.isEmpty {
                    Section(header: Text("Total")) {
                        HStack {
                            Text("Total Stops")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "+%.1f", totalStops))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if !attachedFilters.isEmpty {
                    Section {
                        Button(action: {
                            attachedFilters.removeAll()
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete All Filters")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddFilter) {
                AddFilterView { filter in
                    attachedFilters.append(filter)
                }
            }
        }
    }
}

// MARK: - Add Filter View

struct AddFilterView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (AttachedFilter) -> Void
    
    @State private var filters: [FilterType] = []
    @State private var selectedFilter: FilterType?
    @State private var selectedVariant: FilterVariant?
    @State private var customStops: Double = 1.0
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        Text("Select Filter").tag(nil as FilterType?)
                        ForEach(filters) { filter in
                            Text(filter.name).tag(Optional(filter))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedFilter) { oldValue, newValue in
                        handleFilterChange(newValue)
                    }
                    
                    if let filter = selectedFilter, filter.hasVariants {
                        Picker("Variant", selection: $selectedVariant) {
                            Text("Select...").tag(nil as FilterVariant?)
                            if let variants = filter.variants {
                                ForEach(variants) { variant in
                                    Text(variant.name).tag(Optional(variant))
                                }
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if let filter = selectedFilter, filter.isRange || needsCustomStops {
                        HStack {
                            Text("Stops")
                                .font(.subheadline)
                            Slider(value: $customStops, in: getStopsRange(), step: 0.1)
                            Text(String(format: "%.1f", customStops))
                                .font(.subheadline)
                                .frame(width: 40)
                        }
                    }
                }
                
                if selectedFilter != nil {
                    Section(header: Text("Preview")) {
                        HStack {
                            Text("Filter")
                            Spacer()
                            Text(previewName)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Stops")
                            Spacer()
                            Text(String(format: "+%.1f", calculatedStops))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let filter = selectedFilter else { return }
                        
                        let attachedFilter = AttachedFilter(
                            filterType: filter.id,
                            filterName: filter.name,
                            variantId: selectedVariant?.id,
                            variantName: selectedVariant?.name,
                            stops: calculatedStops
                        )
                        
                        onSave(attachedFilter)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedFilter == nil || calculatedStops == 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadFilters()
            }
        }
    }
    
    private func loadFilters() {
        if let url = Bundle.main.url(forResource: "PhotographyFilters", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let database = try? JSONDecoder().decode(FilterDatabase.self, from: data) {
            filters = database.filters
        } else {
            print("Could not load PhotographyFilters.json from bundle.")
        }
    }
    
    private var needsCustomStops: Bool {
        guard let filter = selectedFilter else { return false }
        if let variant = selectedVariant {
            return variant.stopsMin != nil && variant.stopsMax != nil
        }
        return false
    }
    
    private func getStopsRange() -> ClosedRange<Double> {
        if let filter = selectedFilter {
            if let variant = selectedVariant,
               let min = variant.stopsMin,
               let max = variant.stopsMax {
                return min...max
            }
            if let min = filter.compensationStopsMin,
               let max = filter.compensationStopsMax {
                return min...max
            }
        }
        return 0.0...10.0
    }
    
    private var calculatedStops: Double {
        guard let filter = selectedFilter else { return 0.0 }
        
        if let variant = selectedVariant {
            if let stops = variant.stops {
                return stops
            } else if variant.stopsMin != nil && variant.stopsMax != nil {
                return customStops
            }
        } else if let stops = filter.compensationStops {
            return stops
        } else if filter.compensationStopsMin != nil && filter.compensationStopsMax != nil {
            return customStops
        }
        
        return 0.0
    }
    
    private var previewName: String {
        guard let filter = selectedFilter else { return "" }
        if let variant = selectedVariant {
            return "\(filter.name) \(variant.name)"
        }
        return filter.name
    }
    
    private func handleFilterChange(_ newFilter: FilterType?) {
        selectedVariant = nil
        
        guard let filter = newFilter else { return }
        
        // Set default customStops if it's a range filter
        if let min = filter.compensationStopsMin,
           let max = filter.compensationStopsMax {
            customStops = (min + max) / 2.0
        }
    }
}
