//
//  PerformanceOptimization.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI
import Combine

// MARK: - Performance Utilities

// MARK: - LazyLoading Container

struct LazyLoadingView<Content: View>: View {
    let content: Content
    let threshold: CGFloat
    @State private var isVisible = false
    
    init(threshold: CGFloat = 50, @ViewBuilder content: () -> Content) {
        self.threshold = threshold
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                content
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 100)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = true
                        }
                    }
            }
        }
        .onAppear {
            if !isVisible {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = true
                }
            }
        }
    }
}

// MARK: - Image Loading with Caching

@MainActor
class ImageCache: ObservableObject {
    static let shared = ImageCache()
    private var cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()
    
    private init() {}
    
    func getImage(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: NSString(string: key))
    }
    
    func removeImage(for key: String) {
        cache.removeObject(forKey: NSString(string: key))
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    let cacheKey: String
    
    @StateObject private var imageCache = ImageCache.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(url: URL?, placeholder: Image = Image(systemName: "photo"), cacheKey: String) {
        self.url = url
        self.placeholder = placeholder
        self.cacheKey = cacheKey
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Check cache first
        if let cachedImage = imageCache.getImage(for: cacheKey) {
            self.image = cachedImage
            return
        }
        
        guard let url = url else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        imageCache.setImage(uiImage, for: cacheKey)
                        self.image = uiImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Data Pagination

class PaginationManager<T: Identifiable>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasReachedEnd = false
    
    private let pageSize: Int
    private var currentPage = 0
    private let loadMoreCallback: (Int, Int) async throws -> [T]
    
    init(pageSize: Int = 20, loadMoreCallback: @escaping (Int, Int) async throws -> [T]) {
        self.pageSize = pageSize
        self.loadMoreCallback = loadMoreCallback
    }
    
    func loadFirstPage() async {
        currentPage = 0
        hasReachedEnd = false
        items.removeAll()
        await loadNextPage()
    }
    
    func loadNextPage() async {
        guard !isLoading && !hasReachedEnd else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let newItems = try await loadMoreCallback(currentPage, pageSize)
            await MainActor.run {
                if newItems.count < pageSize {
                    hasReachedEnd = true
                }
                items.append(contentsOf: newItems)
                currentPage += 1
            }
        } catch {
            print("Error loading page: \(error)")
        }
    }
    
    func shouldLoadMore(item: T) -> Bool {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        return itemIndex == items.count - 3 // Load when 3 items from the end
    }
}

// MARK: - Memory-Efficient List

struct OptimizedList<Item: Identifiable, ItemView: View>: View {
    let items: [Item]
    let itemView: (Item) -> ItemView
    let onLoadMore: (() -> Void)?
    
    init(
        items: [Item],
        onLoadMore: (() -> Void)? = nil,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.onLoadMore = onLoadMore
        self.itemView = itemView
    }
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                LazyLoadingView {
                    itemView(item)
                        .onAppear {
                            if let onLoadMore = onLoadMore,
                               let itemIndex = items.firstIndex(where: { $0.id == item.id }),
                               itemIndex == items.count - 3 {
                                onLoadMore()
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Performance Monitoring

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var frameTimer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime > 0 {
            let fps = 1.0 / deltaTime
            metrics.currentFPS = min(fps, 60.0)
        }
        
        lastFrameTime = currentTime
        
        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            metrics.memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
        }
    }
    
    deinit {
        frameTimer?.invalidate()
    }
}

struct PerformanceMetrics {
    var currentFPS: Double = 60.0
    var memoryUsageMB: Double = 0.0
    var isPerformanceGood: Bool {
        return currentFPS > 55.0 && memoryUsageMB < 150.0
    }
}

// MARK: - Debounced Search

class DebouncedSearch: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init(debounceTime: TimeInterval = 0.5) {
        $searchText
            .debounce(for: .seconds(debounceTime), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.debouncedSearchText = value
            }
            .store(in: &cancellables)
    }
}

// MARK: - View Extensions for Performance

extension View {
    // Lazy loading wrapper
    func lazyLoading(threshold: CGFloat = 50) -> some View {
        LazyLoadingView(threshold: threshold) {
            self
        }
    }
    
    // Performance optimization for lists
    func optimizedForList() -> some View {
        self
            .compositingGroup() // Safer than drawingGroup for hit-testing
    }
    
    // Conditional rendering based on visibility
    func visibleInRect(_ rect: CGRect, in coordinateSpace: CoordinateSpace = .global) -> some View {
        self.background(
            GeometryReader { geometry in
                let frame = geometry.frame(in: coordinateSpace)
                Color.clear
                    .preference(key: VisibilityPreferenceKey.self, value: rect.intersects(frame))
            }
        )
    }
}

// MARK: - Visibility Tracking

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - Memory Management

extension View {
    func onMemoryWarning(perform action: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
        ) { _ in
            action()
        }
    }
}

// MARK: - Caching Manager

class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    private var cache: NSCache<NSString, AnyObject>
    
    private init() {
        cache = NSCache<NSString, AnyObject>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }
    
    func getValue<T>(for key: String) -> T? {
        return cache.object(forKey: NSString(string: key)) as? T
    }
    
    func setValue<T: AnyObject>(_ value: T, for key: String) {
        cache.setObject(value, forKey: NSString(string: key))
    }
    
    func removeValue(for key: String) {
        cache.removeObject(forKey: NSString(string: key))
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
}
