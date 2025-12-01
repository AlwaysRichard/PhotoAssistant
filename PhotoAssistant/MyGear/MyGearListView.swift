import SwiftUI

struct MyGearListView: View {
    @State private var gearList: [MyGearModel] = MyGearModel.loadGearList()
        .sorted(by: { $0.cameraName < $1.cameraName })
    
    @State private var selectedGear: MyGearModel?
    
    @State private var showAddCamera = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Text("My Gear")
                        .font(.headline)
                    Spacer()
                    Button("Add") { showAddCamera = true }
                }
                .padding()
                
                Divider()
                
                List(gearList) { gear in
                    Button(action: { selectedGear = gear }) {
                        VStack(alignment: .leading) {
                            Text(gear.cameraName).font(.headline)
                            Text(gear.capturePlane).font(.subheadline)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedGear) { gear in
                MyGearItemView(gear: gear, onUpdate: { updated in
                    if let idx = gearList.firstIndex(where: { $0.id == updated.id }) {
                        gearList[idx] = updated
                        MyGearModel.saveGearList(gearList)
                    }
                }, onDelete: {
                    if let idx = gearList.firstIndex(where: { $0.id == gear.id }) {
                        gearList.remove(at: idx)
                        MyGearModel.saveGearList(gearList)
                    }
                    selectedGear = nil
                })
            }
            .sheet(isPresented: $showAddCamera) {
                MyGearItemView(gear: MyGearModel(cameraName: "", capturePlane: "", capturePlaneWidth: 0, capturePlaneHeight: 0, capturePlaneDiagonal: 0, lenses: []), onUpdate: { newGear in
                    gearList.append(newGear)
                    MyGearModel.saveGearList(gearList)
                    showAddCamera = false
                }, onDelete: {
                    // No delete action needed for new camera
                    showAddCamera = false
                })
            }
        }
    }
}
