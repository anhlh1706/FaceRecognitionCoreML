//
//  ViewController.swift
//  FaceRecognitionCoreML
//
//  Created by Bym on 18/10/2022.
//


import UIKit
import AVKit
import ARKit
import AVFoundation
import Anchorage

final class FaceRecognitionViewController: UIViewController {
    
    // MARK: - IBOutlets
    private var sceneView: ARSCNView!
    
    private var cameraView: UIView!
    
    private var backgroundView: UIView!
    
    private var counterView: CounterView!
    
    private var visualEffectView: UIVisualEffectView!
    
    private var overlayView: UIView!
    
    private var verticalOverlayView: UIView!
    
    private var horizontalOverlayView: UIView!
    
    // MARK: - Properties
    private var photoOutput: AVCapturePhotoOutput!
    
    private var captureSession: AVCaptureSession!
    
    private var captureDevice: AVCaptureDevice?
    
    private var detects: [CounterView.DetectFace] = []
    
    private var innerCircleLayer: CAShapeLayer?
    
    private var isWaitting = true
    
    private var lastFrame: CMSampleBuffer?
    
    private lazy var previewOverlayView: UIImageView = {
        precondition(isViewLoaded)
        let previewOverlayView = UIImageView(frame: .zero)
        previewOverlayView.contentMode = .scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()

    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    let defaultRotation: Double = .pi / 2
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        setupView()
        view.backgroundColor = .black
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
//        createOverlay()
//        drawCircle()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        previewOverlayView.alpha = .leastNonzeroMagnitude
        captureSession.stopRunning()
    }
    
    func setupView() {
        sceneView = ARSCNView()
        view.addSubview(sceneView)
        sceneView.edgeAnchors == view.edgeAnchors
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        verticalOverlayView = UIView()
        view.addSubview(verticalOverlayView)
        verticalOverlayView.edgeAnchors == view.edgeAnchors + UIEdgeInsets(top: 200, left: 50, bottom: 200, right: 50)
        
        horizontalOverlayView = UIView()
        view.addSubview(horizontalOverlayView)
        horizontalOverlayView.edgeAnchors == view.edgeAnchors + UIEdgeInsets(top: 200, left: 50, bottom: 200, right: 50)
        
        
        verticalOverlayView.layer.transform = CATransform3DMakeRotation(-defaultRotation, 0, 1, 0)
        horizontalOverlayView.layer.transform = CATransform3DMakeRotation(defaultRotation, 1, 0, 0)
        
        // MARK: - Setup View's Positions
//        cameraView = UIView()
//        view.addSubview(cameraView)
//        cameraView.edgeAnchors == view.edgeAnchors + UIEdgeInsets(top: 60, left: 40, bottom: 200, right: 40)
//        cameraView.addSubview(previewOverlayView)
//        previewOverlayView.edgeAnchors == cameraView.edgeAnchors
//
//        cameraView.addSubview(annotationOverlayView)
//        annotationOverlayView.edgeAnchors == cameraView.edgeAnchors
//
//        backgroundView = UIView()
//        view.addSubview(backgroundView)
//        backgroundView.edgeAnchors == view.edgeAnchors
//
//        counterView = CounterView()
//        backgroundView.addSubview(counterView)
//        counterView.centerXAnchor == backgroundView.centerXAnchor
//        counterView.centerYAnchor == backgroundView.centerYAnchor - 80
//
//        counterView.widthAnchor == backgroundView.widthAnchor
//        counterView.heightAnchor == backgroundView.widthAnchor
//
//        visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
//
//        backgroundView.addSubview(visualEffectView)
//        visualEffectView.edgeAnchors == backgroundView.edgeAnchors
//
//        overlayView = UIView(frame: backgroundView.frame)
//
//        // MARK: - Setup View's Properties
//        counterView.layer.zPosition = 3000
//
//        visualEffectView.alpha = 0
    }
    
    // bắt đầu quét lại
    func refreshScan() {
        counterView.removeAllActiveFaces()
        detects.removeAll()
    }
    
