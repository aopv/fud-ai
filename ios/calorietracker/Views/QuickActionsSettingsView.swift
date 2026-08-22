import SwiftUI

struct QuickActionsSettingsView: View {
    @AppStorage(QuickActionSettings.storageKeys[0]) private var firstRaw = QuickActionSettings.defaults[0].rawValue
    @AppStorage(QuickActionSettings.storageKeys[1]) private var secondRaw = QuickActionSettings.defaults[1].rawValue
    @AppStorage(QuickActionSettings.storageKeys[2]) private var thirdRaw = QuickActionSettings.defaults[2].rawValue

    var body: some View {
        Form {
            Section {
                quickActionPicker(title: "Quick Action 1", selection: $firstRaw)
                quickActionPicker(title: "Quick Action 2", selection: $secondRaw)
                quickActionPicker(title: "Quick Action 3", selection: $thirdRaw)
            } header: {
                Text("App Icon Shortcuts")
            } footer: {
                Text("Hold the Fud AI app icon to use these shortcuts. On iPhone, Quick Action 1–3 can also be assigned in Shortcuts to the Action Button or Back Tap.")
            }
            .listRowBackground(NeoAppColors.surface)
            .listRowSeparatorTint(NeoAppColors.ink.opacity(0.35))
        }
        .scrollContentBackground(.hidden)
        .background(NeoAppColors.canvas)
        .tint(NeoAppColors.cobalt)
        .navigationTitle("Quick Actions")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: firstRaw) { _, _ in refreshShortcuts() }
        .onChange(of: secondRaw) { _, _ in refreshShortcuts() }
        .onChange(of: thirdRaw) { _, _ in refreshShortcuts() }
    }

    private func quickActionPicker(title: String, selection: Binding<String>) -> some View {
        Picker(selection: selection) {
            ForEach(QuickAction.allCases) { action in
                Label(action.title, systemImage: action.systemImageName)
                    .tag(action.rawValue)
            }
        } label: {
            Label {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .bold))
            } icon: {
                Image(systemName: numberIcon(for: title))
                    .foregroundStyle(NeoAppColors.cobalt)
            }
        }
        .pickerStyle(.menu)
        .tint(NeoAppColors.cobalt)
    }

    private func numberIcon(for title: String) -> String {
        title.hasSuffix("1") ? "1.circle.fill" : title.hasSuffix("2") ? "2.circle.fill" : "3.circle.fill"
    }

    private func refreshShortcuts() {
        QuickActionSettings.registerApplicationShortcuts()
    }
}
