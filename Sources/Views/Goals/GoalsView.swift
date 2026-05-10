import SwiftUI

struct GoalsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showAddSheet = false

    var body: some View {
        List {
            if viewModel.goals.isEmpty {
                ContentUnavailableView(
                    viewModel.loc("No Goals Yet"),
                    systemImage: "target",
                    description: Text(viewModel.loc("Set savings goals to track your progress"))
                )
            } else {
                ForEach(viewModel.goals) { goal in
                    GoalRow(goal: goal, currency: viewModel.currency, theme: viewModel.theme)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteGoal(goal) }
                            } label: {
                                Label(viewModel.loc("Delete"), systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(viewModel.loc("Goals"))
        .toolbar {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGoalView()
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let currency: String
    let theme: AppTheme
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(Int(goal.progress * 100))" + viewModel.loc("% complete"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(CurrencyFormat.format(goal.currentAmount, currency: currency))
                    .font(.subheadline.weight(.bold))
                    + Text(" / \(CurrencyFormat.format(goal.targetAmount, currency: currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primaryColor)
                        .frame(width: geo.size.width * CGFloat(goal.progress), height: 10)
                }
            }
            .frame(height: 10)

            HStack {
                quickAddButton(10)
                quickAddButton(50)
                quickAddButton(100)
                quickAddButton(500)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func quickAddButton(_ amount: Double) -> some View {
        Button {
            Task {
                await viewModel.updateGoalAmount(id: goal.id, newAmount: goal.currentAmount + amount)
            }
        } label: {
            Text("+\(CurrencyFormat.format(amount, currency: currency))")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct AddGoalView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var frequency = "monthly"

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(targetAmount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(viewModel.loc("Goal Details")) {
                    TextField(viewModel.loc("Name"), text: $name)
                    TextField(viewModel.loc("Target Amount"), text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField(viewModel.loc("Current Amount"), text: $currentAmount)
                        .keyboardType(.decimalPad)
                }
                Section(viewModel.loc("Frequency")) {
                    Picker(viewModel.loc("Frequency"), selection: $frequency) {
                        Text(viewModel.loc("Weekly")).tag("weekly")
                        Text(viewModel.loc("Biweekly")).tag("biweekly")
                        Text(viewModel.loc("Monthly")).tag("monthly")
                    }
                }
            }
            .navigationTitle(viewModel.loc("New Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.loc("Save")) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let target = Double(targetAmount), target > 0 else { return }
        let data = GoalData(
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: target,
            currentAmount: Double(currentAmount) ?? 0,
            frequency: frequency
        )
        Task {
            await viewModel.addGoal(data)
            dismiss()
        }
    }
}
