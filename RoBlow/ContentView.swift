import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassWindowView()
            .background(WindowBridge(allowsBackgroundMove: !model.home.isEditing && !model.instances.isEditingName) { window in
                model.hostWindow = window
            })
            .environment(\.colorScheme, .light)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
        .frame(width: 1280, height: 820)
}
