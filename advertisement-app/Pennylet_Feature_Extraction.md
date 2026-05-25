# PennyLet Feature Extraction Brief

Scan date: 2026-05-14
Project folder: /Users/tomorin/ClearSpend-iOS

## Product Snapshot

PennyLet is a SwiftUI iOS money-tracking app focused on helping users understand what they can safely spend today, stay inside a monthly budget, capture transactions quickly, and generate AI-powered personal finance insights. The product combines local-first budget and transaction storage, visual dashboards, receipt scanning, subscription tracking, goals, CSV import/export, multilingual UI, customization, and a Pro subscription tier.

The clearest positioning from the codebase:

- "Track your spending, build healthy budgets, and reach your financial goals."
- "Safe to Spend Today" is the primary dashboard metric and likely the strongest marketing hook.
- The app frames budgeting around disposable monthly money: monthly income minus essentials minus savings goal.
- AI features are positioned as daily, weekly, monthly, and forecast-based spending insights.
- Data is presented as locally stored on-device during onboarding.

## App Identity And Technical Setup

- App name: PennyLet.
- Platform: iOS app.
- UI framework: SwiftUI.
- Minimum iOS target: iOS 18.0.
- Swift version: Swift 6.0.
- Current marketing version: 4.0.
- Current build version: 3.
- Bundle identifier: com.clearspend.tomorin.app.
- Project generation: XcodeGen via project.yml.
- Xcode target/scheme: one application target named Pennylet internally, with PennyLet as the public display name.
- Signing: automatic signing, Apple Sign In entitlement enabled.
- URL scheme: pennylet.
- Assets:
  - App icon: 1024 x 1024 PNG.
  - App logo: 1254 x 1254 PNG.

## Primary User Journey

1. First launch loads local preferences and local data.
2. If no budget exists, the app shows onboarding.
3. Onboarding collects language, visual preferences, currency, monthly income, essential bills, savings goal, and payday.
4. Once a budget exists, the user lands in the main tabbed app.
5. The main dashboard shows how much is safe to spend today, current spending, income, balance, top categories, and recent transactions.
6. The floating plus button opens the transaction entry flow.
7. Users can analyze spending through AI tabs, review subscription costs, track savings goals, and tune settings.

## Main Navigation

The app uses six tabs:

- Home: dashboard and budget summary.
- Activity: searchable transaction list.
- Goals: savings goals and progress tracking.
- AI: daily, weekly, monthly, and Pro forecast analysis.
- Subscriptions: App Store subscription scan and monthly equivalents.
- Health: budget health charts and visual breakdowns.

Global actions:

- Floating plus button for adding transactions.
- Settings gear in tab toolbars.
- Crown button shown for non-Pro users to open upgrade flow.

## Onboarding Features

The onboarding flow has three main steps:

- Welcome / language / CSV import.
- Preferences.
- Budget setup.

Onboarding captures:

- Language: English, Japanese, Simplified Chinese.
- Theme.
- Color mode: light, dark, system.
- Font style: default/Inter, serif, rounded, mono.
- Currency.
- Monthly income.
- Essential bills.
- Savings goal.
- Payday.

Onboarding also supports CSV import to skip manual transaction entry. CSV columns include date, type, category, amount, note, merchant, original currency, original amount, and exchange rate.

Promotional angles:

- Quick setup in minutes.
- Start from scratch or import existing transactions.
- Local-first setup.
- Budgeting built around real monthly disposable money.

## Dashboard Features

The dashboard is centered around the "Safe to Spend Today" card.

Dashboard metrics:

- Safe to Spend Today.
- Days left in month.
- Percent of monthly disposable budget used.
- Spent this month.
- Income this month.
- Balance.
- Top spending categories.
- Recent activity.

Safe-to-spend formula:

Monthly disposable = monthly income - essential bills - savings goal.

Remaining = monthly disposable - spending this month.

Safe daily = remaining / days left in the month.

The dashboard also includes a help screen explaining:

- Balance.
- Safe to Spend Today.
- Top Categories.
- AI Analysis.
- Subscriptions.

Promotional angles:

- A daily spending number instead of vague budgeting.
- Know what you can spend today without doing mental math.
- See whether you are on pace before month-end.
- One-screen overview of income, spending, balance, and category pressure.

## Transaction Tracking

Transaction model supports:

- Amount.
- Expense or income.
- Category.
- Note.
- Date.
- Merchant.
- Recurring flag.
- Tags.
- Original currency.
- Original amount.
- Exchange rate.
- Base currency.

Activity screen features:

- Search by merchant, note, or category.
- Filter by all, income, or expense.
- Group transactions by date.
- Daily section totals.
- Swipe-to-delete transactions.
- Empty states for no transactions or no search results.
- Display of original foreign currency amount when available.

Transaction categories:

Expense categories:

- Food & Dining.
- Groceries.
- Transport.
- Shopping.
- Entertainment.
- Health.
- Bills & Utilities.
- Rent / Housing.
- Subscriptions.
- Travel.
- Education.
- Gifts.
- Other.

Income categories:

- Salary.
- Freelance.
- Investment.
- Gift.
- Other.

Promotional angles:

- Track income and spending in one place.
- Searchable transaction history.
- Category-based spending intelligence.
- Clean date-grouped activity feed.

## Add Transaction Flow

Manual transaction entry includes:

- Expense/income toggle.
- Large amount field.
- Currency picker.
- Live conversion preview for non-base currency entries.
- Receipt scan quick action.
- Category grid.
- Pro custom category creation.
- Note / merchant field.
- Date and time picker.
- Save action with animated styling.

Currency conversion:

- Supported currencies: USD, EUR, GBP, JPY, CAD, AUD, CHF, CNY, HKD, SGD, KRW, BRL.
- Exchange rates are fetched through frankfurter.app.
- Rates are cached in memory for one hour.
- Settings include a manual refresh exchange rates action.
- Foreign transactions preserve original currency, original amount, exchange rate, and base currency.

Promotional angles:

- Works for travelers and multi-currency spending.
- Converts foreign purchases into the user’s home currency.
- Keeps original currency visible for clarity.

## Receipt Scanning

Receipt scanning is one of the strongest feature areas.

Capture sources:

- Built-in document scanner camera flow via VisionKit.
- Photo picker for selecting an existing receipt image.

Processing pipeline:

- Image resizing and JPEG compression.
- Apple Vision OCR.
- OCR language adaptation for English, Japanese, and Simplified Chinese.
- AI extraction through legacy backend LLM endpoint.
- Structured JSON response for receipt items, category, and merchant.

Receipt extraction targets:

- Every purchased item.
- Item price.
- Tax as separate item when shown.
- Discounts as negative prices.
- Merchant.
- Category.

Receipt review UI:

- Preview captured receipt.
- Loading states: extracting details, analyzing with AI.
- Editable item names and prices.
- Running total from line items.
- Editable merchant and category.
- Use button to populate the add transaction form.

Receipt scanner usage limits:

- Free: 5 receipt scans per month.
- Pro: effectively unlimited receipt scans.

Promotional angles:

- Snap a receipt and turn it into a logged expense.
- Itemized receipt scanning, not just total extraction.
- Works with English, Japanese, and Chinese receipts.
- Review and edit before saving.
- Great for people who forget to log expenses manually.

## Voice Input

The codebase includes a VoiceInputView using Speech and AVFoundation.

Implemented capabilities:

- Microphone/speech recognition permission handling.
- Tap-to-record interface.
- Live transcription.
- AI extraction of amount, type, category, merchant, note, and date.
- Regex fallback if AI parsing fails.

Important caveat:

- I did not find VoiceInputView exposed from the current Add Transaction UI. It exists in source and localization, but the visible quick action currently shows receipt scanning only.

Promotional handling:

- Treat voice input as a planned or code-present feature unless you wire it into the UI before marketing it.

## Budget Health

Budget Health tab uses Swift Charts.

Features:

- Monthly disposable overview.
- Percent of budget used.
- Spending by category pie/donut chart.
- Top category legend with amounts.
- Income vs spending bar chart.
- Remaining money.
- Safe daily amount.
- Days left in the month.

Promotional angles:

- Visual spending health at a glance.
- See where your disposable income goes.
- Compare income, spending, and budget side by side.
- Good fit for screenshots and social clips.

## Goals

Savings goal tracking includes:

