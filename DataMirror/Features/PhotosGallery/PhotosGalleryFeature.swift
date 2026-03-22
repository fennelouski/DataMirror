import ComposableArchitecture
import Photos
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "PhotosGallery")

enum PhotoAccessLevel: Equatable, Sendable {
    case none_
    case limited
    case full
}

@Reducer
struct PhotosGalleryFeature {
    @ObservableState
    struct State: Equatable {
        var assets: IdentifiedArrayOf<PhotoAsset> = []
        var isLoading: Bool = false
        var accessLevel: PhotoAccessLevel = .none_
        var totalCount: Int = 0
        @Presents var detail: PhotoDetailFeature.State?
    }

    enum Action {
        case onAppear
        case assetsLoaded([PhotoAsset], Int, PhotoAccessLevel)
        case assetTapped(PhotoAsset)
        case loadMoreTapped
        case detail(PresentationAction<PhotoDetailFeature.Action>)
    }

    @Dependency(\.permissionClient) var permissionClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.assets.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let assets = await permissionClient.fetchPhotoAssets()
                    let total = assets.count
                    let accessLevel: PhotoAccessLevel
                    switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
                    case .limited: accessLevel = .limited
                    case .authorized: accessLevel = .full
                    default: accessLevel = .none_
                    }
                    await send(.assetsLoaded(assets, total, accessLevel))
                }

            case let .assetsLoaded(assets, total, level):
                state.isLoading = false
                state.assets = IdentifiedArrayOf(uniqueElements: assets)
                state.totalCount = total
                state.accessLevel = level
                return .none

            case let .assetTapped(asset):
                state.detail = PhotoDetailFeature.State(asset: asset)
                return .none

            case .loadMoreTapped:
                return .none

            case .detail:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            PhotoDetailFeature()
        }
    }
}

@Reducer
struct PhotoDetailFeature {
    @ObservableState
    struct State: Equatable {
        var asset: PhotoAsset
    }
    enum Action {
        case dismissTapped
    }
    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .dismissTapped: return .none
            }
        }
    }
}
