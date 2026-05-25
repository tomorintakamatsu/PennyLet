import SwiftUI

struct GoalsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showAddSheet = false

    var body: some View {
        List {
            Section {
                GoalsHeroCard(goals: viewModel.goals, currency: viewModel.currency)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
            }

            if viewModel.goals.isEmpty {
                ContentUnavailableView(
                    viewModel.loc("No Goals Yet"),
                    systemImage: "target",
                    description: Text(viewModel.loc("Set savings goals to track your progress"))
                )
            } else {
                ForEach(Array(viewModel.goals.enumerated()), id: \.element.id) { index, goal in
                    GoalRow(goal: goal, currency: viewModel.currency, theme: viewModel.theme)
                        .staggeredEntrance(index: index)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
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
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle(viewModel.loc("Goals"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(viewModel.theme.primaryColor)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGoalView()
        }
    }
}

private struct GoalsHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let goals: [Goal]
    let currency: String

    private var saved: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    private var target: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.loc("Savings direction"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.68))
                Text(CurrencyFormat.format(saved, currency: currency))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(goals.count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(target > 0 ? viewModel.loc("active goals") : viewModel.loc("goals"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: viewModel.theme.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: viewModel.theme.primaryColor.opacity(0.20), radius: 18, y: 10)
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
                Image(systemName: "flag.checkered")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.primaryColor)
                    .frame(width: 30, height: 30)
                    .background(theme.primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

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
                        .fill(
                            LinearGradient(
                                colors: [theme.primaryColor, theme.accentColor.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
        .premiumPanel(tint: theme.primaryColor)
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
                .background(theme.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
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
