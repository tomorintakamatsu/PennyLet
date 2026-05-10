import SwiftUI
import PhotosUI
import Vision
import VisionKit

struct ReceiptScannerView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var extractedAmount: Double?
    @State private var extractedCategory: String?
    @State private var extractedMerchant: String?
    @State private var error: String?
    @State private var lineItems: [ReceiptLineItem] = []
    @State private var editAmount: String = ""
    @State private var editCategory: String = ""
    @State private var editMerchant: String = ""

    struct ReceiptLineItem: Identifiable {
        let id = UUID()
        var name: String
        var price: Double
        var editName: String
        var editPrice: String
    }
    @State private var showDocumentScanner = false
    @State private var showGuestUpgradePrompt = false
    @State private var showSignInSheet = false
    @State private var signInRegisterMode = false
    @State private var navigateToUpgrade = false

    var onResult: ((amount: Double?, category: String?, merchant: String?)) -> Void = { _ in }

    private var canUseScanner: Bool {
        viewModel.canUseFeature("receipt")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !canUseScanner {
                    upgradePrompt
                } else if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if isProcessing {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(processingStep)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 20)
                    } else if let amount = extractedAmount {
                        extractedPreview(amount: amount)
                    }
                } else {
                    emptyState
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding()
            .navigationTitle(viewModel.loc("Scan Receipt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) { dismiss() }
                }
                if (extractedAmount != nil || !lineItems.isEmpty), !isProcessing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(viewModel.loc("Use")) {
                            let cat = editCategory.isEmpty ? extractedCategory : editCategory
                            let merchant = editMerchant.isEmpty ? extractedMerchant : editMerchant
                            let total = lineItems.isEmpty
                                ? (Double(editAmount.replacingOccurrences(of: ",", with: "")) ?? extractedAmount ?? 0)
                                : lineItemTotal
                            onResult((total, cat, merchant))
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task { await loadAndProcess(newValue) }
            }
            .fullScreenCover(isPresented: $showDocumentScanner) {
                DocumentScannerView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { _, newValue in
                guard let image = newValue else { return }
                Task {
                    let resized = resizeImage(image, maxDimension: 800)
                    guard let jpegData = resized.jpegData(compressionQuality: 0.6) else {
                        error = viewModel.loc("Could not prepare image.")
                        return
                    }
                    await processReceipt(imageData: jpegData)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 54))
                .foregroundStyle(viewModel.theme.primaryColor)
            Text(viewModel.loc("Take a photo of your receipt"))
                .font(.title3.weight(.semibold))
            Text(viewModel.loc("We'll extract the merchant, amount, and category automatically."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            let remaining = viewModel.remainingUses("receipt")
            if !viewModel.isPro {
                Text("\(remaining)" + viewModel.loc(" free scans remaining this month"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 12) {
                Button {
                    showDocumentScanner = true
                } label: {
                    Label(viewModel.loc("Scan Receipt"), systemImage: "doc.text.viewfinder")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(viewModel.loc("Choose Photo"), systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(viewModel.theme.primaryColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var upgradePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text(viewModel.isPro ? viewModel.usageExhaustedProTitle : viewModel.usageExhaustedFreeTitle)
                .font(.title3.weight(.semibold))
            Text(viewModel.isPro ? viewModel.usageExhaustedProMessage : viewModel.usageExhaustedFreeMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !viewModel.isPro {
                Button {
                    if viewModel.isGuestMode {
                        showGuestUpgradePrompt = true
                    } else {
                        navigateToUpgrade = true
                    }
                } label: {
                    Text(viewModel.upgradeToProLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.yellow, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxHeight: .infinity)
        .sheet(isPresented: $showGuestUpgradePrompt) {
            GuestUpgradeModal(showSignInSheet: $showSignInSheet, signInRegisterMode: $signInRegisterMode)
                .environment(viewModel)
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInView(startInRegisterMode: signInRegisterMode)
                .environment(viewModel)
        }
        .onChange(of: viewModel.isAuthenticating) { _, new in
            if !new, !viewModel.isGuestMode { showSignInSheet = false }
        }
        .sheet(isPresented: $navigateToUpgrade) {
            UpgradeView()
        }
    }

    private var lineItemTotal: Double {
        lineItems.reduce(0.0) { total, item in
            let price = Double(item.editPrice.replacingOccurrences(of: ",", with: "")) ?? item.price
            return total + (item.price > 0 ? price : 0)
        }
    }

    private func extractedPreview(amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(viewModel.theme.primaryColor)
                Text(viewModel.loc("Review & Edit"))
                    .font(.headline)
                Spacer()
                Text(viewModel.loc("Tap fields to correct"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !lineItems.isEmpty {
                // Header row
                HStack {
                    Text(viewModel.loc("Item")).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text(viewModel.loc("Price")).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                Divider()

                ForEach($lineItems) { $item in
                    HStack(spacing: 8) {
                        TextField("Item", text: $item.editName)
                            .font(.subheadline)
                        TextField("0.00", text: $item.editPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 80)
                    }
                    Divider()
                }

                // Running total
                HStack {
                    Text(viewModel.loc("Total"))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(CurrencyFormat.format(lineItemTotal, currency: viewModel.currency))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(viewModel.theme.primaryColor)
                }
                .padding(.top, 4)
            }

            // Merchant & Category
            VStack(spacing: 8) {
                HStack {
                    Text(viewModel.loc("Merchant")).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                    TextField(viewModel.loc("Merchant"), text: $editMerchant).multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(viewModel.loc("Category")).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                    TextField(viewModel.loc("Category"), text: $editCategory).multilineTextAlignment(.trailing)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .keyboardDoneButton(viewModel.loc("Done"))
    }

    private func loadAndProcess(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                error = viewModel.loc("Could not load image.")
                return
            }
            capturedImage = image
            let resized = resizeImage(image, maxDimension: 800)
            guard let jpegData = resized.jpegData(compressionQuality: 0.6) else {
                error = viewModel.loc("Could not prepare image.")
                return
            }
            await processReceipt(imageData: jpegData)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func processReceipt(imageData: Data) async {
        isProcessing = true
        error = nil

        // Step 1: OCR with Apple Vision
        processingStep = viewModel.loc("Extracting details...")
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            error = viewModel.loc("Could not prepare image.")
            isProcessing = false
            return
        }

        // Match OCR language to the user's app language to avoid mixing CJK characters
        let ocrLanguages: [String] = {
            switch viewModel.language {
            case "ja": return ["ja-JP", "en-US"]
            case "zh": return ["zh-Hans", "en-US"]
            default: return ["en-US"]
            }
        }()
        let customWords: [String] = {
            switch viewModel.language {
            case "ja": return ["税込", "税抜", "小計", "合計", "消費税", "値引", "割引", "円", "TOTAL", "TAX"]
            case "zh": return ["总价", "小计", "合计", "优惠", "折扣", "元", "TOTAL", "TAX"]
            default: return ["TOTAL", "SUBTOTAL", "TAX", "AMOUNT", "CHANGE", "DISCOUNT", "BALANCE"]
            }
        }()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ocrLanguages
        request.minimumTextHeight = 0.01
        request.customWords = customWords
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch {
            self.error = viewModel.loc("Could not parse receipt. Try again.")
            isProcessing = false
            return
        }

        guard let observations = request.results, !observations.isEmpty else {
            error = viewModel.loc("No text found. Try a clearer photo.")
            isProcessing = false
            return
        }

        // Build text preserving line-by-line receipt layout using bounding boxes
        // Tighter grouping to keep item+price pairs on the same line
        var lineGroups: [(y: Int, text: String)] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let text = candidate.string
            let y = Int(obs.boundingBox.origin.y * 1000)
            let lineKey = y / 15  // Tighter line grouping (15pt bands)
            if let idx = lineGroups.firstIndex(where: { abs($0.y - lineKey) <= 1 }) {
                lineGroups[idx].text += " " + text
            } else {
                lineGroups.append((lineKey, text))
            }
        }
        let fullText = lineGroups.sorted(by: { $0.y < $1.y }).map { "[\($0.y)] \($0.text)" }.joined(separator: "\n")
        guard !fullText.isEmpty else {
            error = viewModel.loc("No text found. Try a clearer photo.")
            isProcessing = false
            return
        }

        // Step 2: AI extraction via Base44 LLM
        processingStep = viewModel.loc("Analyzing with AI...")
        let prompt = """
        You are a receipt itemizer for Chinese (中文), Japanese (日本語), and English receipts. Extract EVERY purchased item. The text below is organized line by line exactly as it appears on the receipt.

        CRITICAL RULES:
        - Each line starts with a [position] number showing its vertical location on the receipt. Higher numbers = lower on the receipt.
        - Return items in the EXACT SAME ORDER as they appear on the receipt (top to bottom, lowest [position] first).
        - Each receipt line with a purchase has: [position] ItemName ... Price on the SAME line. Match them 1-to-1.
        - Do NOT reorder, skip, or mix items across different lines.

        JAPANESE RECEIPTS (日本語):
        - Prices often appear as "¥500" or "500円" or "500" (円 is implied)
        - Items often listed as: 商品名 ... 単価 ... 金額
        - Tax lines: 消費税, 外税, 内税
        - Discounts: 値引, 割引

        CHINESE RECEIPTS (中文):
        - Prices often appear as "¥35.00" or "35.00元" or "35.00"
        - Items often listed as: 商品名称 ... 单价 ... 金额
        - Tax: 税, 增值税
        - Discounts: 折扣, 优惠, 满减

        ENGLISH RECEIPTS:
        - Prices as "$4.50" or "4.50"
        - Tax: TAX, VAT, Service Charge
        - Discounts: DISCOUNT, SAVINGS, -5.00

        FOR EACH ITEM:
        - "name": the product description from that line
        - "price": the price from the SAME line, as a number (e.g. 4.50)
        - If the price uses 円 or ¥ or 元, just extract the number
        - Include tax as a separate item named "Tax" if shown
        - Include discounts as negative prices

        category: [food, groceries, transport, shopping, entertainment, health, bills, rent, travel, education, subscriptions, other]
        merchant: store name from receipt header

        Receipt text (line by line):
        \(String(fullText.prefix(3000)))

        Return JSON: {"items": [{"name": "...", "price": 4.50}], "category": "...", "merchant": "..."}
        """

        let schema: [String: AnyCodable] = [
            "type": "object",
            "properties": [
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "price": ["type": "number"],
                        ],
                        "required": ["name", "price"],
                    ],
                ],
                "category": ["type": "string"],
                "merchant": ["type": "string"],
            ],
            "required": ["items", "category"],
        ]

        do {
            let result = try await Base44Client.shared.invokeLLM(prompt: prompt, responseJSONSchema: schema)
            guard let jsonData = result.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                error = viewModel.loc("Could not parse receipt. Try again.")
                isProcessing = false
                return
            }

            // Parse line items
            var items: [ReceiptLineItem] = []
            if let rawItems = dict["items"] as? [[String: Any]] {
                for raw in rawItems {
                    let name = raw["name"] as? String ?? ""
                    let price = raw["price"] as? Double ?? 0
                    guard !name.isEmpty, price != 0 else { continue }
                    items.append(ReceiptLineItem(
                        name: name,
                        price: price,
                        editName: name,
                        editPrice: String(format: "%.2f", abs(price))
                    ))
                }
            }
            lineItems = items

            // Also set single-item extraction for backward compat
            extractedCategory = dict["category"] as? String
            extractedMerchant = dict["merchant"] as? String
            if items.isEmpty, let amt = dict["amount"] as? Double {
                extractedAmount = amt
                editAmount = String(format: "%.2f", amt)
            } else {
                let total = items.reduce(0.0) { $0 + $1.price }
                extractedAmount = total
                editAmount = String(format: "%.2f", total)
            }
            editCategory = extractedCategory ?? ""
            editMerchant = extractedMerchant ?? ""
            await viewModel.incrementUsage("receipt")
        } catch {
            self.error = viewModel.loc("Could not parse receipt. Try again.")
        }
        isProcessing = false
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                parent.dismiss()
                return
            }
            parent.image = scan.imageOfPage(at: 0)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}
