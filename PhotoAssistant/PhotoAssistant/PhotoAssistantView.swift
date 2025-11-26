import SwiftUI

struct PhotoAssistantView: View {
    @State private var selection: Selection?
    
    enum Selection {
        case camera, gear, calibration
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Text("Photo Assistant")
                    .font(.largeTitle)
                    .padding(.top, 40)
                Spacer()
                Button(action: { selection = .camera }) {
                    Label("Open Camera", systemImage: "camera")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                Button(action: { selection = .gear }) {
                    Label("Manage My Gear", systemImage: "camera.metering.center.weighted")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                Button(action: { selection = .calibration }) {
                    Label("Calibrate Camera", systemImage: "slider.horizontal.3")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                }
                Spacer()
            }
            .padding()
            .background(
                NavigationLink(destination: CameraView().ignoresSafeArea(), tag: .camera, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: MyGearListView(), tag: .gear, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: CameraCalibrationView(), tag: .calibration, selection: $selection) { EmptyView() }
                    .hidden()
            )
        }
    }
}

#Preview {
    PhotoAssistantView()
}
