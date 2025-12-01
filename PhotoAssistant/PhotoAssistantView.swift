import SwiftUI

struct PhotoAssistantView: View {
    @State private var selection: Selection?
    
    enum Selection {
        case camera, exposure, dof, fov, gear
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
                Button(action: { selection = .exposure }) {
                    Label("Exposure Compensation", systemImage: "camera.aperture")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                Button(action: { selection = .dof }) {
                    Label("DoF - Depth of Field", systemImage: "ruler")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                Button(action: { selection = .fov }) {
                    Label("FoV - Field of View", systemImage: "scope")
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
                Spacer()
            }
            .padding()
            .background(
                NavigationLink(destination: CameraView().ignoresSafeArea(), tag: .camera, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: ExposureCompensationView(), tag: .exposure, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: DepthOfFieldView(), tag: .dof, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: FieldOfViewView(), tag: .fov, selection: $selection) { EmptyView() }
                    .hidden()
            )
            .background(
                NavigationLink(destination: MyGearListView(), tag: .gear, selection: $selection) { EmptyView() }
                    .hidden()
            )
        }
    }
}

#Preview {
    PhotoAssistantView()
}
