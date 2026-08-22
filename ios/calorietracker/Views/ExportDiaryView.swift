import SwiftUI
import UIKit

/// Export the food diary as JSON / Markdown / CSV over a chosen date range,
/// then hand the file to the system share sheet.
struct ExportDiaryView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var range: DiaryExportRange = .thisWeek
    @State private var format: DiaryExportFormat = .json
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var customEnd: Date = .now

    @State private var emptyNotice = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "DATA PORTABILITY",
                        title: "Export Diary",
                        subtitle: "Choose exactly which meals and file format to share."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Picker("Range", selection: $range) {
                        ForEach(DiaryExportRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(NeoAppColors.cobalt)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .neoPanel(fill: NeoAppColors.surface)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if range == .custom {
                        DatePicker("From", selection: $customStart, displayedComponents: .date)
                            .tint(NeoAppColors.cobalt)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .neoPanel(fill: NeoAppColors.surface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        DatePicker("To", selection: $customEnd, displayedComponents: .date)
                            .tint(NeoAppColors.cobalt)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .neoPanel(fill: NeoAppColors.surface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    NeoSectionBanner(title: "Date Range", detail: range.label, style: .cobalt)
                }

                Section {
                    Picker("Format", selection: $format) {
                        ForEach(DiaryExportFormat.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .neoPanel(fill: NeoAppColors.surface)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    NeoSectionBanner(title: "File Format", detail: format.label, style: .ink)
                }

                Section {
                    Button {
                        exportNow()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .font(.system(.body, design: .rounded, weight: .black))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.black)
                            .padding(.vertical, 14)
                            .background(NeoAppColors.acid)
                            .overlay {
                                Rectangle()
                                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                    .allowsHitTesting(false)
                            }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } footer: {
                    Text("Exports your logged meals — totals, targets, and each item's macros — as a file you can save or send to another app.")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .padding(.top, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listSectionSpacing(NeoAppMetrics.sectionSpacing)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .navigationTitle("Export Food Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Nothing to export", isPresented: $emptyNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("There are no logged meals in the selected range.")
            }
        }
    }

    private func exportNow() {
        let (start, end) = DiaryExporter.resolve(range, customStart: customStart, customEnd: customEnd, foodStore: foodStore)
        guard let (name, data) = DiaryExporter.build(
            from: start, to: end, format: format, foodStore: foodStore, profile: profileStore.profile
        ) else {
            emptyNotice = true
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            Self.presentShareSheet(for: url)
        } catch {
            emptyNotice = true
        }
    }

    /// Present the system share sheet directly via UIKit. A UIActivityViewController
    /// must be *presented*, not embedded in a SwiftUI `.sheet` (doubly so from inside
    /// another sheet), which renders blank.
    private static func presentShareSheet(for url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var top = window.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        if let pop = av.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 40, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(av, animated: true)
    }
}