- Create goals with name, target amount, current amount, and frequency.
- Frequencies: weekly, biweekly, monthly.
- Progress percentage.
- Current vs target amount display.
- Progress bar.
- Quick-add buttons: +10, +50, +100, +500 in selected currency.
- Swipe-to-delete goals.

Promotional angles:

- Track progress toward savings goals.
- Small deposits become visible progress.
- Combine budgeting and goal momentum.

## AI Insights

AI features are organized into segmented tabs:

- Daily Analysis.
- Weekly Recap.
- Monthly Insight.
- Forecast, Pro only.

Daily Analysis:

- Uses today’s transactions.
- Compares daily spend against Safe to Spend Today.
- Identifies top category.
- Pro can include unusual transaction detection.
- Free limit: 5 per month.
- Pro limit: 30 per month.

Weekly Recap:

- Uses past 7 days and compares with prior 7 days.
- Summarizes biggest spending change.
- Identifies top category.
- Shows week-over-week comparison.
- Pro can include actionable spending tip and trend data.
- Free limit: 1 per month.
- Pro limit: 15 per month.

Monthly Insight:

- Analyzes current month against budget.
- Compares this month with last month.
- Looks at spending by category.
- Summarizes budget adherence.
- Identifies biggest category change.
- Provides a next step.
- Free limit: 0 per month.
- Pro limit: 10 per month.

Forecast:

- Pro-only.
- Predicts whether the user will stay within budget.
- Suggests a category to cut back.
- Estimates next month’s spending.
- Uses current month and up to three previous months.
- Pro limit: 3 per month.

AI display features:

- Usage badge with progress bar.
- Loading state.
- Error state.
- Clear current result.
- History section.
- Tap history item for full detail.
- Delete history item.
- Pro charts:
  - Category breakdown pie chart.
  - Weekly/trend bar chart.

Promotional angles:

- AI that uses actual spending totals rather than generic advice.
- Daily, weekly, and monthly money coaching.
- Forecast next month before it arrives.
- Turn raw transactions into personalized next steps.

## Subscription Tracker

Subscription tracking scans StoreKit transactions on the device.

Features:

- Detects active App Store subscriptions.
- Shows number of active subscriptions found.
- Groups totals by currency.
- Calculates monthly equivalent for monthly, yearly, and weekly plans.
- Shows price, billing period, renewal date, and monthly equivalent.
- Friendly name mapping for common services such as YouTube Premium, Spotify, Netflix, Disney+, Hulu, Max, Apple services, iCloud+, Amazon Prime, Tinder, Bumble, Strava, Peloton, Calm, Headspace, Duolingo, Adobe, Microsoft 365, Dropbox, Google One, Notion, Todoist, Evernote, Fantastical, and PennyLet Pro.
- Includes scan prompt, scanning state, empty state, and scan again action.

Important caveat:

- On simulator builds, subscription detection intentionally returns empty results.

Promotional angles:

- Find active App Store subscriptions in one place.
- Convert yearly subscriptions into monthly impact.
- Spot recurring spending that quietly drains the budget.

## Settings And Data Controls

Settings sections:

- Appearance.
- Budget.
- Preferences.
- Auto Analysis, Pro only.
- Data.
- Account.
- Legal.

Appearance:

- Theme picker with color swatches.
- Light, dark, or system color mode.
- Font style picker.
- Week start: Sunday or Monday.

Budget:

- Monthly income.
- Essential bills.
- Savings goal.
- Payday stepper.
- Auto-save after field changes.

Preferences:

- Currency.
- Language.

Auto Analysis, Pro only:

- Enable Auto Analysis.
- Set daily analysis time.
- Set weekly analysis time.
- Set monthly analysis time.
- Help alert explaining scheduled insight generation.

Important caveat:

- Settings for auto analysis are present, but I did not find the actual background scheduling/generation implementation wired in this scan.

Data:

- Export as CSV.
- Import CSV.
- Refresh exchange rates.
- Export & Reset flow.
- Reset without export.

Legal:

- Privacy policy link.
- Apple standard EULA link.

Promotional angles:

- Export your data any time.
- Import transactions from CSV.
- Customize the app to your visual style and language.
- Local data controls for reset and portability.

## Account And Authentication

Implemented auth options:

- Continue as Guest.
- Email/password sign in.
- Email/password account creation.
- OTP email verification after registration.
- Sign in with Apple entitlement and UI.

Storage:

- Auth token stored in Keychain.
- Guest user object used for guest mode.
- App starts local-first and does not require sign-in to create local budget data.

Guest/Pro behavior:

- Guest mode is supported.
- Guest users are prompted to create account or sign in before upgrading to Pro.
- GuestUpgradeModal explains that upgrading requires an account and that data will be saved/synced across devices.

Promotional angles:

- Use without creating an account.
- Sign in when ready to unlock more features.
- Apple Sign In support.

## Privacy And Permissions

Declared permissions:

- Camera: used to scan receipts.
- Microphone: used for voice input.
- Speech Recognition: used to transcribe voice input.
- Notifications: requested at launch for push/local notification support.

Privacy manifest:

- Tracking disabled.
- Tracking domains empty.
- Collected data types empty.
- Declares accessed API categories:
  - UserDefaults, reason CA92.1.
  - File timestamp, reason C617.1.
  - System boot time, reason 35F9.1.

Privacy-oriented product language found in app:

- "Your data is stored locally on this device."

Important caveat:

- The code still contains legacy backend backend and LLM calls for auth, AI, history saving, and receipt/voice parsing. If marketing says "fully offline" or "never leaves your device," that would be inaccurate.

Safer wording:

- "Designed with local-first budgeting data."
- "Use guest mode without creating an account."
- "Export your data any time."
- "AI features process spending summaries to generate insights."

## Monetization And Pro

StoreKit products:

- PennyLet Pro Monthly.
- Product ID: clearspend_pro_monthly_3.
- Auto-renewable monthly subscription.
- PennyLet Pro Yearly.
- Product ID: clearspend_pro_yearly_3.
- Auto-renewable yearly subscription.
- Subscription group: PennyLet Pro / D33B4606.

Upgrade page messaging:

- "PennyLet Pro."
- "Get more AI analyses, visual charts, unlimited receipt scanning, and deeper spending insights."
- Yearly plan badge: "Save 40%."

Pro feature list:

- More AI analyses.
- Custom categories.
- Spending forecasts.
- Auto Analysis.
- Visual pie charts.
- Unlimited receipt scanning.
- Deeper spending insights.

Free vs Pro comparison from app:

- Daily Analysis: Free 5/mo, Pro 30/mo.
- Weekly Recap: Free 1/mo, Pro 15/mo.
- Monthly Insight: Free none, Pro 10/mo.
- Spending Forecasts: Free none, Pro 3/mo.
- Receipt scanning: Free 5/mo, Pro unlimited.
- Subscription Tracker: Free included, Pro included.
- Auto Analysis: Pro only.
- Custom Categories: Pro only.
- Visual Pie Charts: Pro only.

Purchase handling:

- StoreKit 2 product loading.
- Direct purchase flow.
- Restore purchases.
- Pro status stored locally in UserDefaults after purchase/restore.
- RevenueCatService exists but is a stub; actual purchase UI uses StoreKit directly.

## Localization And Internationalization

Languages:

- English.
- Japanese.
- Simplified Chinese.

Localized areas:

- Main tab labels.
- Onboarding.
- Dashboard.
- Activity.
- Goals.
- Budget Health.
- Upgrade.
- Receipt scanner.
- Voice input.
- AI.
- Settings.
- Errors.

There are about 443 localization key entries in the standalone LocalizationStrings file, plus additional dictionaries embedded in AppViewModel.

Internationalization features:

- Currency selection.
- Locale-aware date display.
- Locale-aware currency formatting.
- OCR language selection for receipts: English, Japanese, Simplified Chinese.

Promotional angles:

- Built for multilingual users.
- Useful for users spending across currencies.
- Receipt scanning tuned for English, Japanese, and Chinese receipts.

## Visual Design And Personalization

Themes:

- Sage.
- Ocean.
- Sunset.
- Lavender.
- Forest.
- Midnight.
- Coral.
- Honey.
- Plum.
- Mint.
- Sky.
- Blush.

Color modes:

- Light.
- Dark.
- System.

Font styles:

- Default/Inter.
- Serif.
- Rounded.
- Mono.

UI style:

- SwiftUI materials.
- Rounded cards.
- SF Symbols.
- Animated tab changes and card entrances.
- Numeric text transitions for budget values.
- Shimmer skeleton views exist.

Promotional angles:

- Personalizable look and feel.
- Modern, calm financial dashboard.
- Clear visual language for budget health.

## Backend And AI Infrastructure

legacy backend API constants:

- App ID: 69fade1d8bd803e56de0b85a.
- Base URL: https://removed-legacy-backend.example/api/apps/{appId}.

legacy backendClient supports:

- Entity CRUD.
- Login.
- Registration.
- OTP verification.
- Resend OTP.
- Current user fetch.
- User update.
- LLM invocation.
- File upload.
- Function invocation.

Where AI/backend is used:

- Daily, weekly, monthly, forecast insight generation.
- Saving analysis history.
- Receipt item extraction.
- Voice transaction extraction.
- Some legacy/server paths for budgets, transactions, goals, history.

Current local-first behavior:

- Launch loads local preferences and local budget/transaction/goal data.
- Add transaction writes locally.
- Settings update budget locally.
- CSV import/export operates locally.

Important caveat:

- Some mutation paths still call legacy backend, such as addCustomCategory, addGoal, updateGoalAmount, deleteGoal, deleteAnalysisHistory, AI history creation. This suggests the app is mid-transition between server-backed and local-first behavior.

## App Store / Compliance Notes

Project-level usage descriptions:

- Camera usage: PennyLet uses your camera to scan receipts.
- Microphone usage: PennyLet uses your microphone for voice input.
- Speech recognition usage: PennyLet uses speech recognition to transcribe your voice input.
- Non-exempt encryption: NO.

Entitlements:

- Sign in with Apple.

Legal links:

- Privacy Policy: https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
- Terms: Apple standard EULA.

## Strongest Marketing Claims To Use

These appear well-supported by code:

- Know how much you can safely spend today.
- Track spending, income, balance, and budget health.
- Build a monthly budget around income, essentials, and savings.
- Scan receipts and review itemized expenses before saving.
- Search and filter your transaction history.
- Import and export CSV data.
- Track savings goals with visual progress.
- See category breakdowns and income-vs-spending charts.
- Generate AI-powered daily, weekly, monthly, and forecast insights.
- Detect App Store subscriptions and see their monthly cost.
- Track spending in multiple currencies.
- Use English, Japanese, or Simplified Chinese.
- Customize themes, color mode, and font style.
- Use guest mode without immediate account creation.
- Upgrade to Pro for more AI, forecasts, custom categories, visual charts, and unlimited receipt scanning.

## Claims To Avoid Or Phrase Carefully

Avoid:

- "Fully offline" because AI, auth, receipt extraction, and some data/history paths call legacy backend.
- "No data ever leaves your device" because AI features call backend LLM endpoints.
- "Automatic AI analysis runs in the background" unless scheduling is wired before launch.
- "Voice input is available" unless VoiceInputView is exposed in the UI.
- "All data syncs across devices" without verifying server sync paths are active for the current local-first flow.

Safer:

- "Local-first budgeting data."
- "Optional account features."
- "AI-powered insights when you choose to generate them."
- "Receipt scanning uses OCR and AI extraction."
- "Export your data anytime."

## Promotional Content Buckets For Later

Good App Store subtitle directions:

- Daily spending clarity.
- AI budget insights.
- Receipt scanner and budget tracker.
- Safe-to-spend money tracker.

Good screenshot themes:

- "Know what you can spend today."
- "See where your money goes."
- "Scan receipts in seconds."
- "AI insights from real spending."
- "Track goals and subscriptions."
- "Export, import, and stay in control."

Good short-form video angles:

- Start with the Safe to Spend Today card.
- Add a receipt by scanning.
- Show AI weekly recap.
- Show subscription scan exposing monthly costs.
- Show goal progress increasing with quick-add.
- Show multi-currency conversion while traveling.

Good landing-page sections:

- Hero: Safe to Spend Today.
- Capture: manual entry, receipt scanning, CSV import.
- Understand: dashboard, charts, AI insights.
- Control: goals, subscriptions, export/reset.
- Personalize: themes, currencies, languages.
- Upgrade: Pro comparison.
