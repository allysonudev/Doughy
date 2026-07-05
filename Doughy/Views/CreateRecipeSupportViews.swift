//
//  CreateRecipeSupportViews.swift
//  Doughy
//

import SwiftUI
import PhotosUI
import UIKit
import NaturalLanguage
#if canImport(VisionKit)
import VisionKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Keyboard dismiss

extension View {
    func keyboardDismissible() -> some View {
        scrollDismissesKeyboard(.interactively)
    }

    func scanSourceConfirmationDialog(
        isPresented: Binding<Bool>,
        showPhotoPicker: Binding<Bool>,
        showCamera: Binding<Bool>
    ) -> some View {
        confirmationDialog("Choose Source", isPresented: isPresented, titleVisibility: .visible) {
            Button("Photo Library") {
                showPhotoPicker.wrappedValue = true
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Camera") {
                    showCamera.wrappedValue = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - ModeCard

struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    var enabled: Bool = true
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36)
                    .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .opacity(enabled ? 1.0 : 0.5)
        .modifier(OptionalAccessibilityIdentifier(id: accessibilityID))
    }
}

struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

// MARK: - Source photo PiP

struct SourcePhotoPipView: View {
    let image: UIImage
    let imageCount: Int
    @Binding var corner: SourcePhotoCorner
    let action: () -> Void

    @State var dragOffset: CGSize = .zero
    @State var keyboardHeight: CGFloat = 0
    @State var edgeAttachment: SourcePhotoEdgeAttachment?
    @State var isEdgeHidden = false

    let margin: CGFloat = 16
    let revealWidth: CGFloat = 22
    let thumbnailSize = CGSize(width: 104, height: 132)

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.85), lineWidth: 2)
                }
                .overlay(alignment: .topTrailing) {
                    if imageCount > 1 {
                        Text("\(imageCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.72), in: Capsule())
                            .padding(6)
                    }
                }
                .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(imageCount == 1
                                    ? String(localized: "source_photo.open", defaultValue: "Open source photo")
                                    : String(format: String(localized: "source_photo.open_multiple", defaultValue: "Open %d source photos"), imageCount))
                .accessibilityAddTraits(.isButton)
                .position(currentPosition(in: proxy))
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            guard !isTap(value.translation) else {
                                handleTap()
                                return
                            }

                            let base = currentPosition(in: proxy)
                            let projected = CGPoint(
                                x: base.x + value.predictedEndTranslation.width,
                                y: base.y + value.predictedEndTranslation.height
                            )
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                if let edge = hiddenEdge(for: projected, in: proxy) {
                                    edgeAttachment = SourcePhotoEdgeAttachment(
                                        edge: edge,
                                        y: clampedY(projected.y, in: proxy)
                                    )
                                    isEdgeHidden = true
                                } else if let edge = attachedEdge(for: projected, in: proxy) {
                                    edgeAttachment = SourcePhotoEdgeAttachment(
                                        edge: edge,
                                        y: clampedY(projected.y, in: proxy)
                                    )
                                    isEdgeHidden = false
                                } else {
                                    edgeAttachment = nil
                                    isEdgeHidden = false
                                    corner = nearestCorner(to: projected, in: proxy)
                                }
                                dragOffset = .zero
                            }
                        }
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: corner)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: edgeAttachment)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isEdgeHidden)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            updateKeyboardHeight(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    func currentPosition(in proxy: GeometryProxy) -> CGPoint {
        if let edgeAttachment {
            return edgePosition(
                for: edgeAttachment.edge,
                y: edgeAttachment.y,
                hidden: isEdgeHidden,
                in: proxy
            )
        }

        return position(for: corner, in: proxy)
    }

    func edgePosition(for edge: SourcePhotoHiddenEdge, y: CGFloat, hidden: Bool, in proxy: GeometryProxy) -> CGPoint {
        let x: CGFloat
        switch edge {
        case .leading:
            x = hidden ? revealWidth - thumbnailSize.width / 2 : visibleEdgeX(for: .leading, in: proxy)
        case .trailing:
            x = hidden ? proxy.size.width - revealWidth + thumbnailSize.width / 2 : visibleEdgeX(for: .trailing, in: proxy)
        }
        return CGPoint(x: x, y: clampedY(y, in: proxy))
    }

    func position(for corner: SourcePhotoCorner, in proxy: GeometryProxy) -> CGPoint {
        let x: CGFloat
        let y: CGFloat
        let bounds = verticalBounds(in: proxy)

        switch corner {
        case .topLeading, .bottomLeading:
            x = visibleEdgeX(for: .leading, in: proxy)
        case .topTrailing, .bottomTrailing:
            x = visibleEdgeX(for: .trailing, in: proxy)
        }

        switch corner {
        case .topLeading, .topTrailing:
            y = bounds.top
        case .bottomLeading, .bottomTrailing:
            y = bounds.bottom
        }

        return CGPoint(x: x, y: y)
    }

    func visibleEdgeX(for edge: SourcePhotoHiddenEdge, in proxy: GeometryProxy) -> CGFloat {
        switch edge {
        case .leading:
            return margin + thumbnailSize.width / 2
        case .trailing:
            return proxy.size.width - margin - thumbnailSize.width / 2
        }
    }

    func verticalBounds(in proxy: GeometryProxy) -> (top: CGFloat, bottom: CGFloat) {
        let top = proxy.safeAreaInsets.top + margin + thumbnailSize.height / 2
        let keyboardInset = max(proxy.safeAreaInsets.bottom, keyboardHeight)
        let bottom = max(top, proxy.size.height - keyboardInset - margin - thumbnailSize.height / 2)
        return (top, bottom)
    }

    func clampedY(_ y: CGFloat, in proxy: GeometryProxy) -> CGFloat {
        let bounds = verticalBounds(in: proxy)
        return min(max(y, bounds.top), bounds.bottom)
    }

    func hiddenEdge(for point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoHiddenEdge? {
        let dockThreshold = thumbnailSize.width * 0.35
        if point.x <= dockThreshold {
            return .leading
        }
        if point.x >= proxy.size.width - dockThreshold {
            return .trailing
        }
        return nil
    }

    func attachedEdge(for point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoHiddenEdge? {
        if let edge = edgeAttachment?.edge {
            let edgeLaneWidth = thumbnailSize.width * 0.75
            if abs(point.x - visibleEdgeX(for: edge, in: proxy)) <= edgeLaneWidth {
                return edge
            }
        }

        return nil
    }

    func nearestCorner(to point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoCorner {
        SourcePhotoCorner.allCases.min { lhs, rhs in
            distanceSquared(from: point, to: position(for: lhs, in: proxy))
                < distanceSquared(from: point, to: position(for: rhs, in: proxy))
        } ?? .topTrailing
    }

    func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    func isTap(_ translation: CGSize) -> Bool {
        abs(translation.width) < 6 && abs(translation.height) < 6
    }

    func handleTap() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = .zero
            if isEdgeHidden {
                isEdgeHidden = false
            } else {
                action()
            }
        }
    }

    func updateKeyboardHeight(from note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow
        else {
            keyboardHeight = 0
            return
        }

        let converted = window.convert(frame, from: nil)
        keyboardHeight = max(0, window.bounds.maxY - converted.minY)
    }
}

struct SourcePhotoViewer: View {
    let images: [UIImage]
    @Environment(\.dismiss) var dismiss
    @State var selectedImageIndex = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedImageIndex) {
                ForEach(images.indices, id: \.self) { index in
                    SourcePhotoLiveTextView(image: images[index])
                        .ignoresSafeArea()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            if images.count > 1 {
                Text("\(selectedImageIndex + 1) / \(images.count)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.58), in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 18)
                    .accessibilityLabel(String(
                        format: String(localized: "source_photo.page_count", defaultValue: "Source photo %d of %d"),
                        selectedImageIndex + 1,
                        images.count
                    ))
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                    .padding(18)
            }
            .accessibilityLabel(String(localized: "action.close", defaultValue: "Close"))
        }
        .statusBarHidden(true)
    }
}

struct SourcePhotoLiveTextView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> SourcePhotoViewController {
        SourcePhotoViewController(image: image)
    }

    func updateUIViewController(_ viewController: SourcePhotoViewController, context: Context) {
        viewController.setImage(image)
    }
}

