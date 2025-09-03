//
//  AnimationSystem.swift
//  shigodeki
//
//  Created by Claude on 2025-08-28.
//

import SwiftUI

// MARK: - Animation Presets

extension Animation {
    // Standard easing curves
    static let standardEase = Animation.easeInOut(duration: 0.3)
    static let quickEase = Animation.easeInOut(duration: 0.2)
    static let slowEase = Animation.easeInOut(duration: 0.5)
    
    // Spring animations
    static let standardSpring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    static let bouncySpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.6,
        blendDuration: 0
    )
    
    static let gentleSpring = Animation.spring(
        response: 0.6,
        dampingFraction: 0.9,
        blendDuration: 0
    )
    
    // Specialized animations
    static let cardPresentation = Animation.easeOut(duration: 0.4)
    static let cardDismiss = Animation.easeIn(duration: 0.3)
    static let listItemAppear = Animation.easeOut(duration: 0.2).delay(0.1)
}

// MARK: - Transition Presets

extension AnyTransition {
    // Card transitions
    static let cardSlideUp: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )
    
    static let cardSlideDown: AnyTransition = .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
    
    static let cardScale: AnyTransition = .asymmetric(
        insertion: .scale(scale: 0.8).combined(with: .opacity),
        removal: .scale(scale: 0.9).combined(with: .opacity)
    )
    
    // List item transitions
    static let listItemSlide: AnyTransition = .asymmetric(
        insertion: .move(edge: .leading).combined(with: .opacity),
        removal: .move(edge: .trailing).combined(with: .opacity)
    )
    
    static let listItemFade: AnyTransition = .opacity.combined(with: .scale(scale: 0.95))
}

// MARK: - Interactive Animations

struct InteractiveScaleEffect: ViewModifier {
    @Binding var isPressed: Bool
    let scale: CGFloat
    let animation: Animation
    
    init(isPressed: Binding<Bool>, scale: CGFloat = 0.98, animation: Animation = .quickEase) {
        self._isPressed = isPressed
        self.scale = scale
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(animation, value: isPressed)
    }
}

struct InteractiveOpacityEffect: ViewModifier {
    @Binding var isPressed: Bool
    let opacity: Double
    let animation: Animation
    
    init(isPressed: Binding<Bool>, opacity: Double = 0.8, animation: Animation = .quickEase) {
        self._isPressed = isPressed
        self.opacity = opacity
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? opacity : 1.0)
            .animation(animation, value: isPressed)
    }
}

// MARK: - Loading Animations

struct PulseEffect: ViewModifier {
    @State private var isAnimating = false
    let duration: Double
    let minOpacity: Double
    let maxOpacity: Double
    
    init(duration: Double = 1.0, minOpacity: Double = 0.4, maxOpacity: Double = 1.0) {
        self.duration = duration
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? minOpacity : maxOpacity)
            .animation(
                Animation.easeInOut(duration: duration).repeatForever(),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: isAnimating ? 200 : -200)
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - View Extensions

extension View {
    // Interactive effects
    func interactiveScale(isPressed: Binding<Bool>, scale: CGFloat = 0.98) -> some View {
        self.modifier(InteractiveScaleEffect(isPressed: isPressed, scale: scale))
    }
    
    func interactiveOpacity(isPressed: Binding<Bool>, opacity: Double = 0.8) -> some View {
        self.modifier(InteractiveOpacityEffect(isPressed: isPressed, opacity: opacity))
    }
    
    // Loading effects
    func pulse(duration: Double = 1.0, minOpacity: Double = 0.4) -> some View {
        self.modifier(PulseEffect(duration: duration, minOpacity: minOpacity))
    }
    
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
    
    // Animated appearance
    func animatedAppear(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .scaleEffect(0.8)
            .onAppear {
                withAnimation(.standardSpring.delay(delay)) {
                    // The animation will be handled by the state change
                }
            }
    }
    
    // Staggered list animations
    func staggeredAnimation(index: Int, total: Int) -> some View {
        let delay = Double(index) * 0.05 // 50ms delay between items
        return self
            .opacity(0)
            .offset(x: -20)
            .onAppear {
                withAnimation(.standardEase.delay(delay)) {
                    // Animation will be applied when the view appears
                }
            }
    }
}

// MARK: - Haptic Feedback Integration

struct HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func heavy() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - Animation Utilities

class AnimationStateManager: ObservableObject {
    @Published var isLoading = false
    @Published var showSuccess = false
    @Published var showError = false
    
    func showLoadingState() {
        withAnimation(.standardEase) {
            isLoading = true
        }
    }
    
    func hideLoadingState() {
        withAnimation(.standardEase) {
            isLoading = false
        }
    }
    
    func showSuccessState() {
        withAnimation(.bouncySpring) {
            showSuccess = true
            HapticFeedbackManager.shared.success()
        }
        
        // 🚨 CTO修正: 固定時間での自動消去を撤廃
        // ユーザーが意図的に操作するまで成功状態を保持し、適切なタイミングで呼び出し元が制御
        print("✅ AnimationSystem: Success state shown - manual dismissal required")
    }
    
    func showErrorState() {
        withAnimation(.standardSpring) {
            showError = true
            HapticFeedbackManager.shared.error()
        }
        
        // 🚨 CTO修正: 固定時間での自動消去を撤廃
        // ユーザーが意図的に操作するまでエラー状態を保持し、適切なタイミングで呼び出し元が制御
        print("❌ AnimationSystem: Error state shown - manual dismissal required")
    }
    
    // 🚨 CTO追加: 呼び出し元が明示的に状態を制御するためのメソッド
    func dismissSuccessState() {
        withAnimation(.standardEase) {
            showSuccess = false
        }
        print("✅ AnimationSystem: Success state manually dismissed")
    }
    
    func dismissErrorState() {
        withAnimation(.standardEase) {
            showError = false
        }
        print("❌ AnimationSystem: Error state manually dismissed")
    }
}