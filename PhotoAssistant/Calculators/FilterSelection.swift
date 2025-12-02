//
//  FilterSelection.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/28/25.
//


//
//  FilterSelectorRow.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import SwiftUI

// MARK: - Filter Selection Model

enum FilterSelection: Hashable {
    case none
    case simple(FilterType, Double) // filter, stops
    case variant(FilterType, FilterVariant, Double) // filter, variant, stops
    
    var compensationStops: Double {
        switch self {
        case .none:
            return 0.0
        case .simple(_, let stops):
            return stops
        case .variant(_, _, let stops):
            return stops
        }
    }
}

// MARK: - Filter Selector Row

struct FilterSelectorRow: View {
    @Binding var selection: FilterSelection
    let filters: [FilterType]
    
    @State private var selectedFilter: FilterType?
    @State private var selectedVariant: FilterVariant?
    @State private var customStops: Double = 1.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: $selectedFilter) {
                    Text("Select Filter").tag(nil as FilterType?)
                    ForEach(filters) { filter in
                        Text(filter.name).tag(Optional(filter))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedFilter) { newFilter in
                    handleFilterChange(newFilter)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if let filter = selectedFilter, filter.hasVariants {
                HStack {
                    Spacer()
                    Picker("", selection: $selectedVariant) {
                        Text("Select...").tag(nil as FilterVariant?)
                        if let variants = filter.variants {
                            ForEach(variants) { variant in
                                Text(variant.name).tag(Optional(variant))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedVariant) { _ in
                        updateSelection()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)
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
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .onChange(of: customStops) { _ in
                    updateSelection()
                }
            }
            
            Divider()
                .background(Color.white)
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
    
    private func handleFilterChange(_ newFilter: FilterType?) {
        selectedVariant = nil
        
        guard let filter = newFilter else {
            selection = .none
            return
        }
        
        if filter.hasVariants {
            // Wait for variant selection
            selection = .none
        } else if let stops = filter.compensationStops {
            // Simple filter with fixed stops
            selection = .simple(filter, stops)
        } else if let min = filter.compensationStopsMin,
                  let max = filter.compensationStopsMax {
            // Range filter
            customStops = (min + max) / 2.0
            selection = .simple(filter, customStops)
        }
    }
    
    private func updateSelection() {
        guard let filter = selectedFilter else {
            selection = .none
            return
        }
        
        if let variant = selectedVariant {
            let stops: Double
            if let variantStops = variant.stops {
                stops = variantStops
            } else if variant.stopsMin != nil && variant.stopsMax != nil {
                stops = customStops
            } else {
                stops = 0.0
            }
            selection = .variant(filter, variant, stops)
        } else if filter.isRange {
            selection = .simple(filter, customStops)
        } else if let fixedStops = filter.compensationStops {
            selection = .simple(filter, fixedStops)
        }
    }
}