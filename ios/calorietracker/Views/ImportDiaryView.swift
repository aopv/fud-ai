import SwiftUI
import UniformTypeIdentifiers

struct ImportDiaryView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss

    @State private var isPickingFile = false
    @State private var preview: DiaryImportPreview?
    @State private var errorMessage: String?
    @State private var importedCount: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "DATA PORTABILITY",
                        title: "Import Diary",
                        subtitle: "Validate an exported diary before anything changes."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    Button {
                        isPickingFile = true
                    } label: {
                        Label("Choose JSON File", systemImage: "doc.badge.plus")
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
                } header: {
                    NeoSectionBanner(title: "Select Source", detail: "JSON", style: .cobalt)
                } footer: {
                    Text("Choose a JSON file previously exported by Fud AI. The file is validated before any food log is changed.")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .padding(.top, 6)
                }

                if let preview {
                    Section {
                        LabeledContent("Food entries", value: "\(preview.entryCount)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .neoPanel(fill: NeoAppColors.surface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        LabeledContent("Date range", value: rangeText(preview))
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .neoPanel(fill: NeoAppColors.surface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } header: {
                        NeoSectionBanner(
                            title: "Import Preview",
                            detail: "\(preview.entryCount) ITEMS",
                            style: .ink
                        )
                    }

                    Section {
                        Button {
                            apply(preview, mode: .replaceDateRange)
                        } label: {
                            Label("Replace This Date Range", systemImage: "arrow.triangle.2.circlepath")
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

                        Button {
                            apply(preview, mode: .addAsNew)
                        } label: {
                            Label("Add as New Entries", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                                .font(.system(.body, design: .rounded, weight: .black))
                                .textCase(.uppercase)
                                .foregroundStyle(NeoAppColors.cobalt)
                                .padding(.vertical, 13)
                                .background(NeoAppColors.surface)
                                .overlay {
                                    Rectangle()
                                        .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
                                        .allowsHitTesting(false)
                                }
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        NeoSectionBanner(title: "Import Mode", detail: "CHOOSE ONE", style: .acid)
                    } footer: {
                        Text("Replace removes existing food logs only within the exported date range, then recreates that range from this file. Matching entries keep their photos. Add keeps the current diary and creates duplicates as new entries.")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.mutedInk)
                            .padding(.top, 6)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listSectionSpacing(NeoAppMetrics.sectionSpacing)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .navigationTitle("Import Food Diary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: loadFile
            )
            .alert("Unable to Import", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "The selected file could not be imported.")
            }
            .alert("Import Complete", isPresented: Binding(
                get: { importedCount != nil },
                set: { if !$0 { importedCount = nil } }
            )) {
                Button("Done") { dismiss() }
            } message: {
                Text("Imported \(importedCount ?? 0) food entries.")
            }
        }
    }

    private func loadFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize, size > DiaryImporter.maximumFileSize {
                throw DiaryImportError.fileTooLarge
            }
            preview = try DiaryImporter.parse(Data(contentsOf: url, options: [.mappedIfSafe]))
            errorMessage = nil
        } catch {
            preview = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func apply(_ preview: DiaryImportPreview, mode: DiaryImportMode) {
        let updated = DiaryImporter.applying(preview, to: foodStore.entries, mode: mode)
        foodStore.replaceEntriesFromImport(updated)
        importedCount = preview.entryCount
        self.preview = nil
    }

    private func rangeText(_ preview: DiaryImportPreview) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: preview.startDate)) – \(formatter.string(from: preview.endDate))"
    }
}
