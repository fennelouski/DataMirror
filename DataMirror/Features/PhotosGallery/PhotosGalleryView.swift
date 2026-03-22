import SwiftUI
import ComposableArchitecture
import Photos
import MapKit
import CoreLocation

struct PhotosGalleryView: View {
    @Bindable var store: StoreOf<PhotosGalleryFeature>

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView(String(localized: "Loading Photos…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        accessBanner
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(store.assets) { asset in
                                PhotoThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                                    .onTapGesture { store.send(.assetTapped(asset)) }
                                    .accessibilityLabel(String(localized: "Photo"))
                                    .accessibilityHint(String(localized: "Double tap to view details"))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Your Photos (\(store.assets.count))"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .sheet(
            item: $store.scope(state: \.detail, action: \.detail)
        ) { detailStore in
            PhotoDetailView(store: detailStore)
        }
    }

    @ViewBuilder
    private var accessBanner: some View {
        switch store.accessLevel {
        case .limited:
            DataMirrorPrivacyBanner(
                text: String(localized: "You've granted access to a limited selection. This is what apps with Limited access can see.")
            )
        case .full:
            DataMirrorPrivacyBanner(
                text: String(localized: "This is every photo any app with Full Photo access can read, including all metadata.")
            )
        case .none_:
            EmptyView()
        }
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnailView: View {
    let asset: PhotoAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color(.systemGray5))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)

            if asset.mediaType == .video {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                    Text(durationString)
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.5))
                .padding(4)
            }
        }
        .task {
            image = await loadThumbnail()
        }
    }

    private var durationString: String {
        let mins = Int(asset.duration) / 60
        let secs = Int(asset.duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func loadThumbnail() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.resizeMode = .fast
            options.deliveryMode = .fastFormat

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [asset.id], options: nil)
            guard let phAsset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }

            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: CGSize(width: 150, height: 150),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    @Bindable var store: StoreOf<PhotoDetailFeature>
    @State private var image: UIImage?
    @State private var magnification: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Photo display as first row
                Section {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(magnification)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { magnification = $0 }
                                        .onEnded { _ in
                                            withAnimation {
                                                magnification = max(1.0, min(magnification, 4.0))
                                            }
                                        }
                                )
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    DataMirrorPrivacyBanner(
                        text: String(localized: "This is what any app with Photos access can read about this image.")
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(String(localized: "Image Info")) {
                    LabeledContent(
                        String(localized: "Dimensions"),
                        value: "\(store.asset.pixelWidth) × \(store.asset.pixelHeight)"
                    )
                    LabeledContent(String(localized: "Media Type"), value: mediaTypeString)
                    LabeledContent(
                        String(localized: "Favorite"),
                        value: store.asset.isFavorite ? String(localized: "Yes") : String(localized: "No")
                    )
                }

                if hasCaptureMetadata {
                    Section(String(localized: "Capture Metadata")) {
                        if let date = store.asset.creationDate {
                            LabeledContent(
                                String(localized: "Date Taken"),
                                value: date.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                        if let make = store.asset.cameraMake {
                            LabeledContent(String(localized: "Camera Make"), value: make)
                        }
                        if let model = store.asset.cameraModel {
                            LabeledContent(String(localized: "Camera Model"), value: model)
                        }
                        if let lens = store.asset.lensModel {
                            LabeledContent(String(localized: "Lens"), value: lens)
                        }
                        if let fNumber = store.asset.fNumber {
                            LabeledContent(String(localized: "Aperture"), value: String(format: "f/%.1f", fNumber))
                        }
                        if let exposureTime = store.asset.exposureTime {
                            LabeledContent(String(localized: "Shutter Speed"), value: formatShutterSpeed(exposureTime))
                        }
                        if let iso = store.asset.isoSpeed {
                            LabeledContent(String(localized: "ISO"), value: "\(iso)")
                        }
                        if let focal = store.asset.focalLength {
                            LabeledContent(String(localized: "Focal Length"), value: String(format: "%.0f mm", focal))
                        }
                    }
                }

                if let location = store.asset.location {
                    locationSection(location)
                }

                if store.asset.burstIdentifier != nil || store.asset.modificationDate != nil {
                    Section(String(localized: "Other")) {
                        if let burst = store.asset.burstIdentifier {
                            LabeledContent(String(localized: "Burst ID"), value: burst)
                        }
                        if let modified = store.asset.modificationDate {
                            LabeledContent(
                                String(localized: "Modified"),
                                value: modified.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Photo Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "Close photo details"))
                }
            }
            .task { image = await loadFullImage() }
        }
    }

    @ViewBuilder
    private func locationSection(_ location: PhotoLocation) -> some View {
        Section(String(localized: "Location")) {
            LabeledContent(
                String(localized: "Latitude"),
                value: String(format: "%.4f°", location.latitude)
            )
            LabeledContent(
                String(localized: "Longitude"),
                value: String(format: "%.4f°", location.longitude)
            )
            if let alt = location.altitude {
                LabeledContent(String(localized: "Altitude"), value: String(format: "%.0f m", alt))
            }
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
            .allowsHitTesting(false)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(String(localized: "Map showing photo location"))

            Text(String(localized: "This photo's GPS coordinates are readable by any app with Photo access."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mediaTypeString: String {
        switch store.asset.mediaType {
        case .image: String(localized: "Photo")
        case .video: String(localized: "Video")
        case .audio: String(localized: "Audio")
        default: String(localized: "Unknown")
        }
    }

    private var hasCaptureMetadata: Bool {
        store.asset.cameraMake != nil || store.asset.cameraModel != nil
            || store.asset.fNumber != nil || store.asset.exposureTime != nil
            || store.asset.creationDate != nil
    }

    private func formatShutterSpeed(_ seconds: Double) -> String {
        if seconds >= 1 {
            return String(format: "%.1f s", seconds)
        }
        let denominator = Int(1.0 / seconds)
        return "1/\(denominator)s"
    }

    private func loadFullImage() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [store.asset.id], options: nil)
            guard let phAsset = fetchResult.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
