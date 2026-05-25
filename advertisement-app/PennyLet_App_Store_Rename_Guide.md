# My PennyLet App Store Rename Checklist

Fillable PDF generated May 25, 2026. The PDF version has real interactive checkbox form fields. Open it in Preview, Adobe Acrobat, or another PDF viewer that supports forms, then save after checking items.

## Paste these exact URLs

| App Store Connect field | URL |
| --- | --- |
| 技术支持网址 / Support URL | https://tomorintakamatsu.github.io/pennylet-pages/ |
| 营销网址 / Marketing URL | https://tomorintakamatsu.github.io/pennylet-pages/landing/ |
| 隐私政策网址 / Privacy Policy URL | https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf |

## Interactive progress checklist

Already completed:

- [x] Support page is live and uses f32pluspai@gmail.com.
- [x] Support page no longer has ClearSpend, Base44, account sign-in, or old cloud wording.
- [x] Marketing page is live at the landing URL.
- [x] Landing page no longer has App Store download buttons or apps.apple.com links.
- [x] Privacy policy PDF is live and says PennyLet.
- [x] Privacy policy PDF no longer has ClearSpend, Base44, cloud backend, or sign-in wording.

Still to do in App Store Connect:

- [ ] Create a new iOS version in the existing App Store app record.
- [ ] Change the app name to PennyLet in every localization.
- [ ] Paste the Support URL, Marketing URL, and Privacy Policy URL.
- [ ] Update subscription group and subscription display names to PennyLet Pro.
- [ ] Upload the PennyLet build from Xcode and attach it to the new version.
- [ ] Submit the new version for App Review.
- [ ] After the app is public, add App Store buttons back to the landing/support pages if desired.

## Important notes

- DO FIRST: The website links are already live. Paste these exact URLs into App Store Connect before submitting the new PennyLet version.
- DONE: The temporary App Store buttons were removed from the support page and landing page. Add them back only after the App Store link opens publicly.
- CAREFUL: Public name should be PennyLet with a capital L. Keep that capitalization in customer-facing text.
- DO NOT: Do not create a brand-new app record for the rename. Use the existing App Store app record and create a new version inside it.

## What is already finished

- Support page is live and shows PennyLet, local-first wording, and f32pluspai@gmail.com.
- Marketing page is live at the landing URL above. It is a normal website even though it is made with HTML on GitHub Pages.
- Privacy PDF is live and does not contain the old Base44/sign-in/cloud wording.
- Landing and support pages no longer show placeholder App Store buttons.
- Local app display name is PennyLet in the Xcode project settings.
- Local StoreKit display names say PennyLet Pro for monthly and yearly plans.
- GitHub repo links now use PennyLet names where they are public.

## The order I should follow

1. Open all three links above. If each one loads, continue. If any one fails, fix that before App Review.
2. Create a new iOS version in App Store Connect.
3. Change the app name to PennyLet in every localization. Do not delete an existing localization just because I am renaming it.
4. Paste the Support, Marketing, and Privacy Policy URLs. Save after editing each page/section if App Store Connect offers a Save button.
5. Update subscription display names and descriptions. Keep product IDs unchanged.
6. Upload the PennyLet build from Xcode. The bundle ID should stay the same so this remains the same app.
7. Attach the build, complete App Review information, and submit.
8. After the app is public, add the App Store buttons back on the landing page and support/footer if I want them.

## Step 1 - Check the three live URLs

Broken URLs can cause App Review problems. Check these in a private/incognito browser before submitting.

- Support URL: A PennyLet Support page with contact email f32pluspai@gmail.com and no Base44/account sign-in FAQ.
- Marketing URL: A PennyLet landing page. No App Store download buttons until the public App Store link works.
- Privacy URL: A PennyLet Privacy Policy PDF that opens/downloads correctly.

## Step 2 - Create a new version in App Store Connect

Apple says new versions are created inside the same app record. Apple also says to use an incremental App Store version number and upload a new build.

1. Open https://appstoreconnect.apple.com/.
2. Go to Apps and open the existing ClearSpend/PennyLet app record.
3. In the sidebar, find the iOS platform/version area.
4. Click the plus button (+) next to iOS.
5. Enter a new version number that is higher than the currently live version.
6. Click Create. App Store Connect will copy much of the old metadata into the new version.
7. Save the new version when App Store Connect gives a Save button.

Use version 4.0 only if App Store Connect has not already used 4.0 for this app. If 4.0 was used before, choose 4.1, 5.0, or another higher unused version.

Current local numbers:

```text
MARKETING_VERSION: "4.0"
CURRENT_PROJECT_VERSION: "3"
```

If App Store Connect rejects the version or build number, increase the local numbers in `/Users/tomorin/ClearSpend-iOS/main/project.yml`.

## Step 3 - Change the public app name

