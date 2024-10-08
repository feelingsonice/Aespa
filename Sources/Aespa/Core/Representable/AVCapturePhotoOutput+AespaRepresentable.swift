//
//  AVCapturePhotoOutput+AespaRepresentable.swift
//  
//
//  Created by Young Bin on 2023/06/18.
//

import Foundation
import AVFoundation

protocol AespaPhotoOutputRepresentable {
    func capturePhoto(with: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate)
    func getConnection(with mediaType: AVMediaType, isVideoMirrored: Bool) -> AespaCaptureConnectionRepresentable?
}

extension AVCapturePhotoOutput: AespaPhotoOutputRepresentable {
    func getConnection(with mediaType: AVMediaType, isVideoMirrored: Bool) -> AespaCaptureConnectionRepresentable? {
        guard let conn = connection(with: mediaType) else {
            return nil
        }
        
        conn.isVideoMirrored = isVideoMirrored
        return conn
    }
}
