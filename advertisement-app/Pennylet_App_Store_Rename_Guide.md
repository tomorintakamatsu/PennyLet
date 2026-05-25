# PennyLet Rename Launch Guide

Prepared on May 24, 2026.

This guide is for changing the public app name from ClearSpend to PennyLet and getting the new App Store version ready. It is written in the order you should do the work.

## Color key

> [DO FIRST] Blue means this step should happen before the other steps.

> [BLOCKER] Red means this can block App Store submission or App Review.

> [ALREADY DONE] Green means I already changed this locally in your project.

> [WARNING] Orange means do this carefully because changing it at the wrong time can break the app.

> [OPTIONAL] Purple means nice cleanup, but not required for the public rename.

## Quick answer

> [DO FIRST] Yes. Change the GitHub privacy policy link first. App Store Connect needs a working Privacy Policy URL, and the app already points to the new PennyLet privacy URL.

Use this target URL:

```text
https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
```

Your first job is to make that URL real. After it opens correctly in a private browser window, use the same URL in App Store Connect.

## Step 1: Make the PennyLet privacy policy link work

> [BLOCKER] Do not submit the new App Store version until the Privacy Policy URL works. If the link is broken, App Review can reject the version.

### What you need

- A GitHub repository named `pennylet-privacy`.
- A file named exactly `privacy-policy.pdf`.
- GitHub Pages enabled for that repository.
- This final public URL working:

```text
https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
```

### Important note about your current privacy file

I found an older privacy policy here:

```text
/Users/tomorin/ClearSpend-iOS-artifacts-20260514/privacy-policy.pdf
```

That file appears to be for ClearSpend, so do not upload it as-is unless you update the visible app name and contact details first.

### GitHub steps

1. Open GitHub in your browser.
2. Sign in to the account `tomorintakamatsu`.
3. Create a new public repository named `pennylet-privacy`, or rename your old privacy repository to `pennylet-privacy`.
4. Upload the updated file named exactly `privacy-policy.pdf` to the root of that repository.
5. Open the repository Settings.
6. Open Pages.
7. Under Build and deployment, choose Deploy from a branch.
8. Choose the branch that contains `privacy-policy.pdf`.
9. Choose the root folder if GitHub asks for a folder.
10. Click Save.
11. Wait a few minutes for GitHub Pages to publish.
12. Open this URL in a private browser window:

```text
https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
```

13. Confirm the PDF opens or downloads.
14. Keep that URL. You will paste it into App Store Connect in Step 3.

### If the URL does not work

1. Check that the repository name is exactly `pennylet-privacy`.
2. Check that the file name is exactly `privacy-policy.pdf`.
3. Check that the file is in the repository root, not inside a folder.
4. Check GitHub Settings -> Pages and confirm the page says the site is published.
5. Try the URL again in a private browser window.

## Step 2: Confirm what is already changed locally

> [ALREADY DONE] The local app, StoreKit labels, and landing page are already mostly changed to PennyLet.

These are already updated in your project:

- Xcode project: `/Users/tomorin/ClearSpend-iOS/main/Pennylet.xcodeproj`
- Xcode scheme and target: `Pennylet` internally; the public display name is `PennyLet`
- App entry file: `/Users/tomorin/ClearSpend-iOS/main/Sources/PennyletApp.swift`
- App display name: `PennyLet`
- Camera permission text: `PennyLet uses your camera to scan receipts`
- StoreKit display names: `PennyLet Pro Monthly`, `PennyLet Pro Yearly`, and `PennyLet Pro`
- Landing page name, title, meta tags, header, footer, and App Store button labels: `PennyLet`
- App privacy links in the app: the new `pennylet-privacy` URL
- Old Hostinger verification packet folders for the previous `clearspend.store` work: removed
- The `Pennylet` scheme: built successfully for iOS Simulator

## Step 3: Create a new version in App Store Connect

> [DO FIRST] Do this after the privacy policy URL works. You need a new version because App Store Connect says the app name cannot be changed on the current version.

### Before you click anything

1. Open App Store Connect:

```text
https://appstoreconnect.apple.com/
```

2. Go to Apps.
3. Open the existing app record for the current ClearSpend app.
4. Do not create a brand-new app record.
5. Check the current live version number.
6. Choose a new version number higher than the live version.

Your local project currently says:

```text
MARKETING_VERSION: "4.0"
CURRENT_PROJECT_VERSION: "3"
```

Use App Store version `4.0` only if App Store Connect has not already used `4.0` for this app. If `4.0` is already used, choose a higher version number such as `4.1` or `5.0`.

### Create the new App Store version

1. In App Store Connect, open your app.
2. In the sidebar, find the platform/version area for iOS.
3. Click the plus button next to the iOS version area.
4. Enter the new version number.
5. Click Create.
6. App Store Connect will copy some metadata from the previous version.
7. Save the new version.

### Change the public app name to PennyLet

1. Stay inside the same app record.
2. Open App Information.
3. Find Localized Information.
4. For every localization, set Name to:

```text
PennyLet
```

5. Save.
6. If you support English, Japanese, and Simplified Chinese in App Store Connect, check all three localizations.

### Paste the privacy policy URL

1. In App Information, find Privacy Policy URL.
2. Paste:

```text
https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
```

3. Save.

### Recommended App Store metadata

Use these simple fields unless you already have better copy ready:

```text
App Name: PennyLet
Subtitle: Daily Budget Tracker
Privacy Policy URL: https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
Keywords: budget,expense,spending,receipt,tracker,subscription,goals,cashflow,money
What's New: Rebranded the app to PennyLet and refreshed the app experience.
```

Use this file for longer description copy:

```text
/Users/tomorin/ClearSpend-iOS/advertisement-app/app-store-optimization.md
```

## Step 4: Update the App Store support and marketing links

> [BLOCKER] App Store links should not point to old ClearSpend pages once you submit the PennyLet version.

### Support URL

Use the page where users can contact you or request help. If you do not have a PennyLet support page yet, create one before submission.

Recommended final style:

```text
https://your-pennylet-domain.example/support
```

### Marketing URL

Use your PennyLet landing page once it is live.

Recommended final style:

```text
https://your-pennylet-domain.example/
```

### What to check

1. Open each URL in a private browser window.
2. Confirm the page says PennyLet, not ClearSpend.
3. Confirm the Privacy Policy link on the site goes to the working GitHub PDF.
4. Paste the final links into App Store Connect.
5. Save.

## Step 5: Update App Store subscriptions

> [WARNING] Change subscription display names, not product IDs.

The local StoreKit file already shows PennyLet names, but App Store Connect has its own subscription metadata.

### In App Store Connect

1. Open your app.
2. Go to Monetization.
3. Open Subscriptions.
4. Open the subscription group.
5. Set the subscription group display name to:

```text
PennyLet Pro
```

6. Open the monthly subscription.
7. In every localization, set Display Name to:

```text
PennyLet Pro Monthly
```

8. Set the monthly description to:

```text
Monthly access to all Pro features.
```

9. Open the yearly subscription.
10. In every localization, set Display Name to:

```text
PennyLet Pro Yearly
```

11. Set the yearly description to:

```text
Yearly access to all Pro features.
```

12. Save every changed subscription.
13. If App Store Connect requires review for the subscription metadata, submit it with the new app version.

### Do not change these product IDs

```text
clearspend_pro_monthly_3
clearspend_pro_yearly_3
```

Apple product IDs are internal identifiers. Customers see the display names, not these IDs.

## Step 6: Archive and upload the PennyLet build

> [WARNING] Keep the existing bundle ID for the existing App Store app.

Do not change this bundle ID:

```text
com.clearspend.tomorin.app
```

Keeping the old bundle ID is normal after a public app rename. Changing it would make Apple treat the app like a different app.

### Build steps in Xcode

1. Open this project:

```text
/Users/tomorin/ClearSpend-iOS/main/Pennylet.xcodeproj
```

2. Select the `Pennylet` scheme.
3. Set the destination to Any iOS Device or a connected real iPhone.
4. Open Signing & Capabilities.
5. Confirm your Apple Developer team is selected.
6. Confirm the bundle ID is still:

```text
com.clearspend.tomorin.app
```

7. Choose Product -> Archive.
8. Wait for the archive to finish.
9. In Organizer, select the archive.
10. Click Distribute App.
11. Choose App Store Connect.
12. Upload the archive.
13. Wait for App Store Connect to process the build.
14. Return to the new App Store version.
15. Select the processed build.
16. Complete any export compliance, encryption, age rating, and app privacy prompts.
17. Submit the version for App Review.

### If the version or build number is rejected

Edit this file:

```text
/Users/tomorin/ClearSpend-iOS/main/project.yml
```

Change:

```text
MARKETING_VERSION: "4.0"
CURRENT_PROJECT_VERSION: "3"
```

Use these rules:

- If App Store Connect says the version number was already used, increase `MARKETING_VERSION`.
- If App Store Connect says the build number was already used, increase `CURRENT_PROJECT_VERSION`.

Then regenerate the Xcode project:

```sh
cd /Users/tomorin/ClearSpend-iOS/main
xcodegen generate
open Pennylet.xcodeproj
```

## Step 7: Rename the main GitHub repository

> [DO FIRST] Do this before you share GitHub links publicly under the PennyLet name.

This is separate from the privacy policy repository.

### In GitHub

1. Open the current main app repository.
2. Go to Settings.
3. Open General.
4. Find Repository name.
5. Rename the repository to:

```text
PennyLet
```

6. Confirm the rename.

### On your Mac

After GitHub is renamed, update the local remote:

```sh
cd /Users/tomorin/ClearSpend-iOS
git remote set-url origin https://github.com/tomorintakamatsu/PennyLet.git
git remote -v
```

The expected result should show:

```text
origin  https://github.com/tomorintakamatsu/PennyLet.git (fetch)
origin  https://github.com/tomorintakamatsu/PennyLet.git (push)
```

### Check after the rename

1. Open the new GitHub repo URL in a browser.
2. Check README links.
3. Check badges.
4. Check website links.
5. Check GitHub Pages links if the repo has Pages enabled.
6. Check social links or App Store notes that mention GitHub.

## Step 8: Publish the PennyLet landing page

> [ALREADY DONE] The local landing page files already say PennyLet.

Local landing page folder:

```text
/Users/tomorin/ClearSpend-iOS/landing-page-app
```

Required files:

```text
index.html
styles.css
script.js
assets/pennylet-logo.png
```

### Hosting steps

1. Pick the final PennyLet domain.
2. Avoid using `clearspend.store` for the PennyLet brand.
3. Upload the landing page files to Hostinger, GitHub Pages, Cloudflare Pages, or your chosen host.
4. Connect the domain.
5. Wait for DNS to update.
6. Open the site in a private browser window.
7. Check desktop layout.
8. Check mobile layout.
9. Confirm the page says PennyLet everywhere.
10. Confirm the App Store button points to your App Store app.
11. Confirm the Privacy Policy link points to:

```text
https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf
```

12. Use the final site URL as the App Store Marketing URL.
13. Use a help/contact page as the App Store Support URL.

## Step 9: Leave internal identifiers alone for now

> [WARNING] These old ClearSpend strings are intentionally still present. Do not change them just because the public name changed.

Keep these unless you are doing a separate backend migration:

```text
Bundle ID: com.clearspend.tomorin.app
Product IDs: clearspend_pro_monthly_3, clearspend_pro_yearly_3
AI header: X-ClearSpend-Client
AI client ID: clearspend-ios
Cloudflare Worker name: clearspend-ai-proxy
Local folder: /Users/tomorin/ClearSpend-iOS
```

Why:

- The bundle ID keeps the app connected to the existing App Store listing.
- Product IDs are internal and should stay stable.
- The AI header and client ID must match the deployed backend.
- The local folder is not visible to users.

## Step 10: Optional backend cleanup later

> [OPTIONAL] Rename backend identifiers only after the public rename is submitted and stable.

If you decide to rename the AI backend later, update both the app and Cloudflare Worker together.

Files involved:

```text
/Users/tomorin/ClearSpend-iOS/main/server/deepseek-proxy/wrangler.jsonc
/Users/tomorin/ClearSpend-iOS/main/server/deepseek-proxy/src/index.js
/Users/tomorin/ClearSpend-iOS/main/Sources/Services/AIClient.swift
/Users/tomorin/ClearSpend-iOS/main/Sources/Utilities/Constants.swift
```

Do not change only one side. If the app and Worker disagree on the header or client ID, AI calls will fail.

## Step 11: Optional local folder rename later

> [OPTIONAL] Rename the local folder only after you finish the App Store and GitHub work.

Current local folder:

```text
/Users/tomorin/ClearSpend-iOS
```

Optional future name:

```text
/Users/tomorin/PennyLet-iOS
```

If you rename it later:

1. Close Xcode.
2. Close terminals using the old folder.
3. Rename the folder in Finder or Terminal.
4. Reopen:

```text
/Users/tomorin/PennyLet-iOS/main/Pennylet.xcodeproj
```

5. Update any personal notes that still mention the old local path.

## Final checklist before App Review

> [BLOCKER] Do not submit until every item in this checklist is true.

- The GitHub privacy PDF opens at `https://tomorintakamatsu.github.io/pennylet-privacy/privacy-policy.pdf`.
- The privacy PDF itself says PennyLet, not ClearSpend.
- App Store Connect app name says `PennyLet` for every localization.
- App Store Connect Privacy Policy URL uses the working PennyLet GitHub Pages URL.
- App Store Connect Support URL works.
- App Store Connect Marketing URL works.
- Subscription group display name says `PennyLet Pro`.
- Monthly subscription display name says `PennyLet Pro Monthly`.
- Yearly subscription display name says `PennyLet Pro Yearly`.
- The uploaded build uses the `Pennylet` scheme.
- The uploaded build still uses bundle ID `com.clearspend.tomorin.app`.
- Screenshots and preview videos do not show ClearSpend.
- Landing page says PennyLet in title, header, footer, metadata, and App Store buttons.
- GitHub public links that you plan to share use PennyLet names.
- You have tested the app build before submitting.

## Official references

- Apple: Create a new app version: `https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version/`
- Apple: App information fields: `https://developer.apple.com/help/app-store-connect/reference/app-information/`
- Apple: In-app purchase information: `https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/`
- Apple: Auto-renewable subscription information: `https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information/`
- GitHub: Renaming a repository: `https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository`
- GitHub: Configuring a publishing source for GitHub Pages: `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site`
- GitHub: Managing a custom domain for GitHub Pages: `https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site`
