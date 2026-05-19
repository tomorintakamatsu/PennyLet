import SwiftUI
import Observation
import AuthenticationServices

@MainActor
@Observable
final class AppViewModel {
    // Auth state
    var isAuthenticated = false
    var isLoadingAuth = true
    var authError: String?

    /// NOT @Observable — changed manually to avoid observation graph corruption during sign-in
    @ObservationIgnored var isGuestMode = false

    // MARK: - Persistent Preferences

    private let prefs = UserDefaults.standard

    func savePreferencesToDisk() {
        prefs.set(theme.rawValue, forKey: "app_theme")
        prefs.set(colorMode.rawValue, forKey: "app_color_mode")
        prefs.set(font.rawValue, forKey: "app_font")
        prefs.set(language, forKey: "app_language")
        prefs.set(currency, forKey: "app_currency")
    }

    func loadPreferencesFromDisk() {
        if let t = prefs.string(forKey: "app_theme"), let th = AppTheme(rawValue: t) { theme = th }
        if let c = prefs.string(forKey: "app_color_mode"), let cm = AppColorMode(rawValue: c) { colorMode = cm }
        if let f = prefs.string(forKey: "app_font"), let fn = AppFont(rawValue: f) { font = fn }
        if let l = prefs.string(forKey: "app_language") { language = l }
        if let cr = prefs.string(forKey: "app_currency") { currency = cr }
    }

    // Data
    var transactions: [Transaction] = []
    var budgets: [Budget] = []
    var goals: [Goal] = []
    var analysisHistory: [AnalysisHistory] = []
    var user: User?

    // Loading
    var isLoading = true
    var isLoadingData = false
    var error: String?
    var navigateToTab: Int?
    var initialAISubTab: Int?
    var currentDailyResult: AIResult?
    var currentWeeklyResult: AIResult?
    var currentMonthlyResult: AIResult?
    var currentForecastResult: AIResult?

    func loadLocalData() {
        let decoder = JSONDecoder()
        if let data = prefs.data(forKey: "local_budgets"),
           let b = try? decoder.decode([Budget].self, from: data), !b.isEmpty {
            budgets = b
        }
        if let data = prefs.data(forKey: "local_transactions"),
           let t = try? decoder.decode([Transaction].self, from: data) {
            transactions = t
        }
        if let data = prefs.data(forKey: "local_goals"),
           let g = try? decoder.decode([Goal].self, from: data) {
            goals = g
        }
    }

    func checkAndNotifyBudgetAlerts() {
        guard let budget = currentBudget,
              budget.budgetAlertsEnabled == true,
              budget.budgetAlertsPushEnabled == true else { return }
        let svc = NotificationService()
        svc.scheduleBudgetAlert(summary: spendSummary, currency: currency)
    }

    func saveLocalData() {
        if let data = try? JSONEncoder().encode(budgets) {
            prefs.set(data, forKey: "local_budgets")
        }
        if let data = try? JSONEncoder().encode(transactions) {
            prefs.set(data, forKey: "local_transactions")
        }
        if let data = try? JSONEncoder().encode(goals) {
            prefs.set(data, forKey: "local_goals")
        }
        prefs.synchronize()
    }

    // Preferences (synced from Budget)
    var theme: AppTheme = .sage
    var colorMode: AppColorMode = .system
    var font: AppFont = .inter
    var currency: String = "USD"
    var language: String = "en" {
        didSet { CurrencyFormat.language = language }
    }

    // Developer mode
    var isDeveloperMode = false

    // Retains Apple Sign In objects so they don't dealloc before callback
    private var appleSignInDelegate: AppleSignInDelegate?
    private var appleSignInController: ASAuthorizationController?

    // Auth loading
    var isAuthenticating = false

    // Usage limit alerts
    private let client = Base44Client.shared
    private let cache = CacheService.shared
    let revenueCat = RevenueCatService()
    let proStatus = ProStatusService()

    var currentBudget: Budget? { budgets.first }

    var spendSummary: SpendSummary {
        let txns = transactions
        return SpendCalculator.getSpendSummary(
            transactions: txns,
            budget: currentBudget
        )
    }

    var categoryBreakdown: [CategoryBreakdown] {
        let txns = transactions
        return SpendCalculator.getCategoryBreakdown(transactions: txns)
    }

    var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }

    /// Set by StoreKit purchase/restore. Persisted in UserDefaults.
    var hasProSubscription: Bool {
        get { prefs.bool(forKey: "has_pro_subscription") }
        set { prefs.set(newValue, forKey: "has_pro_subscription") }
    }

    var isPro: Bool {
        isDeveloperMode || hasProSubscription
    }

    func canUseFeature(_ feature: String) -> Bool {
        if isDeveloperMode { return true }
        return remainingUses(feature) > 0
    }

    func remainingUses(_ feature: String) -> Int {
        let counts = localUsageCounts
        let used = counts[feature] ?? 0
        let limit = usageLimit(feature)
        return max(0, limit - used)
    }

    func usageLimit(_ feature: String) -> Int {
        proStatus.limitFor(feature: feature, isPro: isPro)
    }

    private var localUsageCounts: [String: Int] {
        get {
            guard let data = prefs.data(forKey: "usage_counts"),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                prefs.set(data, forKey: "usage_counts")
            }
        }
    }

    func incrementUsage(_ feature: String) async {
        var counts = localUsageCounts
        // Reset if new month
        let currentMonth = {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM"
            return df.string(from: Date())
        }()
        if prefs.string(forKey: "usage_month") != currentMonth {
            counts = [:]
            prefs.set(currentMonth, forKey: "usage_month")
        }
        counts[feature] = (counts[feature] ?? 0) + 1
        localUsageCounts = counts
    }

    var needsResetToSetup = false

    func restoreDefaults() {
        let savedLanguage = prefs.string(forKey: "app_language") ?? "en"
        transactions = []
        budgets = []
        goals = []
        analysisHistory = []
        currentDailyResult = nil
        currentWeeklyResult = nil
        currentMonthlyResult = nil
        currentForecastResult = nil
        theme = .sage
        colorMode = .system
        font = .inter
        currency = "USD"
        language = savedLanguage
        hasProSubscription = false
        let cache = CacheService.shared
        Task { await cache.clear() }
        needsResetToSetup = true
    }

    func requestNotificationPermission() {
        Task {
            let _: Bool = await NotificationService().registerForPushNotifications()
        }
    }

    func updateBudgetLocally(_ data: BudgetData) {
        guard var budget = budgets.first else { return }
        budget.monthlyIncome = data.monthlyIncome
        budget.monthlyEssentials = data.monthlyEssentials
        budget.monthlySavingsGoal = data.monthlySavingsGoal
        if let p = data.payDay { budget.payDay = p }
        if let c = data.currency { budget.currency = c; currency = c }
        if let l = data.language { budget.language = l; language = l }
        if let t = data.theme { budget.theme = t; if let th = AppTheme(rawValue: t) { theme = th } }
        if let cm = data.colorMode { budget.colorMode = cm; if let c = AppColorMode(rawValue: cm) { colorMode = c } }
        if let f = data.font { budget.font = f; if let fn = AppFont(rawValue: f) { font = fn } }
        if let s = data.startOfWeek { budget.startOfWeek = s }
        if let a = data.autoAnalysisEnabled { budget.autoAnalysisEnabled = a }
        if let d = data.dailyAnalysisTime { budget.dailyAnalysisTime = d }
        if let w = data.weeklyAnalysisTime { budget.weeklyAnalysisTime = w }
        if let m = data.monthlyAnalysisTime { budget.monthlyAnalysisTime = m }
        if let be = data.budgetAlertsEnabled { budget.budgetAlertsEnabled = be }
        if let bee = data.budgetAlertsEmailEnabled { budget.budgetAlertsEmailEnabled = bee }
        if let bp = data.budgetAlertsPushEnabled { budget.budgetAlertsPushEnabled = bp }
        if let ae = data.alertEmail { budget.alertEmail = ae }
        if let cc = data.customCategories { budget.customCategories = cc }
        budgets[0] = budget
        saveLocalData()
    }

    func addCustomCategory(_ name: String) {
        guard let budget = currentBudget else { return }
        var customs = budget.customCategories ?? []
        guard !customs.contains(name) else { return }
        customs.append(name)
        let data = BudgetData(
            monthlyIncome: budget.monthlyIncome,
            monthlyEssentials: budget.monthlyEssentials,
            monthlySavingsGoal: budget.monthlySavingsGoal,
            payDay: budget.payDay,
            customCategories: customs
        )
        Task {
            do {
                let updated: Budget = try await client.update(entity: "Budget", id: budget.id, data: data)
                if let idx = budgets.firstIndex(where: { $0.id == budget.id }) {
                    budgets[idx] = updated
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func generateForecast() async throws -> AIResult {
        let s = spendSummary
        let cal = Calendar.current
        let thisMonth = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        }
        let thisMonthSpent = thisMonth.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let thisMonthIncome = thisMonth.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }

        // Previous months for comparison (up to 3 months back)
        var pastMonthsData: [(label: String, spent: Double)] = []
        for offset in 1...3 {
            guard let monthStart = cal.date(byAdding: .month, value: -offset, to: Date()) else { continue }
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: monthStart, toGranularity: .month) && tx.type == .expense
            }
            let total = monthTxns.reduce(0) { $0 + $1.amount }
            let df = DateFormatter(); df.dateFormat = "MMM"
            pastMonthsData.append((df.string(from: monthStart), total))
        }

        let byCategory: [String: Double] = Dictionary(grouping: thisMonth.filter { $0.type == .expense }, by: { $0.category ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }
        let catLines = byCategory.map { "\($0.key): \(CurrencyFormat.format($0.value, currency: currency))" }.joined(separator: "\n")

        // Current month trend (weekly)
        let currentLabel = {
            let df = DateFormatter(); df.dateFormat = "MMM"
            return df.string(from: Date())
        }()

        let prompt = """
        You are a precise personal finance forecaster. Use ONLY the data below. NEVER invent numbers.

        This month's spending by category:
        \(catLines.isEmpty ? "No spending data this month." : catLines)

        This month: Spent \(CurrencyFormat.format(thisMonthSpent, currency: currency)), Income \(CurrencyFormat.format(thisMonthIncome, currency: currency))
        Past months: \(pastMonthsData.map { "\($0.label): \(CurrencyFormat.format($0.spent, currency: currency))" }.joined(separator: ", "))
        Daily safe spend: \(CurrencyFormat.format(s.safeDaily, currency: currency))
        Days remaining: \(s.daysLeft)

        INSTRUCTIONS: Write a 2-3 sentence forecast in \(promptLanguage).
        - Predict whether they'll stay within budget.
        - Suggest one specific category to cut back.
        - Estimate next month's total spending.
        """

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": .object([
                "summary": .object(["type": "string"]),
                "forecast_amount": .object(["type": "number"]),
                "top_forecasted_category": .object(["type": "string"]),
                "saving_tip": .object(["type": "string"]),
            ]),
            "required": .array([.string("summary")]),
        ]
        let raw = try await client.invokeLLM(prompt: prompt, responseJSONSchema: schema)
        let formatted = formatForecastResult(raw)

        // Compute chart data
        var trendData: [(String, Double)] = []
        for pm in pastMonthsData.reversed() { trendData.append((pm.label, pm.spent)) }
        trendData.append((currentLabel, thisMonthSpent))
        trendData.append((loc("Next Month"), 0)) // placeholder for visual

        let catChart = byCategory.map { (name: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }.map { (name: $0.name, amount: $0.amount) }

        let now = ISO8601DateFormatter().string(from: Date())
        let historyData = AnalysisHistoryData(type: "forecast", content: formatted, analysisDate: now, categoryChartJSON: chartJSON(catChart), dailyChartJSON: chartJSON(trendData))
        let saved: AnalysisHistory = try await client.create(entity: "AnalysisHistory", data: historyData)
        analysisHistory.insert(saved, at: 0)

        await incrementUsage("forecast")
        let res = AIResult(text: formatted, categoryChart: catChart, dailyChart: trendData)
        currentForecastResult = res
        return res
    }

    private func formatForecastResult(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        var parts: [String] = []
        if let summary = json["summary"] as? String { parts.append(summary) }
        if let forecast = json["forecast_amount"] as? Double {
            parts.append("\(l.totalSpent) (est): \(CurrencyFormat.format(forecast, currency: currency))")
        }
        if let topCat = json["top_forecasted_category"] as? String {
            parts.append("\(l.topCategory): \(topCat)")
        }
        if let tip = json["saving_tip"] as? String { parts.append("\(l.suggestion): \(tip)") }
        return parts.isEmpty ? raw : parts.joined(separator: "\n\n")
    }

    // MARK: - Auth

    func checkAuth() async {
        isLoadingAuth = true
        if let token = AuthService.getToken() {
            await client.setToken(token)
            do {
                user = try await client.me()
                isAuthenticated = true
                loadLocalData()
            } catch let error as ClientError where error.localizedDescription.contains("unauthorized") || error.localizedDescription.contains("401") {
                AuthService.deleteToken()
                await client.setToken(nil)
                continueAsGuest()
                await finishGuestSetup()
            } catch {
                loadFromCache()
                isAuthenticated = true
            }
        } else {
            continueAsGuest()
            await finishGuestSetup()
        }
        isLoadingAuth = false
    }

    func loginWithEmail(email: String, password: String) {
        authError = nil
        isAuthenticating = true
        Task {
            do {
                let response = try await client.login(email: email, password: password)
                guard let token = response.accessToken else {
                    authError = "No access token received"
                    isAuthenticating = false
                    return
                }
                await completeSignIn(token: token)
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }

    var pendingOTPEmail = ""
    var showOTPEntry = false

    func registerWithEmail(email: String, password: String) {
        authError = nil
        isAuthenticating = true
        Task {
            do {
                _ = try await client.register(email: email, password: password)
                // Registration requires OTP verification
                pendingOTPEmail = email
                showOTPEntry = true
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }

    func verifyOTPAndSignIn(code: String) {
        authError = nil
        isAuthenticating = true
        let email = pendingOTPEmail
        Task {
            do {
                let response = try await client.verifyOtp(email: email, otpCode: code)
                guard let token = response.accessToken else {
                    authError = "No access token received"
                    isAuthenticating = false
                    return
                }
                await completeSignIn(token: token)
                isAuthenticating = false
                showOTPEntry = false
                pendingOTPEmail = ""
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }

    func startAppleSignIn() {
        authError = nil
        isAuthenticating = true
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate { [weak self] result in
            self?.appleSignInDelegate = nil
            self?.appleSignInController = nil
            Task { @MainActor in
                await self?.handleAppleResult(result)
            }
        }
        self.appleSignInDelegate = delegate
        self.appleSignInController = controller
        controller.delegate = delegate
        controller.presentationContextProvider = AuthPresentationProvider.shared
        controller.performRequests()
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                authError = "Invalid Apple credential"
                isAuthenticating = false
                return
            }

            // Decode JWT payload to get Apple user ID and email
            let jwtPayload: [String: Any]? = {
                let parts = tokenString.components(separatedBy: ".")
                guard parts.count >= 2 else { return nil }
                var padded = parts[1]
                while padded.count % 4 != 0 { padded += "=" }
                guard let data = Data(base64Encoded: padded.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")) else { return nil }
                return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            }()

            guard let appleID = jwtPayload?["sub"] as? String else {
                authError = "Could not read Apple ID"
                isAuthenticating = false
                return
            }

            // Use Apple's real email from credential (first sign-in) or JWT (subsequent)
            let email = credential.email ?? (jwtPayload?["email"] as? String)
            let fullName = credential.fullName.map { name in
                [name.givenName, name.familyName].compactMap { $0 }.joined(separator: " ")
            }

            // Deterministic credentials from Apple user ID
            let accountEmail = email ?? "\(String(appleID.suffix(12)))@clearspend.app"
            let accountPassword = "apple_\(appleID.suffix(16))"

            do {
                let response: Base44Client.AuthResponse
                do {
                    response = try await client.login(email: accountEmail, password: accountPassword)
                } catch {
                    response = try await client.register(email: accountEmail, password: accountPassword)
                    if let realName = fullName {
                        _ = try? await client.updateMe(data: ["name": .string(realName)])
                    }
                }

                guard let accessToken = response.accessToken else {
                    authError = "No access token received"
                    isAuthenticating = false
                    return
                }
                await completeSignIn(token: accessToken)
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                isAuthenticating = false
                return
            }
            self.authError = error.localizedDescription
            isAuthenticating = false
        }
    }

    private func completeSignIn(token: String) async {
        AuthService.storeToken(token)
        await client.setToken(token)
        do {
            isGuestMode = false
            user = try await client.me()
            isAuthenticated = true
            loadLocalData()
        } catch {
            AuthService.deleteToken()
            await client.setToken(nil)
            authError = error.localizedDescription
        }
    }

    // MARK: - AI

    struct AIResult {
        let text: String
        let categoryChart: [(name: String, amount: Double)]
        let dailyChart: [(day: String, amount: Double)]
    }

    func generateDailyAnalysis() async throws -> AIResult {
        let summary = spendSummary
        let todayTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return Calendar.current.isDateInToday(date)
        }
        let todaySpent = todayTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let todayIncome = todayTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let txnLines = todayTxns.map { tx in
            let symbol = tx.type == .income ? "+" : "-"
            return "\(symbol)\(CurrencyFormat.format(tx.amount, currency: currency)) \(tx.category ?? "uncategorized") \(tx.merchant ?? "")"
        }.joined(separator: "\n")

        let prompt = """
        You are a precise personal finance assistant. Use ONLY the data below. NEVER invent numbers.

        Today's transactions:
        \(txnLines.isEmpty ? "No transactions today." : txnLines)

        Totals:
        - Spent: \(CurrencyFormat.format(todaySpent, currency: currency))
        - Income: \(CurrencyFormat.format(todayIncome, currency: currency))
        - Daily safe spend: \(CurrencyFormat.format(summary.safeDaily, currency: currency))

        INSTRUCTIONS: Output in \(promptLanguage).
        - title: A short headline summarizing today (e.g. "On track" or "Over budget warning").
        - summary: 1-2 sentences comparing today's spend to the safe daily limit.
        - top_category: The highest-spend category today with its amount, or "none".
        \(isPro ? "- unusual: Flag any transaction that is unusually large or out of pattern compared to normal spending, or say \\\"none\\\"." : "")
        """

        let props: [String: AnyCodable] = {
            var p: [String: AnyCodable] = [
                "title": .object(["type": "string"]),
                "summary": .object(["type": "string"]),
                "top_category": .object(["type": "string"]),
            ]
            if isPro { p["unusual"] = .object(["type": "string"]) }
            return p
        }()

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": .object(props),
            "required": .array([.string("title"), .string("summary"), .string("top_category")]),
        ]

        let raw = try await client.invokeLLM(prompt: prompt, responseJSONSchema: schema)
        let formatted = formatResult(raw, type: "daily")

        let today = ISO8601DateFormatter().string(from: Date())
        let historyData = AnalysisHistoryData(type: "daily", content: formatted, analysisDate: today, categoryChartJSON: nil, dailyChartJSON: nil)
        let saved: AnalysisHistory = try await client.create(entity: "AnalysisHistory", data: historyData)
        analysisHistory.insert(saved, at: 0)

        await incrementUsage("daily")
        let res = AIResult(text: formatted, categoryChart: [], dailyChart: [])
        currentDailyResult = res
        return res
    }

    func generateWeeklyAnalysis() async throws -> AIResult {
        let summary = spendSummary
        let cal = Calendar.current
        let thisWeekTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.dateComponents([.day], from: date, to: Date()).day ?? 999 <= 7
        }
        let lastWeekStart = cal.date(byAdding: .day, value: -14, to: Date())!
        let lastWeekEnd = cal.date(byAdding: .day, value: -7, to: Date())!
        let lastWeekTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return date >= lastWeekStart && date < lastWeekEnd
        }

        let thisWeekSpent = thisWeekTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let lastWeekSpent = lastWeekTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

        let thisWeekByCat = Dictionary(grouping: thisWeekTxns.filter { $0.type == .expense }, by: { $0.category ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }
        let lastWeekByCat = Dictionary(grouping: lastWeekTxns.filter { $0.type == .expense }, by: { $0.category ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }

        let catLines = thisWeekByCat.map { "\($0.key): \(CurrencyFormat.format($0.value, currency: currency))" }.joined(separator: ", ")
        let lastCatLines = lastWeekByCat.map { "\($0.key): \(CurrencyFormat.format($0.value, currency: currency))" }.joined(separator: ", ")

        let prompt = """
        You are a precise personal finance analyst. Use ONLY the data below. NEVER invent numbers.

        This week's spending by category: \(catLines.isEmpty ? "none" : catLines)
        Last week's spending by category: \(lastCatLines.isEmpty ? "none" : lastCatLines)
        This week total spent: \(CurrencyFormat.format(thisWeekSpent, currency: currency))
        Last week total spent: \(CurrencyFormat.format(lastWeekSpent, currency: currency))
        Daily safe spend: \(CurrencyFormat.format(summary.safeDaily, currency: currency))
        Days remaining this month: \(summary.daysLeft)

        INSTRUCTIONS: Output in \(promptLanguage).
        - summary: 2 sentences comparing this week to last week, noting the biggest change in spending.
        - top_category: The highest-spend category this week.
        - vs_last_week: A comparison like "This week (+15% vs last week)" or "This week (-8% vs last week)" based on totals.
        \(isPro ? "- tip: One specific, actionable spending tip for next week." : "")
        \(isPro ? "- trend_data: An array of 4 objects with keys \\\"week\\\" (string like \\\"W1\\\", \\\"W2\\\") and \\\"categories\\\" (array of objects with \\\"name\\\" and \\\"amount\\\") representing the last 4 weeks of category spending for a trend chart. Use real category names from the data above." : "")
        """

        let props: [String: AnyCodable] = {
            var p: [String: AnyCodable] = [
                "summary": .object(["type": "string"]),
                "top_category": .object(["type": "string"]),
                "vs_last_week": .object(["type": "string"]),
            ]
            if isPro {
                p["tip"] = .object(["type": "string"])
                p["trend_data"] = .object([
                    "type": "array",
                    "items": .object([
                        "type": "object",
                        "properties": .object([
                            "week": .object(["type": "string"]),
                            "categories": .object([
                                "type": "array",
                                "items": .object([
                                    "type": "object",
                                    "properties": .object([
                                        "name": .object(["type": "string"]),
                                        "amount": .object(["type": "number"]),
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])
            }
            return p
        }()

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": .object(props),
            "required": .array([.string("summary"), .string("top_category"), .string("vs_last_week")]),
        ]

        let raw = try await client.invokeLLM(prompt: prompt, responseJSONSchema: schema)
        let formatted = formatResult(raw, type: "weekly")

        let now = ISO8601DateFormatter().string(from: Date())
        let trendData = computeWeeklyTrend()
        let historyData = AnalysisHistoryData(type: "weekly", content: formatted, analysisDate: now, categoryChartJSON: nil, dailyChartJSON: chartJSON(trendData))
        let saved: AnalysisHistory = try await client.create(entity: "AnalysisHistory", data: historyData)
        analysisHistory.insert(saved, at: 0)

        await incrementUsage("recap")
        let res = AIResult(text: formatted, categoryChart: [], dailyChart: trendData)
        currentWeeklyResult = res
        return res
    }

    func generateMonthlyAnalysis() async throws -> AIResult {
        let budget = currentBudget
        let s = spendSummary
        let cal = Calendar.current
        let monthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: Date(), toGranularity: .month)
        }
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
        }

        let monthSpent = monthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let monthIncome = monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let lastMonthSpent = lastMonthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

        let thisByCat = Dictionary(grouping: monthTxns.filter { $0.type == .expense }, by: { $0.category ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }
        let lastByCat = Dictionary(grouping: lastMonthTxns.filter { $0.type == .expense }, by: { $0.category ?? "other" })
            .mapValues { txns in txns.reduce(0) { $0 + $1.amount } }

        let catLines = thisByCat.map { "\($0.key): \(CurrencyFormat.format($0.value, currency: currency))" }.joined(separator: ", ")
        let lastCatLines = lastByCat.map { "\($0.key): \(CurrencyFormat.format($0.value, currency: currency))" }.joined(separator: ", ")

        let disposable = (budget?.monthlyIncome ?? 0) - (budget?.monthlyEssentials ?? 0) - (budget?.monthlySavingsGoal ?? 0)
        let budgetPct = disposable > 0 ? Int(min(100, (monthSpent / disposable) * 100)) : 0

        let prompt = """
        You are a precise personal finance analyst. Use ONLY the data below. NEVER invent numbers.

        This month's spending by category: \(catLines.isEmpty ? "none" : catLines)
        Last month's spending by category: \(lastCatLines.isEmpty ? "none" : lastCatLines)
        This month spent: \(CurrencyFormat.format(monthSpent, currency: currency))
        This month income: \(CurrencyFormat.format(monthIncome, currency: currency))
        Last month spent: \(CurrencyFormat.format(lastMonthSpent, currency: currency))
        Monthly budget (disposable): \(CurrencyFormat.format(disposable, currency: currency))
        Budget used: \(budgetPct)%
        Days remaining: \(s.daysLeft)

        INSTRUCTIONS: Output in \(promptLanguage).
        - headline: A short summary of budget adherence (e.g. "On track this month" or "Over budget").
        - summary: 2-3 sentences analyzing overall spending vs budget, the biggest category changes from last month, and whether they're likely to stay within budget.
        - budget_adherence: A comparison like "\(budgetPct)% of budget used with \(s.daysLeft) days left".
        - biggest_change: Which category changed the most from last month and by how much.
        - next_step: One actionable recommendation for the remaining days.
        - category_chart: An array of objects with "name" and "amount" for this month's spending by category (for a pie chart).
        """

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": .object([
                "headline": .object(["type": "string"]),
                "summary": .object(["type": "string"]),
                "budget_adherence": .object(["type": "string"]),
                "biggest_change": .object(["type": "string"]),
                "next_step": .object(["type": "string"]),
                "category_chart": .object([
                    "type": "array",
                    "items": .object([
                        "type": "object",
                        "properties": .object([
                            "name": .object(["type": "string"]),
                            "amount": .object(["type": "number"]),
                        ])
                    ])
                ]),
            ]),
            "required": .array([.string("headline"), .string("summary")]),
        ]

        let raw = try await client.invokeLLM(prompt: prompt, responseJSONSchema: schema)
        let formatted = formatResult(raw, type: "monthly")

        let now = ISO8601DateFormatter().string(from: Date())
        let catChart = computeCategoryBreakdown()
        let historyData = AnalysisHistoryData(type: "monthly", content: formatted, analysisDate: now, categoryChartJSON: chartJSON(catChart), dailyChartJSON: nil)
        let saved: AnalysisHistory = try await client.create(entity: "AnalysisHistory", data: historyData)
        analysisHistory.insert(saved, at: 0)

        await incrementUsage("insight")
        let res = AIResult(text: formatted, categoryChart: catChart, dailyChart: [])
        currentMonthlyResult = res
        return res
    }

    private func formatResult(_ raw: String, type: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        var parts: [String] = []
        switch type {
        case "daily":
            if let title = json["title"] as? String { parts.append(title) }
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let top = json["top_category"] as? String { parts.append("\(l.topCategory): \(top)") }
            if let unusual = json["unusual"] as? String, unusual.lowercased() != "none" {
                parts.append("⚠️ \(unusual)")
            }
        case "weekly":
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let top = json["top_category"] as? String { parts.append("\(l.topCategory): \(top)") }
            if let vs = json["vs_last_week"] as? String { parts.append(vs) }
            if let tip = json["tip"] as? String { parts.append("💡 \(l.suggestion): \(tip)") }
        case "monthly":
            if let h = json["headline"] as? String { parts.append(h) }
            if let summary = json["summary"] as? String { parts.append(summary) }
            if let adh = json["budget_adherence"] as? String { parts.append(adh) }
            if let chg = json["biggest_change"] as? String { parts.append("📊 \(chg)") }
            if let next = json["next_step"] as? String { parts.append("\(l.nextStep): \(next)") }
        default:
            return raw
        }
        return parts.isEmpty ? raw : parts.joined(separator: "\n\n")
    }

    private func parseChartData(from raw: String) -> ([(String, Double)], [(String, Double)]) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [])
        }
        // category_chart for pie charts
        let cats = (json["category_chart"] as? [[String: Any]])?.compactMap { c -> (String, Double)? in
            guard let name = c["name"] as? String, let amt = c["amount"] as? Double else { return nil }
            return (name, amt)
        } ?? []
        // trend_data for weekly 4-week trend (flattened into daily chart format)
        let days = (json["trend_data"] as? [[String: Any]])?.flatMap { week -> [(String, Double)] in
            guard let weekName = week["week"] as? String,
                  let categories = week["categories"] as? [[String: Any]] else { return [] }
            return categories.compactMap { cat -> (String, Double)? in
                guard let name = cat["name"] as? String, let amt = cat["amount"] as? Double else { return nil }
                return ("\(weekName) \(name)", amt)
            }
        } ?? []
        return (cats, days)
    }

    func chartsForHistory(_ item: AnalysisHistory) -> (category: [(name: String, amount: Double)], daily: [(day: String, amount: Double)]) {
        let cal = Calendar.current
        let refDate: Date = {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = item.analysisDate ?? item.createdDate, let date = fmt.date(from: d) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let d = item.analysisDate ?? item.createdDate, let date = fmt.date(from: d) { return date }
            return Date()
        }()

        switch item.type {
        case "weekly":
            // Compute 4-week trend around the analysis date
            var trend: [(String, Double)] = []
            for weekOffset in stride(from: 3, through: 0, by: -1) {
                guard let weekStart = cal.date(byAdding: .day, value: -(weekOffset * 7 + 7), to: refDate),
                      let weekEnd = cal.date(byAdding: .day, value: -(weekOffset * 7), to: refDate) else { continue }
                let weekTxns = transactions.filter { tx in
                    guard let date = tx.dateValue else { return false }
                    return date >= weekStart && date < weekEnd && tx.type == .expense
                }
                let total = weekTxns.reduce(0) { $0 + $1.amount }
                let df = DateFormatter(); df.dateFormat = "M/d"
                trend.append((df.string(from: weekStart), total))
            }
            return ([], trend)

        case "monthly":
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: refDate, toGranularity: .month) && tx.type == .expense
            }
            let grouped = Dictionary(grouping: monthTxns, by: { $0.category ?? "other" })
            let cats = grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.1 > $1.1 }
                .map { (name: $0.0, amount: $0.1) }
            return (cats, [])

        case "forecast":
            // Category breakdown for current month
            let monthTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return cal.isDate(date, equalTo: refDate, toGranularity: .month) && tx.type == .expense
            }
            let grouped = Dictionary(grouping: monthTxns, by: { $0.category ?? "other" })
            let cats = grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
                .sorted { $0.1 > $1.1 }
                .map { (name: $0.0, amount: $0.1) }

            // Trend: past 3 months + current
            var trend: [(String, Double)] = []
            for offset in stride(from: 3, through: 0, by: -1) {
                guard let monthStart = cal.date(byAdding: .month, value: -offset, to: refDate) else { continue }
                let txns = transactions.filter { tx in
                    guard let date = tx.dateValue else { return false }
                    return cal.isDate(date, equalTo: monthStart, toGranularity: .month) && tx.type == .expense
                }
                let total = txns.reduce(0) { $0 + $1.amount }
                let df = DateFormatter(); df.dateFormat = "MMM"
                trend.append((df.string(from: monthStart), total))
            }
            return (cats, trend)

        default:
            return ([], [])
        }
    }

    private func computeWeeklyTrend() -> [(String, Double)] {
        let cal = Calendar.current
        var result: [(String, Double)] = []
        for weekOffset in stride(from: 3, through: 0, by: -1) {
            guard let weekStart = cal.date(byAdding: .day, value: -(weekOffset * 7 + 7), to: Date()),
                  let weekEnd = cal.date(byAdding: .day, value: -(weekOffset * 7), to: Date()) else { continue }
            let weekTxns = transactions.filter { tx in
                guard let date = tx.dateValue else { return false }
                return date >= weekStart && date < weekEnd && tx.type == .expense
            }
            let total = weekTxns.reduce(0) { $0 + $1.amount }
            let label: String = {
                let df = DateFormatter(); df.dateFormat = "M/d"
                return "\(df.string(from: weekStart))"
            }()
            result.append((label, total))
        }
        return result
    }

    private func computeCategoryBreakdown() -> [(String, Double)] {
        let monthTxns = transactions.filter { tx in
            guard let date = tx.dateValue else { return false }
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: monthTxns, by: { $0.category ?? "other" })
        return grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
            .map { (name: $0.0, amount: $0.1) }
    }

    private func chartJSON(_ data: [(String, Double)]) -> String? {
        guard !data.isEmpty else { return nil }
        let arr = data.map { ["name": $0.0, "amount": $0.1] }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: arr) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    // MARK: - AI Formatting

    private var l: AILabels {
        switch language {
        case "ja": return .init(topCategory: "トップカテゴリ", pattern: "パターン", suggestion: "アドバイス",
                                 totalSpent: "支出合計", totalIncome: "収入合計", budgetUsed: "予算使用率", nextStep: "次のステップ")
        case "zh": return .init(topCategory: "主要类别", pattern: "消费模式", suggestion: "建议",
                                 totalSpent: "总支出", totalIncome: "总收入", budgetUsed: "预算使用率", nextStep: "下一步")
        default:  return .init(topCategory: "Top category", pattern: "Pattern", suggestion: "Suggestion",
                                 totalSpent: "Total spent", totalIncome: "Total income", budgetUsed: "Budget used", nextStep: "Next step")
        }
    }

    private struct AILabels {
        let topCategory, pattern, suggestion: String
        let totalSpent, totalIncome, budgetUsed, nextStep: String
    }

    private var userCachePrefix: String {
        "user_\(user?.id ?? "guest")_"
    }

    private var promptLanguage: String {
        switch language {
        case "ja": return "Japanese"
        case "zh": return "Simplified Chinese"
        default: return "English"
        }
    }

    // MARK: - Localization

    var homeTab: String {
        switch language { case "ja": return "ホーム"; case "zh": return "首页"; default: return "Home" }
    }
    var activityTab: String {
        switch language { case "ja": return "取引"; case "zh": return "交易"; default: return "Activity" }
    }
    var goalsTab: String {
        switch language { case "ja": return "目標"; case "zh": return "目标"; default: return "Goals" }
    }
    var aiTab: String {
        switch language { case "ja": return "AI"; case "zh": return "AI"; default: return "AI" }
    }
    var healthTab: String {
        switch language { case "ja": return "分析"; case "zh": return "分析"; default: return "Health" }
    }
    var settingsTitle: String {
        switch language { case "ja": return "設定"; case "zh": return "设置"; default: return "Settings" }
    }
    var appearanceSection: String {
        switch language { case "ja": return "デザイン"; case "zh": return "外观"; default: return "Appearance" }
    }
    var budgetSection: String {
        switch language { case "ja": return "予算"; case "zh": return "预算"; default: return "Budget" }
    }
    var preferencesSection: String {
        switch language { case "ja": return "設定"; case "zh": return "偏好"; default: return "Preferences" }
    }
    var analysisSectionLabel: String {
        switch language { case "ja": return "自動分析"; case "zh": return "自动分析"; default: return "Auto Analysis" }
    }
    var dataSectionLabel: String {
        switch language { case "ja": return "データ"; case "zh": return "数据"; default: return "Data" }
    }
    var accountSectionLabel: String {
        switch language { case "ja": return "アカウント"; case "zh": return "账户"; default: return "Account" }
    }
    var signOutLabel: String {
        switch language { case "ja": return "サインアウト"; case "zh": return "退出登录"; default: return "Sign Out" }
    }
    var deleteAccountLabel: String {
        switch language { case "ja": return "アカウント削除"; case "zh": return "删除账户"; default: return "Delete Account" }
    }
    var exportCSVLabel: String {
        switch language { case "ja": return "CSVエクスポート"; case "zh": return "导出CSV"; default: return "Export as CSV" }
    }
    var autoAnalysisLabel: String {
        switch language { case "ja": return "自動分析を有効にする"; case "zh": return "启用自动分析"; default: return "Enable Auto Analysis" }
    }
    var signOutConfirmTitle: String { self.signOutLabel }
    var signOutConfirmMessage: String {
        switch language { case "ja": return "本当にサインアウトしますか？データは保持されます。"; case "zh": return "确定要退出登录吗？数据会被保留。"; default: return "Are you sure you want to sign out? Your data will be preserved." }
    }
    var deleteConfirmTitle: String { self.deleteAccountLabel }
    var deleteConfirmMessage: String {
        switch language { case "ja": return "すべてのデータが永久に削除されます。この操作は取り消せません。"; case "zh": return "这将永久删除所有数据。此操作无法撤销。"; default: return "This will permanently delete all data. This action cannot be undone." }
    }
    var cancelLabel: String {
        switch language { case "ja": return "キャンセル"; case "zh": return "取消"; default: return "Cancel" }
    }
    var deleteLabel: String {
        switch language { case "ja": return "削除"; case "zh": return "删除"; default: return "Delete" }
    }
    var languageLabel: String {
        switch language { case "ja": return "言語"; case "zh": return "语言"; default: return "Language" }
    }
    var currencyLabel: String {
        switch language { case "ja": return "通貨"; case "zh": return "货币"; default: return "Currency" }
    }
    var themeLabel: String {
        switch language { case "ja": return "テーマ"; case "zh": return "主题"; default: return "Theme" }
    }
    var colorModeLabel: String {
        switch language { case "ja": return "カラーモード"; case "zh": return "颜色模式"; default: return "Color Mode" }
    }
    var fontLabel: String {
        switch language { case "ja": return "フォント"; case "zh": return "字体"; default: return "Font" }
    }
    var dailyTabLabel: String {
        switch language { case "ja": return "デイリー"; case "zh": return "每日"; default: return "Daily" }
    }
    var weeklyTabLabel: String {
        switch language { case "ja": return "ウィークリー"; case "zh": return "每周"; default: return "Weekly" }
    }
    var monthlyTabLabel: String {
        switch language { case "ja": return "マンスリー"; case "zh": return "每月"; default: return "Monthly" }
    }
    var aiInsightsTitle: String {
        switch language { case "ja": return "AIインサイト"; case "zh": return "AI洞察"; default: return "AI Insights" }
    }
    var generatingLabel: String {
        switch language { case "ja": return "分析を生成中..."; case "zh": return "正在生成分析..."; default: return "Generating insights..." }
    }
    var resultLabel: String {
        switch language { case "ja": return "結果"; case "zh": return "结果"; default: return "Result" }
    }
    var clearLabel: String {
        switch language { case "ja": return "クリア"; case "zh": return "清除"; default: return "Clear" }
    }
    var generateLabel: String {
        switch language { case "ja": return "生成"; case "zh": return "生成"; default: return "Generate" }
    }
    var historyLabel: String {
        switch language { case "ja": return "履歴"; case "zh": return "历史"; default: return "History" }
    }
    func freeUsesRemaining(_ n: Int) -> String {
        switch language { case "ja": return "今月の無料利用はあと\(n)回です"; case "zh": return "本月剩余免费使用次数：\(n)"; default: return "\(n) free uses remaining this month" }
    }
    var dailyAnalysisTitle: String {
        switch language { case "ja": return "今日の分析"; case "zh": return "每日分析"; default: return "Daily Analysis" }
    }
    var dailyAnalysisSubtitle: String {
        switch language { case "ja": return "今日の支出パターンのAI分析を取得"; case "zh": return "获取今日消费模式的AI分析"; default: return "Get an AI recap of today's spending patterns" }
    }
    var weeklyRecapTitle: String {
        switch language { case "ja": return "週間レポート"; case "zh": return "每周回顾"; default: return "Weekly Recap" }
    }
    var weeklyRecapSubtitle: String {
        switch language { case "ja": return "過去7日間の支出を振り返る"; case "zh": return "回顾过去7天的消费"; default: return "Review your spending over the past 7 days" }
    }
    var monthlyInsightTitle: String {
        switch language { case "ja": return "月間分析"; case "zh": return "月度洞察"; default: return "Monthly Insight" }
    }
    var monthlyInsightSubtitle: String {
        switch language { case "ja": return "月間の財務状況の詳細分析"; case "zh": return "月度财务健康状况的深度分析"; default: return "Deep analysis of your monthly financial health" }
    }
    var upgradeTitle: String {
        switch language { case "ja": return "アップグレード"; case "zh": return "升级"; default: return "Upgrade" }
    }
    var upgradeToProLabel: String {
        switch language { case "ja": return "Proにアップグレード"; case "zh": return "升级到Pro"; default: return "Upgrade to Pro" }
    }
    var monthlyInsightRequiresPro: String {
        switch language { case "ja": return "月間分析はProが必要です"; case "zh": return "月度洞察需要Pro"; default: return "Monthly Insights require Pro" }
    }
    var upgradeDescription: String {
        switch language {
        case "ja": return "ClearSpend Proにアップグレードして、カスタムカテゴリ、支出予測、ビジュアルチャート、無制限のレシートスキャンを解除しましょう。"
        case "zh": return "升级到ClearSpend Pro以解锁自定义类别、支出预测、可视化图表和无限收据扫描。"
        default: return "Upgrade to ClearSpend Pro to unlock custom categories, spending forecasts, visual charts, and unlimited receipt scanning."
        }
    }
    var subscribeLabel: String {
        switch language { case "ja": return "購読する"; case "zh": return "订阅"; default: return "Subscribe" }
    }
    var restoreLabel: String {
        switch language { case "ja": return "購入を復元"; case "zh": return "恢复购买"; default: return "Restore Purchases" }
    }
    var addTransactionTitle: String {
        switch language { case "ja": return "取引を追加"; case "zh": return "添加交易"; default: return "Add Transaction" }
    }
    var expenseLabel: String {
        switch language { case "ja": return "支出"; case "zh": return "支出"; default: return "Expense" }
    }
    var incomeLabel: String {
        switch language { case "ja": return "収入"; case "zh": return "收入"; default: return "Income" }
    }
    var amountLabel: String {
        switch language { case "ja": return "金額"; case "zh": return "金额"; default: return "Amount" }
    }
    var categoryLabel: String {
        switch language { case "ja": return "カテゴリ"; case "zh": return "类别"; default: return "Category" }
    }
    var noteLabel: String {
        switch language { case "ja": return "メモ"; case "zh": return "备注"; default: return "Note" }
    }
    var dateLabel: String {
        switch language { case "ja": return "日付"; case "zh": return "日期"; default: return "Date" }
    }
    var saveLabel: String {
        switch language { case "ja": return "保存"; case "zh": return "保存"; default: return "Save" }
    }
    var weekStartsLabel: String {
        switch language { case "ja": return "週の始まり"; case "zh": return "每周开始日"; default: return "Week Starts" }
    }
    var sundayLabel: String {
        switch language { case "ja": return "日曜日"; case "zh": return "周日"; default: return "Sunday" }
    }
    var mondayLabel: String {
        switch language { case "ja": return "月曜日"; case "zh": return "周一"; default: return "Monday" }
    }
    var monthlyIncomeLabel: String {
        switch language { case "ja": return "月収"; case "zh": return "月收入"; default: return "Monthly Income" }
    }
    var essentialsLabel: String {
        switch language { case "ja": return "固定費"; case "zh": return "固定支出"; default: return "Essentials" }
    }
    var savingsGoalLabel: String {
        switch language { case "ja": return "貯金目標"; case "zh": return "储蓄目标"; default: return "Savings Goal" }
    }
    var payDayLabel: String {
        switch language { case "ja": return "給料日"; case "zh": return "发薪日"; default: return "Pay Day" }
    }
    var dayLabel: (Int) -> String {
        switch language {
        case "ja": return { "\($0)日" }
        case "zh": return { "第\($0)天" }
        default: return { "Day \($0)" }
        }
    }
    var editBudgetLabel: String {
        switch language { case "ja": return "予算を編集"; case "zh": return "编辑预算"; default: return "Edit Budget" }
    }
    var savingDots: String {
        switch language { case "ja": return "保存中..."; case "zh": return "保存中..."; default: return "Saving..." }
    }
    var scanReceiptLabel: String {
        switch language { case "ja": return "レシートをスキャン"; case "zh": return "扫描收据"; default: return "Scan Receipt" }
    }
    var voiceInputLabel: String {
        switch language { case "ja": return "音声入力"; case "zh": return "语音输入"; default: return "Voice Input" }
    }
    var usageExhaustedFreeTitle: String {
        switch language { case "ja": return "利用制限に達しました"; case "zh": return "使用次数已用完"; default: return "Usage Limit Reached" }
    }
    var usageExhaustedFreeMessage: String {
        switch language { case "ja": return "今月の無料利用回数を使い切りました。ClearSpend Proにアップグレードして、より多くの分析と機能をお楽しみください。"; case "zh": return "您本月的免费使用次数已用完。升级到ClearSpend Pro以获取更多分析和功能。"; default: return "You've used all your free attempts this month. Upgrade to ClearSpend Pro for more analyses and features." }
    }
    var usageExhaustedProTitle: String {
        switch language { case "ja": return "月間制限に達しました"; case "zh": return "月度使用次数已用完"; default: return "Monthly Limit Reached" }
    }
    var usageExhaustedProMessage: String {
        switch language { case "ja": return "今月のご利用回数を使い切りました。次の月次リセットまでお待ちください。"; case "zh": return "您本月的使用次数已用完。请等待下月重置。"; default: return "You've used all your monthly attempts. Please wait for the next monthly reset." }
    }
    var okLabel: String {
        switch language { case "ja": return "OK"; case "zh": return "确定"; default: return "OK" }
    }
    var devModeEnabled: String {
        switch language { case "ja": return "開発者モード有効"; case "zh": return "开发者模式已启用"; default: return "Developer Mode Enabled" }
    }
    var devModeUnlimited: String {
        switch language { case "ja": return "すべての機能が無制限になりました"; case "zh": return "所有功能现在无限制"; default: return "All features are now unlimited" }
    }

    // MARK: - Generic Localization

    var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return loc(hour < 17 ? "Good morning, " : "Good evening, ")
    }

    func loc(_ key: String) -> String {
        switch language {
        case "ja": return Self.jaDict[key] ?? LocalizationStrings.ja[key] ?? key
        case "zh": return Self.zhDict[key] ?? LocalizationStrings.zh[key] ?? key
        default: return key
        }
    }

    private static let jaDict: [String: String] = [
// App
        "ClearSpend": "ClearSpend",
        "Track spending, reach goals": "支出を管理して目標を達成",
        "Sign In with Base44": "Base44でサインイン",
        "You'll be redirected to Base44 to sign in securely.": "安全にサインインするためBase44にリダイレクトされます。",
        "Continue as Guest": "ゲストとして続ける",
        "Guest Mode": "ゲストモード",
        "Sign in to save your data and unlock all features.": "サインインしてデータを保存し、すべての機能を解放しましょう。",
        "Active Subscriptions": "アクティブなサブスク",
        "found": "件見つかりました",
        "Yearly": "年間",
        "Detected on this device": "このデバイスで検出",
        "Expired": "期限切れ",
        "No App Store subscriptions found": "App Storeサブスクリプションが見つかりません",
        "Active subscriptions purchased through Apple will appear here automatically.": "Appleを通じて購入したアクティブなサブスクリプションが自動的に表示されます。",
        "Scan for Subscriptions": "サブスクリプションをスキャン",
        "ClearSpend can detect your active App Store subscriptions and track them automatically.": "ClearSpendはアクティブなApp Storeサブスクリプションを検出し、自動的に追跡します。",
        "Scan Now": "今すぐスキャン",
        "Scanning subscriptions...": "サブスクリプションをスキャン中...",
        "Subscription Tracker": "サブスクリプション管理",
        "Create Account or Sign In": "アカウント作成 / サインイン",
        "Account Required": "アカウントが必要です",
        "Upgrading to Pro requires an account. Create one or sign in to continue.": "Proへのアップグレードにはアカウントが必要です。アカウントを作成するかサインインしてください。",
        "To upgrade to ClearSpend Pro, you need an account. Your data will be saved and synced across devices.": "ClearSpend Proにアップグレードするにはアカウントが必要です。データは保存され、デバイス間で同期されます。",
        "Log In": "ログイン",

        // Onboarding
        "Already have an account? Log In": "アカウントをお持ちですか？ログイン",
        "How ClearSpend Works": "ClearSpendの使い方",
        "Help": "ヘルプ",
        "Done": "完了",
        "help_balance": "今月の収入から支出を引いた金額です。プラスなら黒字、マイナスなら赤字です。",
        "help_safe_daily": "（月収 − 固定費 − 貯金目標 − 既に使った金額）÷ 残り日数 で計算されます。この金額を超えて使うと月末までに予算が足りなくなります。",
        "help_categories": "今月の支出をカテゴリ別に分類します。どのカテゴリにお金を使いすぎているかが一目でわかります。",
        "help_ai": "AIがあなたの支出パターンを分析し、日次・週次・月次のインサイトを提供します。無料枠でお試しいただけます。",
        "help_subscriptions": "このデバイスのApp Storeサブスクリプションを自動検出し、月額・年額の合計を表示します。",
        "Welcome to ClearSpend": "ClearSpendへようこそ",
        "Track your spending, build healthy budgets, and reach your financial goals.": "支出を管理し、健全な予算を立て、目標を達成しましょう。",
        "Back": "戻る",
        "Next": "次へ",
        "Get Started": "始める",
        "Please enter a valid monthly income": "有効な月収を入力してください",
        "Preferences": "設定",
        "Appearance": "デザイン",
        "Color Mode": "カラーモード",
        "Font": "フォント",
        "Region": "地域",
        "Currency": "通貨",
        "Your Budget": "あなたの予算",
        "After tax": "税引後",
        "Essential Bills": "固定費",
        "Rent, utilities, etc.": "家賃、光熱費など",
        "Savings Goal": "貯金目標",
        "Monthly target": "月間目標",
        "Pay Day": "給料日",

        // Dashboard
        "Hello, ": "こんにちは、",
        "Monthly Income": "月収",
        "Good morning, ": "おはようございます、",
        "Good evening, ": "こんばんは、",
        "there": "ゲスト",
        "Safe to Spend Today": "今日使える金額",
        "Spent": "支出",
        "Income": "収入",
        "Balance": "残高",
        "Top Categories": "カテゴリ別",
        "No spending this month": "今月の支出はありません",
        "Recent Activity": "最近の取引",
        "View All": "すべて見る",
        "No transactions yet": "まだ取引がありません",
        "d left": "日残り",
        "% used": "%使用",
        "% of budget used": "予算の%使用",

        // Activity
        "Activity": "取引",
        "Search transactions": "取引を検索",
        "Filter": "フィルター",
        "No Transactions": "取引なし",
        "No Results": "結果なし",
        "Generate Test Data": "テストデータを生成",
        "Add your first transaction": "最初の取引を追加しましょう",
        "Try a different search": "別のキーワードで検索",

        // Goals
        "Goals": "目標",
        "No Goals Yet": "まだ目標がありません",
        "Set savings goals to track your progress": "貯金目標を設定して進捗を管理しましょう",
        "% complete": "%達成",
        "Goal Details": "目標詳細",
        "Name": "名前",
        "Target Amount": "目標金額",
        "Current Amount": "現在の金額",
        "Frequency": "頻度",
        "Weekly": "毎週",
        "Biweekly": "隔週",
        "Monthly": "毎月",
        "New Goal": "新しい目標",
        "Add Goal": "目標を追加",

        // Budget Health
        "Budget Health": "予算の健全性",
        "Monthly Disposable": "月間自由支出",
        "Spending by Category": "カテゴリ別支出",
        "No spending data this month": "今月の支出データがありません",
        "Income vs Spending": "収入 vs 支出",
        "Remaining": "残り",
        "Safe Daily": "安全な1日額",
        "Days Left": "残り日数",

        // Upgrade
        "ClearSpend Pro": "ClearSpend Pro",
        "Free": "無料",
        "Pro": "Pro",
        "Get AI-powered insights, receipt scanning, voice input, and more.": "AI分析、レシートスキャン、音声入力をご利用いただけます。",
        "Plan": "プラン",
        "Yearly (save 40%)": "年間（40%割引）",
        "Processing...": "処理中...",
        "Subscribe": "購読する",
        "Restore Purchases": "購入を復元",
        "More AI Analyses": "より多くのAI分析",
        "30 daily, 15 weekly, 10 monthly, and 3 forecasts every month": "毎月30回のデイリー、15回のウィークリー、10回のマンスリー、3回の予測",
        "Custom Categories": "カスタムカテゴリ",
        "Create your own spending and income categories": "自分だけの支出・収入カテゴリを作成",
        "Spending Forecasts": "支出予測",
        "AI predicts next month's spending based on your history": "過去のデータからAIが来月の支出を予測",
        "Forecast": "予測",
        "Spending Forecast": "支出予測",
        "Weekly Trend": "週間トレンド",
        "Next Month": "来月",
        "Monthly Limit Reached": "月間制限に達しました",
        "Please wait until the first of next month for your usage to refresh.": "来月1日までお待ちください。",
        "Free Uses Exhausted": "無料利用回数を使い切りました",
        "Upgrade to ClearSpend Pro for more analyses and unlimited access.": "ClearSpend Proにアップグレードして、より多くの分析と無制限のアクセスを。",
        " free left of ": "回の無料利用が残っています（全",
        " uses this month": "回/月）",
        "See AI-predicted spending for next month based on your history.": "過去の履歴に基づいてAIが予測した来月の支出を表示します。",
        "New": "新規",
        "New Category": "新しいカテゴリ",
        "Add": "追加",
        "/mo": "/月",
        "Upgrade": "アップグレード",
        "Get more AI analyses, visual charts, unlimited receipt scanning, and deeper spending insights.": "より多くのAI分析、ビジュアルチャート、無制限のレシートスキャン、より深い支出インサイトを。",
        "Visual Pie Charts": "ビジュアル円グラフ",
        "Beautiful spending breakdown charts in weekly and monthly reports": "週次・月次レポートの美しい支出内訳グラフ",
        "Unlimited Receipt Scanning": "無制限のレシートスキャン",
        "Scan as many receipts as you want, no monthly cap": "レシートを何枚でもスキャン、月間制限なし",
        "Deeper Spending Insights": "より深い支出インサイト",
        "Detailed patterns, trends, and personalized recommendations": "詳細なパターン、トレンド、パーソナライズされた提案",
        "Just $3.33/month": "月々たった$3.33",
        "AI Spending Insights": "AI支出分析",
        "Daily, weekly, and monthly analysis": "日次・週次・月次の分析",
        "Receipt Scanner": "レシートスキャン",
        "Snap receipts to log expenses instantly": "レシートを撮影して即座に記録",
        "Voice Input": "音声入力",
        "Log transactions by speaking": "話しかけるだけで取引を記録",
        "Custom Tags": "カスタムタグ",
        "Organize transactions your way": "取引を自由に整理",
        "Budget Alerts": "予算アラート",
        "Get notified when nearing limits": "予算が近づいたら通知",
        "Advanced Charts": "高度なグラフ",
        "Deeper insights into your spending": "支出をより深く分析",
        "Unable to load pricing. Please try again.": "価格を読み込めませんでした。再試行してください。",
        "No active subscription found.": "有効なサブスクリプションが見つかりません。",
        "Purchase restored! Pro features are now unlocked.": "購入が復元されました！Pro機能のロックが解除されました。",

        // Receipt Scanner
        "Scan Receipt": "レシートをスキャン",
        "Take Photo": "写真を撮る",
        "Use": "使用",
        "Take a photo of your receipt": "レシートを撮影してください",
        "We'll extract the merchant, amount, and category automatically.": "店名、金額、カテゴリを自動的に抽出します。",
        " free scans remaining this month": "今月の無料スキャン残り",
        "Choose Photo": "写真を選択",
        "Extracted Details": "抽出された情報",
        "Merchant": "店名",
        "Could not load image.": "画像を読み込めませんでした。",
        "Could not prepare image.": "画像を準備できませんでした。",
        "Uploading receipt...": "レシートをアップロード中...",
        "Extracting details...": "詳細を抽出中...",
        "Could not parse receipt. Try again.": "レシートを解析できませんでした。再試行してください。",

        // Voice Input
        "Analyze": "分析",
        "Microphone access required": "マイクのアクセス許可が必要です",
        "Enable in Settings > Privacy > Microphone": "設定 > プライバシー > マイク で許可してください",
        "Listening...": "聞いています...",
        "Tap to speak": "タップして話す",
        "Speech recognition unavailable.": "音声認識が利用できません。",
        "Audio engine failed to start.": "オーディオエンジンの起動に失敗しました。",

        // Charts / AI
        "Category Breakdown": "カテゴリ別内訳",
        "Daily Spending": "1日の支出",
        "Analysis": "分析",

        // Misc
        "Developer Mode": "開発者モード",
        "Type": "種類",
        "Budget": "予算",
        "Save": "保存",
        "Cancel": "キャンセル",
        "Delete": "削除",
        "Theme": "テーマ",
        "Saving...": "保存中...",
        "Amount": "金額",
        "0": "0",
        "Light": "ライト",
        "Dark": "ダーク",
        "System": "システム",
        "Sage": "セージ",
        "Ocean": "オーシャン",
        "Sunset": "サンセット",
        "Lavender": "ラベンダー",
        "Forest": "フォレスト",
        "Midnight": "ミッドナイト",
        "Coral": "コーラル",
        "Honey": "ハニー",
        "Plum": "プラム",
        "Mint": "ミント",
        "Sky": "スカイ",
         "Blush": "ブラッシュ",
        "Inter": "Inter",
        "Serif": "セリフ",
        "Rounded": "ラウンド",
        "Mono": "モノ",
        "Food & Dining": "食事",
        "Groceries": "食料品",
        "Transport": "交通",
        "Shopping": "ショッピング",
        "Entertainment": "エンタメ",
        "Health": "健康",
        "Bills & Utilities": "光熱費",
        "Rent / Housing": "家賃",
        "Subscriptions": "サブスク",
        "Travel": "旅行",
        "Education": "教育",
        "Gifts": "ギフト",
        "Other": "その他",
        "Salary": "給料",
        "Freelance": "フリーランス",
        "Investment": "投資",
        "Gift": "贈与",
        "All": "すべて",
        "Expense": "支出",
        "Allocation": "配分",
        "Validation failed": "入力エラー",
        "Invalid URL": "無効なURL",
        "Invalid response from server": "サーバーからの無効な応答",
        "Session expired. Please sign in again.": "セッションが切れました。もう一度サインインしてください。",
        "Resource not found": "リソースが見つかりません",
        "HTTP error": "HTTPエラー",
        "Server error": "サーバーエラー",
        "Data error": "データエラー",
        "Date,Type,Category,Amount,Note,Merchant": "日付,種類,カテゴリ,金額,メモ,店名",
        "21:00": "21:00",
        "09:00": "09:00",
        "$39.99/yr": "¥4,800/年",
        "$4.99/mo": "¥600/月",
        "10x More AI Analyses": "10倍のAI分析",
        "30 daily, 15 weekly, and 10 monthly analyses every month": "毎月30回のデイリー、15回のウィークリー、10回のマンスリー分析",
        "Sign In with Apple": "Appleでサインイン",
        "Email": "メールアドレス",
        "Password": "パスワード",
        "Sign In": "サインイン",
        "Create Account": "アカウント作成",
        "Already have an account? Sign In": "アカウントをお持ちですか？サインイン",
        "Don't have an account? Create one": "アカウントがありませんか？作成する",
        "or": "または",
        "Verify Email": "メール確認",
        "Enter the verification code sent to your email": "メールに送信された確認コードを入力してください",
        "Verification Code": "確認コード",
        "Verify & Sign In": "確認してサインイン",
        "Converting...": "変換中...",
        "Rate": "レート",
        "Refresh Exchange Rates": "為替レートを更新",
        "Network error": "ネットワークエラー",
        "Currency not supported": "サポートされていない通貨",
        "Could not fetch exchange rate.": "為替レートを取得できませんでした。",
        "Exchange rates updated": "為替レートを更新しました",
    ]

    private static let zhDict: [String: String] = [
// App
        "ClearSpend": "ClearSpend",
        "Track spending, reach goals": "追踪支出，实现目标",
        "Sign In with Base44": "通过Base44登录",
        "You'll be redirected to Base44 to sign in securely.": "您将被重定向到Base44以安全登录。",
        "Continue as Guest": "以游客身份继续",
        "Guest Mode": "游客模式",
        "Sign in to save your data and unlock all features.": "登录以保存数据并解锁所有功能。",
        "Active Subscriptions": "活跃订阅",
        "found": "个",
        "Yearly": "每年",
        "Detected on this device": "在此设备上检测到",
        "Expired": "已过期",
        "No App Store subscriptions found": "未找到App Store订阅",
        "Active subscriptions purchased through Apple will appear here automatically.": "通过Apple购买的活跃订阅将自动显示在这里。",
        "Scan for Subscriptions": "扫描订阅",
        "ClearSpend can detect your active App Store subscriptions and track them automatically.": "ClearSpend可以检测您活跃的App Store订阅并自动追踪。",
        "Scan Now": "立即扫描",
        "Scanning subscriptions...": "正在扫描订阅...",
        "Subscription Tracker": "订阅追踪",
        "Create Account or Sign In": "创建账户 / 登录",
        "Account Required": "需要账户",
        "Upgrading to Pro requires an account. Create one or sign in to continue.": "升级到Pro需要账户。请创建账户或登录以继续。",
        "To upgrade to ClearSpend Pro, you need an account. Your data will be saved and synced across devices.": "要升级到ClearSpend Pro，您需要一个账户。您的数据将被保存并在设备间同步。",
        "Log In": "登录",

        // Onboarding
        "Already have an account? Log In": "已有账户？登录",
        "How ClearSpend Works": "ClearSpend使用指南",
        "Help": "帮助",
        "Done": "完成",
        "help_balance": "本月收入减去支出。正数为盈余，负数为亏损。",
        "help_safe_daily": "计算方式：（月收入 − 固定支出 − 储蓄目标 − 已支出）÷ 剩余天数。超过此金额意味着月底前预算不足。",
        "help_categories": "按类别分类本月支出。清楚看到哪个类别超支。",
        "help_ai": "AI分析您的支出模式，提供每日、每周和每月的洞察。免费试用可用次数。",
        "help_subscriptions": "自动检测此设备上的App Store订阅，显示月度和年度总额。",
        "Welcome to ClearSpend": "欢迎使用ClearSpend",
        "Track your spending, build healthy budgets, and reach your financial goals.": "追踪支出，建立健康预算，实现财务目标。",
        "Back": "返回",
        "Next": "下一步",
        "Get Started": "开始使用",
        "Please enter a valid monthly income": "请输入有效的月收入",
        "Preferences": "偏好设置",
        "Appearance": "外观",
        "Color Mode": "颜色模式",
        "Font": "字体",
        "Region": "地区",
        "Currency": "货币",
        "Your Budget": "您的预算",
        "After tax": "税后",
        "Essential Bills": "固定支出",
        "Rent, utilities, etc.": "房租、水电等",
        "Savings Goal": "储蓄目标",
        "Monthly target": "月度目标",
        "Pay Day": "发薪日",

        // Dashboard
        "Hello, ": "你好，",
        "Monthly Income": "月收入",
        "Good morning, ": "早上好，",
        "Good evening, ": "晚上好，",
        "there": "访客",
        "Safe to Spend Today": "今日可安全支出",
        "Spent": "已支出",
        "Income": "收入",
        "Balance": "余额",
        "Top Categories": "热门类别",
        "No spending this month": "本月无支出",
        "Recent Activity": "最近交易",
        "View All": "查看全部",
        "No transactions yet": "暂无交易",
        "d left": "天剩余",
        "% used": "%已使用",
        "% of budget used": "预算使用率",

        // Activity
        "Activity": "交易",
        "Search transactions": "搜索交易",
        "Filter": "筛选",
        "No Transactions": "暂无交易",
        "No Results": "无结果",
        "Generate Test Data": "生成测试数据",
        "Add your first transaction": "添加第一笔交易",
        "Try a different search": "尝试其他搜索",

        // Goals
        "Goals": "目标",
        "No Goals Yet": "暂无目标",
        "Set savings goals to track your progress": "设定储蓄目标追踪进度",
        "% complete": "%完成",
        "Goal Details": "目标详情",
        "Name": "名称",
        "Target Amount": "目标金额",
        "Current Amount": "当前金额",
        "Frequency": "频率",
        "Weekly": "每周",
        "Biweekly": "每两周",
        "Monthly": "每月",
        "New Goal": "新建目标",
        "Add Goal": "添加目标",

        // Budget Health
        "Budget Health": "预算健康",
        "Monthly Disposable": "月度可支配",
        "Spending by Category": "分类支出",
        "No spending data this month": "本月无支出数据",
        "Income vs Spending": "收入与支出",
        "Remaining": "剩余",
        "Safe Daily": "日均可花",
        "Days Left": "剩余天数",

        // Upgrade
        "ClearSpend Pro": "ClearSpend Pro",
        "Free": "免费",
        "Pro": "Pro",
        "Get AI-powered insights, receipt scanning, voice input, and more.": "获取AI驱动的洞察、收据扫描、语音输入等功能。",
        "Plan": "计划",
        "Yearly (save 40%)": "年度（节省40%）",
        "Processing...": "处理中...",
        "Subscribe": "订阅",
        "Restore Purchases": "恢复购买",
        "More AI Analyses": "更多AI分析",
        "30 daily, 15 weekly, 10 monthly, and 3 forecasts every month": "每月30次每日、15次每周、10次每月、3次预测",
        "Custom Categories": "自定义类别",
        "Create your own spending and income categories": "创建您自己的支出和收入类别",
        "Spending Forecasts": "支出预测",
        "AI predicts next month's spending based on your history": "AI根据您的历史记录预测下月支出",
        "Forecast": "预测",
        "Spending Forecast": "支出预测",
        "Weekly Trend": "每周趋势",
        "Next Month": "下月",
        "Monthly Limit Reached": "已达月度上限",
        "Please wait until the first of next month for your usage to refresh.": "请等待下月1日刷新使用次数。",
        "Free Uses Exhausted": "免费使用次数已用完",
        "Upgrade to ClearSpend Pro for more analyses and unlimited access.": "升级到ClearSpend Pro以获取更多分析和无限访问。",
        " free left of ": "次免费剩余/共",
        " uses this month": "次每月",
        "See AI-predicted spending for next month based on your history.": "查看AI根据您的历史记录预测的下月支出。",
        "New": "新建",
        "New Category": "新类别",
        "Add": "添加",
        "/mo": "/月",
        "Upgrade": "升级",
        "Get more AI analyses, visual charts, unlimited receipt scanning, and deeper spending insights.": "获取更多AI分析、可视化图表、无限收据扫描和更深入的消费洞察。",
        "Visual Pie Charts": "可视化饼图",
        "Beautiful spending breakdown charts in weekly and monthly reports": "每周和每月报告中精美的消费分类图表",
        "Unlimited Receipt Scanning": "无限收据扫描",
        "Scan as many receipts as you want, no monthly cap": "随心扫描收据，无月度上限",
        "Deeper Spending Insights": "更深入的消费洞察",
        "Detailed patterns, trends, and personalized recommendations": "详细的消费模式、趋势和个性化建议",
        "Just $3.33/month": "每月仅$3.33",
        "AI Spending Insights": "AI消费洞察",
        "Daily, weekly, and monthly analysis": "每日、每周、每月分析",
        "Receipt Scanner": "收据扫描器",
        "Snap receipts to log expenses instantly": "拍照即可即时记录消费",
        "Voice Input": "语音输入",
        "Log transactions by speaking": "用语音记录交易",
        "Custom Tags": "自定义标签",
        "Organize transactions your way": "按您的方式整理交易",
        "Budget Alerts": "预算提醒",
        "Get notified when nearing limits": "接近限额时收到通知",
        "Advanced Charts": "高级图表",
        "Deeper insights into your spending": "更深入的消费洞察",
        "Unable to load pricing. Please try again.": "无法加载定价，请重试。",
        "No active subscription found.": "未找到有效订阅。",
        "Purchase restored! Pro features are now unlocked.": "购买已恢复！Pro功能现已解锁。",

        // Receipt Scanner
        "Scan Receipt": "扫描收据",
        "Take Photo": "拍照",
        "Use": "使用",
        "Take a photo of your receipt": "拍摄收据照片",
        "We'll extract the merchant, amount, and category automatically.": "我们将自动提取商家、金额和类别。",
        " free scans remaining this month": "本月剩余免费扫描次数",
        "Choose Photo": "选择照片",
        "Extracted Details": "提取详情",
        "Merchant": "商家",
        "Could not load image.": "无法加载图片。",
        "Could not prepare image.": "无法准备图片。",
        "Uploading receipt...": "正在上传收据...",
        "Extracting details...": "正在提取详情...",
        "Could not parse receipt. Try again.": "无法解析收据，请重试。",

        // Voice Input
        "Analyze": "分析",
        "Microphone access required": "需要麦克风权限",
        "Enable in Settings > Privacy > Microphone": "请在 设置 > 隐私 > 麦克风 中启用",
        "Listening...": "正在聆听...",
        "Tap to speak": "点击说话",
        "Speech recognition unavailable.": "语音识别不可用。",
        "Audio engine failed to start.": "音频引擎启动失败。",

        // Charts / AI
        "Category Breakdown": "类别分布",
        "Daily Spending": "每日支出",
        "Analysis": "分析",

        // Misc
        "Developer Mode": "开发者模式",
        "Type": "类型",
        "Budget": "预算",
        "Save": "保存",
        "Cancel": "取消",
        "Delete": "删除",
        "Theme": "主题",
        "Saving...": "保存中...",
        "Amount": "金额",
        "0": "0",
        "Light": "浅色",
        "Dark": "深色",
        "System": "跟随系统",
        "Sage": "鼠尾草",
        "Ocean": "海洋",
        "Sunset": "日落",
        "Lavender": "薰衣草",
        "Forest": "森林",
        "Midnight": "午夜",
        "Coral": "珊瑚",
        "Honey": "蜂蜜",
        "Plum": "梅子",
        "Mint": "薄荷",
        "Sky": "天空",
        "Blush": "腮红",
        "Inter": "Inter",
        "Serif": "衬线体",
        "Rounded": "圆体",
        "Mono": "等宽体",
        "Food & Dining": "餐饮",
        "Groceries": "食品杂货",
        "Transport": "交通",
        "Shopping": "购物",
        "Entertainment": "娱乐",
        "Health": "健康",
        "Bills & Utilities": "账单与水电",
        "Rent / Housing": "房租",
        "Subscriptions": "订阅",
        "Travel": "旅行",
        "Education": "教育",
        "Gifts": "礼物",
        "Other": "其他",
        "Salary": "工资",
        "Freelance": "自由职业",
        "Investment": "投资",
        "Gift": "赠与",
        "All": "全部",
        "Expense": "支出",
        "Allocation": "分配",
        "Validation failed": "输入验证失败",
        "Invalid URL": "无效URL",
        "Invalid response from server": "服务器响应无效",
        "Session expired. Please sign in again.": "会话已过期，请重新登录。",
        "Resource not found": "资源未找到",
        "HTTP error": "HTTP错误",
        "Server error": "服务器错误",
        "Data error": "数据错误",
        "Date,Type,Category,Amount,Note,Merchant": "日期,类型,类别,金额,备注,商家",
        "21:00": "21:00",
        "09:00": "09:00",
        "$39.99/yr": "¥258/年",
        "$4.99/mo": "¥33/月",
        "10x More AI Analyses": "10倍AI分析次数",
        "30 daily, 15 weekly, and 10 monthly analyses every month": "每月30次每日分析、15次每周回顾、10次月度洞察",
        "Sign In with Apple": "通过Apple登录",
        "Email": "邮箱",
        "Password": "密码",
        "Sign In": "登录",
        "Create Account": "创建账户",
        "Already have an account? Sign In": "已有账户？登录",
        "Don't have an account? Create one": "没有账户？创建一个",
        "or": "或",
        "Verify Email": "验证邮箱",
        "Enter the verification code sent to your email": "请输入发送到您邮箱的验证码",
        "Verification Code": "验证码",
        "Verify & Sign In": "验证并登录",
        "Converting...": "转换中...",
        "Rate": "汇率",
        "Refresh Exchange Rates": "刷新汇率",
        "Network error": "网络错误",
        "Currency not supported": "不支持的货币",
        "Could not fetch exchange rate.": "无法获取汇率。",
        "Exchange rates updated": "汇率已更新",
    ]

    private func budgetToJSON(_ b: Budget) -> AnyCodable {
        .object([
            "id": .string(b.id),
            "monthly_income": .double(b.monthlyIncome),
            "monthly_essentials": b.monthlyEssentials.map { .double($0) } ?? .null,
            "monthly_savings_goal": b.monthlySavingsGoal.map { .double($0) } ?? .null,
            "currency": b.currency.map { .string($0) } ?? .null,
            "language": b.language.map { .string($0) } ?? .null,
            "theme": b.theme.map { .string($0) } ?? .null,
            "font": b.font.map { .string($0) } ?? .null,
            "color_mode": b.colorMode.map { .string($0) } ?? .null,
            "pay_day": b.payDay.map { .int($0) } ?? .null,
        ])
    }

    func deleteAllData() async {
        // Delete server data in order (transactions first, user last)
        for tx in transactions {
            _ = try? await client.delete(entity: "Transaction", id: tx.id)
        }
        for goal in goals {
            _ = try? await client.delete(entity: "Goal", id: goal.id)
        }
        for item in analysisHistory {
            _ = try? await client.delete(entity: "AnalysisHistory", id: item.id)
        }
        for budget in budgets {
            _ = try? await client.delete(entity: "Budget", id: budget.id)
        }
        // Clear local state
        transactions = []
        budgets = []
        goals = []
        analysisHistory = []
    }

    func continueAsGuest() {
        isGuestMode = true
        isAuthenticated = true
        isLoadingAuth = false
        loadPreferencesFromDisk()
        user = User(id: "guest", email: nil, name: "Guest", isPro: false, monthlyUsage: MonthlyUsage.empty, createdDate: nil)
    }

    func finishGuestSetup() async {
        if let cached: [Budget] = await cache.load(forKey: "guest_budgets"), !cached.isEmpty {
            budgets = cached
        }
        if let cached: [Transaction] = await cache.load(forKey: "guest_transactions") {
            transactions = cached
        }
    }

    func migrateGuestDataToAccount() async {
        guard isGuestMode else { return }
        for budget in budgets where budget.id.hasPrefix("guest-") {
            let data = BudgetData(
                monthlyIncome: budget.monthlyIncome,
                monthlyEssentials: budget.monthlyEssentials,
                monthlySavingsGoal: budget.monthlySavingsGoal,
                payDay: budget.payDay,
                currency: budget.currency,
                language: budget.language,
                theme: budget.theme,
                colorMode: budget.colorMode,
                font: budget.font
            )
            if let created: Budget = try? await client.create(entity: "Budget", data: data) {
                budgets = [created]
            }
        }
        for txn in transactions where txn.id.hasPrefix("guest-") {
            let data = TransactionData(
                amount: txn.amount, type: txn.type, category: txn.category,
                note: txn.note, date: txn.date, merchant: txn.merchant,
                description: txn.description, isRecurring: txn.isRecurring, tags: txn.tags
            )
            let _: Transaction? = try? await client.create(entity: "Transaction", data: data)
        }
        isGuestMode = false
        loadLocalData()
        await cache.clear()
    }

    private func loadGuestCache() async {
        if let cached: [Budget] = await cache.load(forKey: "guest_budgets"), !cached.isEmpty {
            budgets = cached
        }
        if let cached: [Transaction] = await cache.load(forKey: "guest_transactions") {
            transactions = cached
        }
    }

    func saveGuestCache() {
        guard isGuestMode else { return }
        let currentBudgets = budgets
        let currentTxns = transactions
        Task {
            await cache.cache(currentBudgets, forKey: "guest_budgets")
            await cache.cache(currentTxns, forKey: "guest_transactions")
        }
    }

    func signOut() {
        AuthService.deleteToken()
        Task {
            await client.setToken(nil)
            await cache.clear()
        }
        prefs.removeObject(forKey: "last_user_id")
        isAuthenticated = false
        isGuestMode = false
        user = nil
        transactions = []
        budgets = []
        goals = []
        analysisHistory = []
        continueAsGuest()
    }

    // MARK: - Data Loading

    func refreshAll() async {
        // Reload from local storage only — no server calls
        loadLocalData()
        isLoadingData = false
    }

    private func loadTransactions() async {
        do {
            let data: [Transaction] = try await client.list(entity: "Transaction", sort: "-date", limit: 500)
            transactions = data
            await cache.cache(data, forKey: "\(userCachePrefix)transactions")
        } catch let fetchError {
            if let cached: [Transaction] = await cache.load(forKey: "\(userCachePrefix)transactions") {
                transactions = cached
            }
            if transactions.isEmpty { error = fetchError.localizedDescription }
        }
    }

    private func loadBudgets() async {
        do {
            let data: [Budget] = try await client.list(entity: "Budget", sort: "-created_date", limit: 1)
            budgets = data
            await cache.cache(data, forKey: "\(userCachePrefix)budgets")
            applyBudgetPreferences()
        } catch {
            if let cached: [Budget] = await cache.load(forKey: "\(userCachePrefix)budgets") {
                budgets = cached
                applyBudgetPreferences()
            }
        }
    }

    private func loadGoals() async {
        do {
            let data: [Goal] = try await client.list(entity: "Goal", sort: "-created_date", limit: 50)
            goals = data
            await cache.cache(data, forKey: "\(userCachePrefix)goals")
        } catch {
            if let cached: [Goal] = await cache.load(forKey: "\(userCachePrefix)goals") {
                goals = cached
            }
        }
    }

    private func loadAnalysisHistory() async {
        do {
            let data: [AnalysisHistory] = try await client.list(entity: "AnalysisHistory", sort: "-created_date", limit: 30)
            analysisHistory = data
            await cache.cache(data, forKey: "\(userCachePrefix)analysis_history")
        } catch {
            if let cached: [AnalysisHistory] = await cache.load(forKey: "\(userCachePrefix)analysis_history") {
                analysisHistory = cached
            }
        }
    }

    private func loadFromCache() {
        Task {
            if let cached: [Transaction] = await cache.load(forKey: "\(userCachePrefix)transactions") {
                transactions = cached
            }
            if let cached: [Budget] = await cache.load(forKey: "\(userCachePrefix)budgets") {
                budgets = cached
                applyBudgetPreferences()
            }
            if let cached: [Goal] = await cache.load(forKey: "\(userCachePrefix)goals") {
                goals = cached
            }
        }
    }

    private func applyBudgetPreferences() {
        guard let budget = currentBudget else { return }
        if let t = budget.theme, let appTheme = AppTheme(rawValue: t) { theme = appTheme }
        if let cm = budget.colorMode, let mode = AppColorMode(rawValue: cm) { colorMode = mode }
        if let f = budget.font, let appFont = AppFont(rawValue: f) { font = appFont }
        if let c = budget.currency { currency = c }
        if let l = budget.language { language = l }
    }

    // MARK: - Mutations

    func addTransaction(_ data: TransactionData) async {
        let localId = UUID().uuidString
        let txn = Transaction(
            id: localId, amount: data.amount, type: data.type,
            category: data.category, note: data.note, date: data.date,
            merchant: data.merchant, description: data.description,
            isRecurring: data.isRecurring, tags: data.tags,
            originalCurrency: data.originalCurrency,
            originalAmount: data.originalAmount,
            exchangeRate: data.exchangeRate,
            baseCurrency: data.baseCurrency
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            transactions.insert(txn, at: 0)
        }
        saveLocalData()
    }

    func refreshExchangeRates() async {
        do {
            _ = try await CurrencyRateService.shared.refreshRates(base: currency)
        } catch {
            // Silently fail; rates will be fetched on next transaction
        }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        let id = transaction.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            transactions.removeAll { $0.id == id }
        }
        if isGuestMode {
            saveGuestCache()
            return
        }
        do {
            try await client.delete(entity: "Transaction", id: id)
        } catch {
            self.error = error.localizedDescription
            saveLocalData()
        }
    }

    func updateBudget(_ data: BudgetData) async {
        guard let budget = currentBudget else { return }
        do {
            let updated: Budget = try await client.update(entity: "Budget", id: budget.id, data: data)
            if let idx = budgets.firstIndex(where: { $0.id == budget.id }) {
                budgets[idx] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addGoal(_ data: GoalData) async {
        do {
            let created: Goal = try await client.create(entity: "Goal", data: data)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                goals.append(created)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateGoalAmount(id: String, newAmount: Double) async {
        guard let idx = goals.firstIndex(where: { $0.id == id }) else { return }
        let optimistic = goals[idx]
        goals[idx] = Goal(
            id: optimistic.id, name: optimistic.name,
            targetAmount: optimistic.targetAmount,
            currentAmount: newAmount,
            targetDate: optimistic.targetDate, category: optimistic.category,
            paymentAmount: optimistic.paymentAmount, frequency: optimistic.frequency,
            startDate: optimistic.startDate,
            createdDate: optimistic.createdDate, updatedDate: optimistic.updatedDate
        )
        do {
            let data = GoalData(
                name: optimistic.name,
                targetAmount: optimistic.targetAmount,
                currentAmount: newAmount
            )
            let updated: Goal = try await client.update(entity: "Goal", id: id, data: data)
            goals[idx] = updated
        } catch {
            goals[idx] = optimistic
            self.error = error.localizedDescription
        }
    }

    func deleteGoal(_ goal: Goal) async {
        let id = goal.id
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            goals.removeAll { $0.id == id }
        }
        do {
            try await client.delete(entity: "Goal", id: id)
        } catch {
            self.error = error.localizedDescription
            saveLocalData()
        }
    }

    func deleteAnalysisHistory(_ item: AnalysisHistory) async {
        await deleteAnalysisHistoryById(item.id)
    }

    func deleteAnalysisHistoryById(_ id: String) async {
        analysisHistory.removeAll { $0.id == id }
        do {
            try await client.delete(entity: "AnalysisHistory", id: id)
        } catch {
            self.error = error.localizedDescription
            saveLocalData()
        }
    }

    var needsOnboarding: Bool {
        guard !isLoading else { return false }
        return budgets.isEmpty
    }
}

// MARK: - Apple Sign In Delegate

final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorization, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - ASWebAuthenticationSession Presentation Context

final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AuthPresentationProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        keyWindow
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        keyWindow
    }

    private var keyWindow: ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}
