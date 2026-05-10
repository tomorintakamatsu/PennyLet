import SwiftUI
import Charts

struct BudgetHealthView: View {
    @Environment(AppViewModel.self) private var viewModel

    var summary: SpendSummary { viewModel.spendSummary }
    var breakdown: [CategoryBreakdown] { viewModel.categoryBreakdown }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let budget = viewModel.currentBudget {
                    budgetOverview(budget)
                }
                pieChartSection
                barChartSection
                statCardsSection
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .navigationTitle(viewModel.loc("Budget Health"))
    }

    private func budgetOverview(_ budget: Budget) -> some View {
        VStack(spacing: 8) {
            Text(viewModel.loc("Monthly Disposable"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(CurrencyFormat.format(summary.monthlyDisposable, currency: viewModel.currency))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(viewModel.theme.primaryColor)
            Text("\(Int(summary.spendPercent))" + viewModel.loc("% of budget used"))
                .font(.caption)
                .foregroundStyle(summary.isOverBudget ? .red : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.loc("Spending by Category"))
                .font(.headline)

            if breakdown.isEmpty {
                Text(viewModel.loc("No spending data this month"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                Chart(breakdown) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(item.category.color)
                }
                .frame(height: 200)

                VStack(spacing: 8) {
                    ForEach(breakdown.prefix(6)) { item in
                        HStack {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 10, height: 10)
                            Text(viewModel.loc(item.category.label))
                                .font(.caption)
                            Spacer()
                            Text(CurrencyFormat.format(item.amount, currency: viewModel.currency))
                                .font(.caption.weight(.medium))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.loc("Income vs Spending"))
                .font(.headline)

            Chart {
                BarMark(
                    x: .value("Type", viewModel.loc("Income")),
                    y: .value("Amount", summary.incomeThisMonth)
                )
                .foregroundStyle(.green)
                BarMark(
                    x: .value("Type", viewModel.loc("Spent")),
                    y: .value("Amount", summary.spent)
                )
                .foregroundStyle(.red)
                if summary.monthlyDisposable > 0 {
                    BarMark(
                        x: .value("Type", viewModel.loc("Budget")),
                        y: .value("Amount", summary.monthlyDisposable)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var statCardsSection: some View {
        HStack(spacing: 12) {
            statCard(viewModel.loc("Remaining"), value: summary.remaining, color: summary.isOverBudget ? .red : .green)
            statCard(viewModel.loc("Safe Daily"), value: summary.safeDaily, color: viewModel.theme.primaryColor)
            statCard(viewModel.loc("Days Left"), value: Double(summary.daysLeft), color: .blue, isWhole: true)
        }
    }

    private func statCard(_ title: String, value: Double, color: Color, isWhole: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(isWhole
                ? "\(Int(value))"
                : CurrencyFormat.format(value, currency: viewModel.currency)
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
