//
//  File.swift
//  
//
//  Created by Young Bin on 2023/06/30.
//

import SwiftUI
import Foundation
import AVFoundation

// See https://stackoverflow.com/a/78823621/7242490
class PreviewViewController: UIViewController {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLayoutSubviews() {
        previewLayer?.frame = view.frame
    }
}

struct Preview: UIViewControllerRepresentable {
    let session: AespaSession
    let gravity: AVLayerVideoGravity
    let previewLayer: AVCaptureVideoPreviewLayer
    
    init(
        of session: AespaSession,
        gravity: AVLayerVideoGravity
    ) {
        self.gravity = gravity
        self.session = session
        self.previewLayer = session.previewLayer
    }
    
    func makeUIViewController(context: Context) -> PreviewViewController {
        let viewController = PreviewViewController()
        viewController.view.backgroundColor = .clear
        viewController.previewLayer = previewLayer
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) {
        previewLayer.videoGravity = gravity
        if previewLayer.superlayer == nil {
            uiViewController.view.layer.addSublayer(previewLayer)
        }
        uiViewController.previewLayer = previewLayer
    }
    
    func dismantleUIViewController(_ uiViewController: PreviewViewController, coordinator: ()) {
        previewLayer.removeFromSuperlayer()
    }
}
