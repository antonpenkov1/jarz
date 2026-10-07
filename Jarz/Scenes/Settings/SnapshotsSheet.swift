import SwiftUI

/// Automatic snapshots taken before destructive actions; one tap brings the
/// whole app back to that moment. Worker-backed settings sub-screen.
struct SnapshotsSheet: View {
    let onRestored: () -> Void
    let onDone: () -> Void

    @State private var snapshots: [SnapshotInfo] = []
    @State private var pendingRestore: SnapshotInfo?
    @State private var restoreFailed = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if snapshots.isEmpty {
                        Text("No snapshots yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.secondary)
                            .listRowBackground(Theme.bg)
                    }
                    ForEach(snapshots) { snapshot in
                        Button {
                            pendingRestore = snapshot
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title(for: snapshot))
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.ink)
                                    Text(Self.dateFormatter.string(from: snapshot.date))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.bg)
                        .listRowSeparatorTint(Theme.hairline)
                    }
                } header: {
                    SectionLabel("Snapshots")
                        .padding(.leading, -8)
                } footer: {
                    Text("Saved automatically before deleting a jar, importing data, recalculating food or restoring. The last 5 are kept.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Restore previous state")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.ink)
                }
            }
            .alert("Restore this state?", isPresented: Binding(
                get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } }
            )) {
                Button("Restore", role: .destructive) {
                    if let snapshot = pendingRestore {
                        if StorageWorker.shared.restoreSnapshot(id: snapshot.id) {
                            Haptics.success()
                            onRestored()
                        } else {
                            restoreFailed = true
                        }
                    }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("Everything in Jarz will be replaced with this snapshot. Your current state is saved as a new snapshot first.")
            }
            .alert("Import failed", isPresented: $restoreFailed) {
                Button("OK", role: .cancel) {}
            }
            .onAppear { snapshots = StorageWorker.shared.snapshots() }
        }
    }

    private func title(for snapshot: SnapshotInfo) -> String {
        switch snapshot.kind {
        case .deleteJar: return String(localized: "Before deleting \(snapshot.detail)")
        case .importData: return String(localized: "Before import")
        case .recalculateFood: return String(localized: "Before food recalculation")
        case .restore: return String(localized: "Before restore")
        }
    }
}
