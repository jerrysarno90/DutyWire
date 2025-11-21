import SwiftUI
import Amplify

struct SquadManagementListView: View {
    @State private var squads: [EditableSquad] = EditableSquad.samples
    @State private var selectedSquad: EditableSquad?
    @State private var showingEditor = false

    var body: some View {
        List {
            Section("Active squads") {
                ForEach(squads) { squad in
                    Button {
                        selectedSquad = squad
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(squad.name)
                                    .font(.headline)
                                Text("\(squad.members.count) members • \(squad.focusArea)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if squad.isDefault {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    squads.remove(atOffsets: indexSet)
                }
            }
        }
        .background(SquadManagementBackground().ignoresSafeArea())
        .navigationTitle("Manage Squads")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedSquad = EditableSquad.emptyTemplate()
                    showingEditor = true
                } label: {
                    Label("Add squad", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $selectedSquad) { squad in
            SquadRosterEditor(
                squad: squad,
                onSave: { updated in
                    if let index = squads.firstIndex(where: { $0.id == updated.id }) {
                        squads[index] = updated
                    } else {
                        squads.append(updated)
                    }
                },
                onDelete: { dismissed in
                    squads.removeAll { $0.id == dismissed.id }
                }
            )
        }
    }
}

private struct SquadRosterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var squad: EditableSquad
    let onSave: (EditableSquad) -> Void
    let onDelete: (EditableSquad) -> Void

    init(squad: EditableSquad, onSave: @escaping (EditableSquad) -> Void, onDelete: @escaping (EditableSquad) -> Void) {
        _squad = State(initialValue: squad)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Squad name", text: $squad.name)
                    TextField("Focus area", text: $squad.focusArea)
                    Toggle("Default supervisor squad", isOn: $squad.isDefault)
                }

                Section("Members") {
                    ForEach(squad.members) { member in
                        HStack {
                            Text(member.displayName)
                            Spacer()
                            Text(member.role.rawValue.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        squad.members.remove(atOffsets: indexSet)
                    }

                    Button("Add placeholder member") {
                        squad.members.append(EditableSquadMember(displayName: "New officer"))
                    }
                }
            }
            .navigationTitle(squad.name.isEmpty ? "New squad" : squad.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .destructiveAction) {
                    if !squad.members.isEmpty {
                        Button("Delete") {
                            onDelete(squad)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(squad)
                        dismiss()
                    }
                    .disabled(squad.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

private struct SquadManagementBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct EditableSquad: Identifiable, Equatable {
    let id: UUID
    var name: String
    var focusArea: String
    var isDefault: Bool
    var members: [EditableSquadMember]

    static func emptyTemplate() -> EditableSquad {
        EditableSquad(id: UUID(), name: "", focusArea: "", isDefault: false, members: [])
    }

    static let samples: [EditableSquad] = [
        EditableSquad(
            id: UUID(),
            name: "Downtown Bravo",
            focusArea: "Patrol overtime / special events",
            isDefault: true,
            members: [
                EditableSquadMember(displayName: "Sgt. Keller", role: .supervisor),
                EditableSquadMember(displayName: "Officer Delgado", role: .officer),
                EditableSquadMember(displayName: "Officer Hayes", role: .officer),
            ]
        ),
        EditableSquad(
            id: UUID(),
            name: "Community Response",
            focusArea: "Door checks and neighborhood requests",
            isDefault: false,
            members: [
                EditableSquadMember(displayName: "Officer Barnes", role: .officer),
                EditableSquadMember(displayName: "Officer Tran", role: .officer),
            ]
        ),
    ]
}

private struct EditableSquadMember: Identifiable, Equatable {
    let id = UUID()
    var displayName: String
    var role: SquadRole = .officer
}
