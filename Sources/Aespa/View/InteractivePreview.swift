//
//  InteractivePreview.swift
//  
//
//  Created by Young Bin on 2023/06/30.
//

import Combine
import SwiftUI
import AVFoundation

/// Struct that contains the options for customizing an `InteractivePreview`.
///
/// The options include enabling or disabling certain interactive features such as changing position,
/// zooming, focusing, adjusting focus mode when moved, and showing a crosshair.
public struct InteractivePreviewOption {
    /// Flag that controls whether the camera position can be changed. Default is `true`.
    public var enableChangePosition: Bool
    
    /// Flag that controls whether zoom functionality is enabled. Default is `true`.
    public var enableZoom: Bool
    
    /// Flag that controls whether focus can be manually adjusted. Default is `true`.
    public var enableFocus: Bool
    
    /// Flag that controls whether the focus mode is changed when the camera is moved. Default is `true`.
    public var enableChangeFocusModeWhenMoved: Bool
    
    /// Flag that controls whether a crosshair is displayed on the preview. Default is `true`.
    public var enableShowingCrosshair: Bool

    /// Initialize the option
    public init(
        enableChangePosition: Bool = true,
        enableZoom: Bool = true,
        enableFocus: Bool = true,
        enableChangeFocusModeWhenMoved: Bool = true,
        enableShowingCrosshair: Bool = true
    ) {
        self.enableChangePosition = enableChangePosition
        self.enableZoom = enableZoom
        self.enableFocus = enableFocus
        self.enableChangeFocusModeWhenMoved = enableChangeFocusModeWhenMoved
        self.enableShowingCrosshair = enableShowingCrosshair
    }
}

@available(iOS 17.0, *)
public struct InteractivePreview: View {
    public static let gestureState = GestureStateViewModel()
    
    @Observable
    public class GestureStateViewModel {
        public var isZooming: Bool = false
        public var isDragging: Bool = false
        
        public func reset() {
            isZooming = false
            isDragging = false
        }
    }
    
    private let option: InteractivePreviewOption
    private let preview: Preview
    
    // Used to control gesture states
    @State var gestureStateViewModel = InteractivePreview.gestureState

    // Zoom
    @State private var previousZoomFactor: CGFloat = 1.0
    @State private var currentZoomFactor: CGFloat = 1.0
    
    // Focus
    @State private var preferredFocusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    @State private var focusingLocation = CGPoint.zero

    // Crosshair
    @State private var focusFrameOpacity: Double = 0
    @State private var showingCrosshairTask: Task<Void, Error>?
    
    private var subjectAreaChangeMonitoringSubscription: Cancellable?
    
    init(_ preview: Preview, option: InteractivePreviewOption = .init()) {
        self.preview = preview
        self.option = option
        self.preferredFocusMode = preview.session.currentFocusMode ?? .continuousAutoFocus
        
        self.subjectAreaChangeMonitoringSubscription = preview
            .session
            .getSubjectAreaDidChangePublisher()
            .sink(receiveValue: { [self] _ in
                if option.enableChangeFocusModeWhenMoved {
                    self.resetFocusMode()
                }
            })
        
    }
    
    var session: AespaSession {
        preview.session
    }
    
    var layer: AVCaptureVideoPreviewLayer {
        preview.previewLayer
    }
    
    var currentFocusMode: AVCaptureDevice.FocusMode? {
        session.currentFocusMode
    }
    
    var currentCameraPosition: AVCaptureDevice.Position? {
        session.currentCameraPosition
    }
    
    public var body: some View {
        GeometryReader { geometry in
            preview
                .gesture(changePositionGesture, isEnabled: !gestureStateViewModel.isZooming && !gestureStateViewModel.isDragging)
                .gesture(pinchZoomGesture, isEnabled: !gestureStateViewModel.isDragging)
//                .gesture(tapToFocusGesture(geometry)) // Currently disabled
            .onChange(of: geometry.size) { newSize in
                DispatchQueue.main.async {
                    layer.frame = CGRect(origin: .zero, size: newSize)
                }
            }
        }
        .onDisappear {
            gestureStateViewModel.reset()
        }
    }
}

@available(iOS 17.0, *)
private extension InteractivePreview {
    var changePositionGesture: some Gesture {
        return TapGesture(count: 2).onEnded {
            let nextPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
            session.common(.position(position: nextPosition))
        }
    }
    
    func tapToFocusGesture(_ geometry: GeometryProxy) -> some Gesture {
        guard session.isRunning, option.enableFocus else {
            return DragGesture(minimumDistance: 0).onEnded { _ in }
        }
        
        return DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard
                    let currentFocusMode,
                    currentFocusMode == .locked || currentFocusMode == .continuousAutoFocus
                else {
                    return
                }
                
                var point = value.location
                point = CGPoint(
                    x: point.x / geometry.size.width,
                    y: point.y / geometry.size.height
                )
                
                session.common(.focus(mode: .autoFocus))
                focusingLocation = value.location
                
                if option.enableShowingCrosshair {
                    showCrosshair()
                }
            }
    }
    
    var pinchZoomGesture: some Gesture {
        if #available(iOS 17.0, *) {
            return MagnifyGesture(minimumScaleDelta: 0.01)
                .onChanged { [unowned session, gestureStateViewModel] (scale) in
                    gestureStateViewModel.isZooming = true
                    let maxZoomFactor = session.maxZoomFactor ?? 1.0
                    let videoZoomFactor = scale.magnification
                    let newZoomFactor = max(1.0, min(videoZoomFactor, maxZoomFactor))
                    session.common(.zoom(factor: newZoomFactor))
                }
                .onEnded { [unowned session, gestureStateViewModel] (scale) in
                    gestureStateViewModel.isZooming = false
                    let maxZoomFactor = session.maxZoomFactor ?? 1.0
                    let videoZoomFactor = scale.magnification
                    let newZoomFactor = max(1.0, min(videoZoomFactor, maxZoomFactor))
                    session.common(.zoom(factor: newZoomFactor))
                }
        } else {
            // Should not be used!
            return MagnificationGesture(minimumScaleDelta: 0.01)
                .onChanged { [unowned session, gestureStateViewModel] (scale) in
                    gestureStateViewModel.isZooming = true
                    let maxZoomFactor = session.maxZoomFactor ?? 1.0
                    let videoZoomFactor = scale * previousZoomFactor
                    if (videoZoomFactor <= maxZoomFactor) {
                        let newZoomFactor = max(1.0, min(videoZoomFactor, maxZoomFactor))
                        session.common(.zoom(factor: newZoomFactor))
                    }
                }
                .onEnded { [unowned session, gestureStateViewModel] (scale) in
                    gestureStateViewModel.isZooming = false
                    let videoZoomFactor = scale * previousZoomFactor
                    previousZoomFactor = videoZoomFactor >= 1 ? videoZoomFactor : 1
                }
        }
    }
    
    func resetFocusMode() {
        guard session.isRunning else { return }
        session.common(.focus(mode: preferredFocusMode))
    }
    
    func showCrosshair() {
        guard option.enableShowingCrosshair else { return }
        
        // Cancel the previous task
        showingCrosshairTask?.cancel()
        // Running a new task
        showingCrosshairTask = Task {
            // 10^9 nano seconds = 1 second
            let second: UInt64 = 1_000_000_000
            
            withAnimation { focusFrameOpacity = 1 }
            
            try await Task.sleep(nanoseconds: 2 * second)
            withAnimation { focusFrameOpacity = 0.35 }
            
            try await Task.sleep(nanoseconds: 3 * second)
            withAnimation { focusFrameOpacity = 0 }
        }
    }
}