    func okUI(point: CGPoint) {
        func deg2rad(_ number: Double) -> Double {
            return number * .pi / 180
        }
        
//        let translationX = deg2rad(max(-50, min((point.x + 20) * 2, 50))) + defaultRotation
//        let transformX = CATransform3DMakeRotation(translationX, 1, 0, 0)
        
//        print(point.y)
        let translationY = deg2rad(max(-50, min(point.y, 50))) - defaultRotation
        let transformY = CATransform3DMakeRotation(translationY, 0, 1, 0)
        
        DispatchQueue.main.async { [self] in
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: { [self] in
//                horizontalOverlayView.layer.transform = transformX
                verticalOverlayView.layer.transform = transformY
                horizontalOverlayView.layoutIfNeeded()
            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.green.withAlphaComponent(0.3).cgColor]
        gradientLayer.locations = [0.0 , 0.65, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.frame = horizontalOverlayView.bounds
        gradientLayer.cornerRadius = 150
        horizontalOverlayView.layer.insertSublayer(gradientLayer, at: 0)
        
        let gradientLayer2 = CAGradientLayer()
        gradientLayer2.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.green.withAlphaComponent(0.3).cgColor]
        gradientLayer2.locations = [0.0 , 0.65, 1]
        gradientLayer2.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer2.endPoint = CGPoint(x: 1, y: 0)
        gradientLayer2.frame = verticalOverlayView.bounds
        gradientLayer2.cornerRadius = 150
        verticalOverlayView.layer.insertSublayer(gradientLayer2, at: 0)
    }

}

extension FaceRecognitionViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = sceneView.device else { return nil }
        let faceGeometry = ARSCNFaceGeometry(device: device)
        
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
            return
        }
        faceGeometry.update(from: faceAnchor.geometry)
        let eulerAngles = faceAnchor.transform.translation
        okUI(point: CGPoint(x: CGFloat(eulerAngles.y), y: CGFloat(eulerAngles.x)))
    }
}


private extension FaceRecognitionViewController {

    func setUpCaptureSessionOutput() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA ]
        output.alwaysDiscardsLateVideoFrames = true
        guard captureSession.canAddOutput(output) else {
            return
        }
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
    }

    func setUpCaptureSessionInput() {
        DispatchQueue.global().async { [self] in
            guard let device = captureDevice(forPosition: .front) else {
                return
            }
            
            guard let camera = AVCaptureDevice.default(for: .video) else { return }
            captureDevice = camera
            captureDevice?.isFocusModeSupported(.continuousAutoFocus)
            
            do {
                try captureDevice?.lockForConfiguration()
                captureDevice?.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            } catch { }
            
            photoOutput = AVCapturePhotoOutput()
            
            captureSession.beginConfiguration()
            captureSession!.inputs.forEach(captureSession.removeInput)
            
            guard let input = try? AVCaptureDeviceInput(device: device) else { return }
            guard captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) else {
                return
            }
            captureSession.addInput(input)
            captureSession.addOutput(photoOutput)
            captureSession.commitConfiguration()
        }
    }

    func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first(where: { $0.position == position })
    }
                                        
    func createOverlay() {
        overlayView.backgroundColor = UIColor.black
        
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: counterView.frame.midX, y: counterView.frame.midY),
                    radius: counterView.frame.size.height / 2 - 65,
                    startAngle: 0,
                    endAngle: 2 * .pi,
                    clockwise: false)
        path.addRect(CGRect(origin: .zero, size: backgroundView.frame.size))
        
        let maskLayer = CAShapeLayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.path = path
        maskLayer.fillRule = .evenOdd
        
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        backgroundView.addSubview(overlayView)
        overlayView.edgeAnchors == backgroundView.edgeAnchors
    }

    func drawCircle() {
        let circlePath = UIBezierPath(
            arcCenter: counterView.center,
            radius: counterView.frame.size.height / 2 - 55,
            startAngle: 0,
            endAngle: 2 * .pi,
            clockwise: true)
        
        let shapeLayer = CAShapeLayer()
        innerCircleLayer = shapeLayer
        shapeLayer.path = circlePath.cgPath
        
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 2
        
        backgroundView.layer.addSublayer(shapeLayer)
    }
    
}