final class SourcePhotoViewController: UIViewController, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let imageView = UIImageView()
    var currentImage: UIImage?
    var shouldResetZoom = true
    var lastLayoutBounds: CGSize = .zero

    #if canImport(VisionKit)
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    var analysisTask: Task<Void, Never>?
    #endif

    init(image: UIImage) {
        self.currentImage = image
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.maximumZoomScale = 5
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        #if canImport(VisionKit)
        imageView.addInteraction(interaction)
        interaction.preferredInteractionTypes = .textSelection
        #endif

        if let currentImage {
            setImage(currentImage)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        layoutImage()
    }

    func setImage(_ image: UIImage) {
        guard currentImage !== image || imageView.image == nil else { return }
        currentImage = image
        imageView.image = image
        shouldResetZoom = true
        view.setNeedsLayout()
        analyzeImage(image)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    deinit {
        #if canImport(VisionKit)
        analysisTask?.cancel()
        #endif
    }

    func layoutImage() {
        guard let image = imageView.image, scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }

        let boundsSize = scrollView.bounds.size
        let layoutBoundsChanged = lastLayoutBounds != boundsSize
        lastLayoutBounds = boundsSize

        let fittedSize = aspectFitSize(for: image.size, in: boundsSize)
        imageView.bounds = CGRect(origin: .zero, size: fittedSize)
        imageView.center = CGPoint(x: fittedSize.width / 2, y: fittedSize.height / 2)
        scrollView.contentSize = fittedSize
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5

        if shouldResetZoom || layoutBoundsChanged {
            scrollView.zoomScale = 1
            shouldResetZoom = false
        } else if scrollView.zoomScale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }

        centerImage()
    }

    func aspectFitSize(for imageSize: CGSize, in boundsSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return boundsSize }
        let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    func centerImage() {
        let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }

    func analyzeImage(_ image: UIImage) {
        #if canImport(VisionKit)
        guard ImageAnalyzer.isSupported else { return }
        analysisTask?.cancel()
        interaction.analysis = nil
        analysisTask = Task { [analyzer, interaction] in
            do {
                let analysis = try await analyzer.analyze(image, configuration: ImageAnalyzer.Configuration([.text]))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .textSelection
                }
            } catch {
                // The image remains zoomable even when Live Text analysis is unavailable.
            }
        }
        #endif
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            completion(nil)
        }
    }
}