1. In App Store Connect, stay inside the same app record and the new iOS version.
2. Open App Information or the localization/metadata area where the app name is editable.
3. For each localization I use, set the app name to PennyLet.
4. Check English, Japanese, and Simplified Chinese if those localizations exist.
5. Do not delete the original localization unless I truly no longer support that language. For a rename, edit the existing localization instead.
6. Save.

Customer-facing name: PennyLet. The Xcode project, target, and scheme are now also named PennyLet.

## Step 4 - Paste the URL fields

Use these exact links. The protocol `https://` must be included.

- Support URL: https://tomorintakamatsu.github.io/pennylet-pages/
- Marketing URL: https://tomorintakamatsu.github.io/pennylet-pages/landing/
- Privacy Policy URL: https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf

## Step 5 - Update subscription names

Change display names and descriptions only. Do not change Product IDs, because Product IDs are already connected to purchases.

1. In App Store Connect, open Monetization or Subscriptions.
2. Open the existing subscription group.
3. Set the subscription group display name to PennyLet Pro.
4. Open the monthly product and set customer-facing display name to PennyLet Pro Monthly.
5. Open the yearly product and set customer-facing display name to PennyLet Pro Yearly.
6. Update descriptions so they say PennyLet, not ClearSpend.
7. Save every localization that App Store Connect shows.
8. If Apple asks to submit subscription metadata for review, submit it with the new app version.

Keep these product IDs unchanged:

```text
clearspend_pro_monthly_3
clearspend_pro_yearly_3
```

## Step 6 - Check App Privacy and review notes

1. Open the App Privacy section in App Store Connect.
2. Confirm the Privacy Policy URL is the PennyLet PDF URL.
3. Make sure the privacy answers match the current app: local-first app, no account required, no bank connection required, optional receipt/AI features only when used.
4. In App Review Notes, mention that the app can be used locally without an account.
5. If Pro features are tested, explain that subscriptions are handled by Apple In-App Purchase.

## Step 7 - Archive and upload the PennyLet build

Do not change the bundle ID for this rename. Keeping the bundle ID keeps this attached to the existing App Store listing.

```text
cd /Users/tomorin/ClearSpend-iOS/main
open PennyLet.xcodeproj
```

1. In Xcode, choose the PennyLet scheme.
2. Select Any iOS Device or a real connected iPhone as the destination.
3. Open Product > Archive.
4. When Organizer opens, select the new archive.
5. Click Distribute App.
6. Choose App Store Connect.
7. Upload the build.
8. Wait for App Store Connect to finish processing it.
9. Go back to the new version and select the processed build.

Public display name already set locally:

```text
INFOPLIST_KEY_CFBundleDisplayName: PennyLet
```

Internal identifiers that are intentionally still old:

```text
Bundle ID: com.clearspend.tomorin.app
AI header: X-ClearSpend-Client
Worker/client strings: clearspend-ios, clearspend-ai-proxy
Local folder: /Users/tomorin/ClearSpend-iOS
```

These are not public app-store branding. Leave them alone unless I am doing a separate technical migration later.

## Final checklist

- [ ] App name says PennyLet in every App Store Connect localization.
- [ ] Support URL is https://tomorintakamatsu.github.io/pennylet-pages/
- [ ] Marketing URL is https://tomorintakamatsu.github.io/pennylet-pages/landing/
- [ ] Privacy Policy URL is https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
- [ ] Subscription display names say PennyLet Pro.
- [ ] Product IDs are unchanged.
- [ ] Uploaded build shows PennyLet on the iPhone home screen.
- [ ] Screenshots, descriptions, keywords, and What’s New do not say ClearSpend unless explaining the rename in release notes.
- [ ] Support/landing pages do not have placeholder App Store buttons.
- [ ] App Review Notes explain there is no required account or bank sign-in.

## Recommended App Store text

| Field | Suggested value |
| --- | --- |
| App Name | PennyLet |
| Subtitle | Daily Budget Tracker |
| Keywords | budget,expense,spending,receipt,tracker,subscription,goals,cashflow,money |
| What’s New | Rebranded the app to PennyLet and refreshed the app experience. |

Short review note I can paste:

```text
PennyLet is a local-first iPhone budgeting app. Users can use the app without creating an account and without linking a bank. Pro features use Apple In-App Purchase. Receipt scanning and AI features are optional.
```

## After the app is published

1. Open the public App Store page in a browser and confirm it works for normal users.
2. If the public link works, add App Store buttons back to the landing page and support/footer if I want them.
3. Use this format: https://apps.apple.com/app/id6758940961 if that is the final public Apple app ID.
4. If App Store Connect gives a different public app ID, use the App Store Connect public link instead.
5. Update social profiles, GitHub README links, and any custom domain later. This does not require a new App Store version unless app metadata changes.

## Official Apple sources checked

- Create a new version: https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version/
- Support URL and Marketing URL definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Required/localizable/editable properties: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties
