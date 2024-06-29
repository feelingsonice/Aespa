//
//  AVFoundation + Extension.swift
//
//
//  Created by Young Bin on 2023/05/28.
//

import AVFoundation

extension AVCaptureDevice.Position {
    var chooseBestCamera: AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: self
        ).devices.first
    }
}

import UIKit

extension AVCapturePhoto {
    var image: UIImage? {
        guard let imageData = fileDataRepresentation() else { return nil }
        return UIImage(data: imageData)
    }
}
