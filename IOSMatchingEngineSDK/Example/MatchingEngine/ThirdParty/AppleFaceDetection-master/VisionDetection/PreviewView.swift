//
//  PreviewView.swift
//  VisionDetection
//
//  Created by Wei Chieh Tseng on 09/06/2017.
//  Copyright © 2017 Willjay. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

//var lastFaceRect = CGRect(0,0,0,0)

class PreviewView: UIView
{
    private var maskLayerMexCloud = [CAShapeLayer]()    // face box
    private var maskLayerMexEdge = [CAShapeLayer]()
    private var maskLayer = [CAShapeLayer]()

    // MARK: AV capture properties

    var videoPreviewLayer: AVCaptureVideoPreviewLayer
    {
        return layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession?
    {
        get
        {
            return videoPreviewLayer.session
        }

        set
        {
            videoPreviewLayer.session = newValue
        }
    }

    override class var layerClass: AnyClass
    {
        return AVCaptureVideoPreviewLayer.self
    }

    // Create a new layer drawing the bounding box
    private func createLayer(in rect: CGRect) -> CAShapeLayer
    {
        let mask = CAShapeLayer()
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = UIColor.yellow.cgColor
        mask.borderWidth = 2.0

        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 1)

        return mask
    }
    
    private func createLayer(in rect: CGRect, color: CGColor) -> CAShapeLayer
    {
       // Swift.print("createLayer \(color)")
        let mask = CAShapeLayer()
        
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = color
        mask.borderWidth = 2.0
        
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 1)
        
        return mask
    }
    
 
    private func createLayerCloud(in rect: CGRect, color: CGColor = UIColor.orange.cgColor) -> CAShapeLayer
    {
        Swift.print("createLayerCloud \(color)")

        let mask = CAShapeLayer()
        
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = color
        mask.borderWidth = 3.0
        
        maskLayerMexCloud.append(mask)
        layer.insertSublayer(mask, at: 1)
        
        return mask
    }
    
    private func createLayerEdge(in rect: CGRect, color: CGColor = UIColor.green.cgColor) -> CAShapeLayer
    {
        Swift.print("createLayerEdge \(color)")

        let mask = CAShapeLayer()
        mask.frame = rect
        mask.cornerRadius = 10
        mask.opacity = 0.75
        mask.borderColor = color
        mask.borderWidth = 3.0
        
        maskLayerMexEdge.append(mask)
        layer.insertSublayer(mask, at: 1)
        
        return mask
    }
    
    func getFaceBounds(face: VNFaceObservation) -> CGRect
    {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = face.boundingBox.applying(translate).applying(transform)

        return facebounds
    }
    
    func getFaceBounds( rect:CGRect, hint sentImageSize: CGSize) -> CGRect
    {
        let transform = CGAffineTransform(scaleX: 1, y: 1).translatedBy(x: 0, y: 0)
        
        let ratioW = frame.width   / (sentImageSize.width * 2)
        let ratioH = frame.height   / (sentImageSize.height * 2)
        
        let translate = CGAffineTransform.identity.scaledBy(x: ratioW, y: ratioH)
        
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = rect.applying(translate).applying(transform)

        return facebounds
    }
    
    func drawFaceboundingBox(face: VNFaceObservation)
    {
        let facebounds = getFaceBounds(face:face)
        
        let localProcessing = UserDefaults.standard.bool(forKey: "Local processing")
        if localProcessing == true
        {
            _ = createLayer(in: facebounds, color: UIColor.yellow.cgColor  )    // local yellow
        }
     }
    
    func drawFaceboundingBox2( rect:CGRect, hint sentImageSize: CGSize)
    {

        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = getFaceBounds( rect: rect, hint: sentImageSize)

        _ = createLayer(in: facebounds, color: UIColor.blue.cgColor  )
    }
    
    
    func drawFaceboundingBoxCloud( rect:CGRect, hint sentImageSize: CGSize)   -> CGRect
    {
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = getFaceBounds( rect: rect, hint: sentImageSize)
        
        _ = createLayerCloud(in: facebounds, color: UIColor.orange.cgColor  )    // green orange
        
        return facebounds
   }
    
    func drawFaceboundingBoxEdge( rect:CGRect, hint sentImageSize: CGSize)   -> CGRect
    {
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = getFaceBounds( rect: rect, hint: sentImageSize)

        _ = createLayerEdge(in: facebounds, color: UIColor.green.cgColor    )

        
        return facebounds
    }

    // MARK: -
    
    func drawFaceWithLandmarks(face: VNFaceObservation)
    {
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)

        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)

        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let facebounds = face.boundingBox.applying(translate).applying(transform)

        // Draw the bounding rect
        let faceLayer = createLayer(in: facebounds)

        // Draw the landmarks
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.nose)!, isClosed: false)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.noseCrest)!, isClosed: false)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.medianLine)!, isClosed: false)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.leftEye)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.leftPupil)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.leftEyebrow)!, isClosed: false)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.rightEye)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.rightPupil)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.rightEye)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.rightEyebrow)!, isClosed: false)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.innerLips)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.outerLips)!)
        drawLandmarks(on: faceLayer, faceLandmarkRegion: (face.landmarks?.faceContour)!, isClosed: false)
    }

    func drawLandmarks(on targetLayer: CALayer, faceLandmarkRegion: VNFaceLandmarkRegion2D, isClosed: Bool = true)
    {
        let rect: CGRect = targetLayer.frame
        var points: [CGPoint] = []

        for i in 0 ..< faceLandmarkRegion.pointCount
        {
            let point = faceLandmarkRegion.normalizedPoints[i]
            points.append(point)
        }

        let landmarkLayer = drawPointsOnLayer(rect: rect, landmarkPoints: points, isClosed: isClosed)

        // Change scale, coordinate systems, and mirroring
        landmarkLayer.transform = CATransform3DMakeAffineTransform(
            CGAffineTransform.identity
                .scaledBy(x: rect.width, y: -rect.height)
                .translatedBy(x: 0, y: -1)
        )

        targetLayer.insertSublayer(landmarkLayer, at: 1)
    }

    func drawPointsOnLayer(rect _: CGRect, landmarkPoints: [CGPoint], isClosed: Bool = true) -> CALayer
    {
        let linePath = UIBezierPath()
        linePath.move(to: landmarkPoints.first!)

        for point in landmarkPoints.dropFirst()
        {
            linePath.addLine(to: point)
        }

        if isClosed
        {
            linePath.addLine(to: landmarkPoints.first!)
        }

        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath.cgPath
        lineLayer.fillColor = nil
        lineLayer.opacity = 1.0
        lineLayer.strokeColor = UIColor.green.cgColor
        lineLayer.lineWidth = 0.02

        return lineLayer
    }

    func removeMask()
    {
        for mask in maskLayer
        {
            mask.removeFromSuperlayer()
        }
        maskLayer.removeAll()
    }
    
    func removeMaskLayerMexCloud()
    {
        for mask in maskLayerMexCloud
        {
            mask.removeFromSuperlayer()
        }
        maskLayerMexCloud.removeAll()
    }
    
    func removeMaskLayerMexEdge()
    {
        for mask in maskLayerMexEdge
        {
            mask.removeFromSuperlayer()
        }
        maskLayerMexEdge.removeAll()
    }
    
    
    
}
