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
import Combine
import ImageIO
import CoreMotion

final class FaceRecognitionViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    // MARK: - IBOutlets
    private var sceneView: ARSCNView!
    
    private var cameraView: UIView!
    
    private var backgroundView: UIView!
    
    private var counterView: CounterView!
    
    private var ambientIntensityValueLabel: UILabel!
    
    private var motionValueLabel: UILabel!
    
    private var gyroValueLabel: UILabel!
    
    private var magnetometerValueLabel: UILabel!
    
    private var rotationRateLabel: UILabel!
    
    private var headEulerValueLabel: UILabel!
    
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
    
    private let ambientIntensityValue = CurrentValueSubject<String?, Never>("0")
    
    private let headEuler = CurrentValueSubject<CGPoint, Never>(.zero)
    
    private var cancellables = [AnyCancellable]()
    
    let defaultRotation: Double = .pi / 2
    
    let manager = CMMotionManager()
    
    var contentNode: SCNNode?
    
    lazy var rightEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    lazy var leftEyeNode = SCNReferenceNode(named: "coordinateOrigin")
    
    let accelerometer = CurrentValueSubject<String?, Never>("")
    
    let gyro = CurrentValueSubject<String?, Never>("")
    
    let magnetic = CurrentValueSubject<String?, Never>("")
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setUpCaptureSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            counterView.startScanning()
            UIView.animate(withDuration: 0.3) {
                self.visualEffectView.alpha = 0
            }
        }
        
        manager.accelerometerUpdateInterval = 0.1
        
        manager.startAccelerometerUpdates(to: .main) { (data, error) in
            let x = data?.acceleration.x ?? 0
            let y = data?.acceleration.y ??                0
            let z = data?.acceleration.z ?? 0
            self.accelerometer.send(String(format: "Accelerometer\n %.2f - x\n %.2f - y\n %.2f - z", x, y, z))
        }
        
        manager.startGyroUpdates(to: .main, withHandler: { data, _ in
            let x = (data?.rotationRate.x ?? 0)
            let y = (data?.rotationRate.y ?? 0)
            let z = (data?.rotationRate.z ?? 0)
            
            self.gyro.send(String(format: "Gyro\n%.2f - x\n%.2f - y\n %.2f - z", x, y, z))
        })
        
        manager.startMagnetometerUpdates(to: .main) { data, _ in
            let x = (data?.magneticField.x ?? 0)
            let y = (data?.magneticField.y ?? 0)
            let z = (data?.magneticField.z ?? 0)
            self.magnetic.send(String(format: "Magnetic field\n%.2f - x\n%.2f - y\n%.2f - z", x, y, z))
        }
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
        configuration.isWorldTrackingEnabled = true
        configuration.maximumNumberOfTrackedFaces = 2
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // MARK: - Setup View's Positions
        cameraView = UIView()
        view.addSubview(cameraView)
        cameraView.edgeAnchors == view.edgeAnchors + UIEdgeInsets(top: 60, left: 40, bottom: 200, right: 40)

        backgroundView = UIView()
        view.addSubview(backgroundView)
        backgroundView.edgeAnchors == view.edgeAnchors

        counterView = CounterView()
        backgroundView.addSubview(counterView)
        counterView.centerXAnchor == backgroundView.centerXAnchor
        counterView.centerYAnchor == backgroundView.centerYAnchor - 80

        counterView.widthAnchor == backgroundView.widthAnchor
        counterView.heightAnchor == backgroundView.widthAnchor

        verticalOverlayView = UIView()
        backgroundView.addSubview(verticalOverlayView)
        verticalOverlayView.edgeAnchors == counterView.edgeAnchors + 50

        horizontalOverlayView = UIView()
        backgroundView.addSubview(horizontalOverlayView)
        horizontalOverlayView.edgeAnchors == counterView.edgeAnchors + 50

        verticalOverlayView.layer.transform = CATransform3DMakeRotation(-defaultRotation, 0, 1, 0)
        horizontalOverlayView.layer.transform = CATransform3DMakeRotation(defaultRotation, 1, 0, 0)

        ambientIntensityValueLabel = UILabel()
        backgroundView.addSubview(ambientIntensityValueLabel)
        ambientIntensityValueLabel.topAnchor == backgroundView.safeAreaLayoutGuide.topAnchor + 10
        ambientIntensityValueLabel.trailingAnchor == backgroundView.trailingAnchor - 4

        motionValueLabel = UILabel()
        backgroundView.addSubview(motionValueLabel)
        motionValueLabel.topAnchor == ambientIntensityValueLabel.bottomAnchor + 10
        motionValueLabel.trailingAnchor == backgroundView.trailingAnchor - 4

        gyroValueLabel = UILabel()
        backgroundView.addSubview(gyroValueLabel)
        gyroValueLabel.topAnchor == motionValueLabel.bottomAnchor + 10
        gyroValueLabel.trailingAnchor == backgroundView.trailingAnchor - 4
        
        magnetometerValueLabel = UILabel()
        backgroundView.addSubview(magnetometerValueLabel)
        magnetometerValueLabel.topAnchor == gyroValueLabel.bottomAnchor + 10
        magnetometerValueLabel.trailingAnchor == backgroundView.trailingAnchor - 4
        
        rotationRateLabel = UILabel()
        backgroundView.addSubview(rotationRateLabel)
        rotationRateLabel.topAnchor == magnetometerValueLabel.bottomAnchor + 10
        rotationRateLabel.trailingAnchor == backgroundView.trailingAnchor - 4

        headEulerValueLabel = UILabel()
        backgroundView.addSubview(headEulerValueLabel)
        headEulerValueLabel.topAnchor == rotationRateLabel.bottomAnchor + 10
        headEulerValueLabel.trailingAnchor == backgroundView.trailingAnchor - 4

        visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))

        backgroundView.addSubview(visualEffectView)
        visualEffectView.edgeAnchors == backgroundView.edgeAnchors

        overlayView = UIView(frame: backgroundView.frame)

        // MARK: - Setup View's Properties
        counterView.layer.zPosition = 3000
        counterView.alpha = .leastNonzeroMagnitude
        visualEffectView.alpha = 0
        
        motionValueLabel.numberOfLines = 0
        
        [headEulerValueLabel, rotationRateLabel, gyroValueLabel, motionValueLabel, ambientIntensityValueLabel, magnetometerValueLabel].forEach {
            $0?.font = .systemFont(ofSize: 12)
            $0?.textColor = .green
            $0?.numberOfLines = 0
            $0?.textAlignment = .right
        }
        
        ambientIntensityValue
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .map({ "Lux: \($0 ?? "")" })
            .assign(to: \.text, on: ambientIntensityValueLabel)
            .store(in: &cancellables)
        
        accelerometer
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .assign(to: \.text, on: motionValueLabel)
            .store(in: &cancellables)
        
        gyro
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .assign(to: \.text, on: gyroValueLabel)
            .store(in: &cancellables)
        
        gyro
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .assign(to: \.text, on: gyroValueLabel)
            .store(in: &cancellables)
        
        magnetic
            .throttle(for: .seconds(0.1), scheduler: DispatchQueue.main, latest: true)
            .assign(to: \.text, on: magnetometerValueLabel)
            .store(in: &cancellables)
        
//        headEuler.throttle(for: .seconds(0.05), scheduler: DispatchQueue.main, latest: true)
//            .map({ String(format: "Head euler: x %.2f, y %.2f", $0.x, $0.y) })
//            .assign(to: \.text, on: headEulerValueLabel)
//            .store(in: &cancellables)
    }
    
}

extension FaceRecognitionViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
//        guard let device = sceneView.device else { return nil }
//        let faceGeometry = ARSCNFaceGeometry(device: device)
//        let node = SCNNode(geometry: faceGeometry)
//
//        let notez = SCNReferenceNode(named: "coordinateOrigin")
//        node.addChildNode(notez)
//        return node
        
        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        let material = faceGeometry.firstMaterial!

        material.diffuse.contents = #imageLiteral(resourceName: "wireframeTexture") // Example texture map image.
        material.lightingModel = .constant


        let notez = SCNReferenceNode(named: "coordinateOrigin")
        let note = SCNNode(geometry: faceGeometry)
        note.addChildNode(notez)
        
        rightEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        leftEyeNode.simdPivot = float4x4(diagonal: [3, 3, 3, 1])
        
        note.addChildNode(rightEyeNode)
        note.addChildNode(leftEyeNode)

        return note
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        ambientIntensityValue.send(String(Int(sceneView.session.currentFrame?.lightEstimate?.ambientIntensity ?? 0)))
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
            return
        }
        faceGeometry.update(from: faceAnchor.geometry)
        rightEyeNode.simdTransform = faceAnchor.rightEyeTransform
        leftEyeNode.simdTransform = faceAnchor.leftEyeTransform
        
        headEuler.send(CGPoint(x: CGFloat(-faceAnchor.transform.eulerAngles.y), y: CGFloat(faceAnchor.transform.eulerAngles.z)))
    }
}


private extension FaceRecognitionViewController {

    func setUpCaptureSession() {
        guard let device = captureDevice(forPosition: .front),
              let camera = AVCaptureDevice.default(for: .video) else {
            return
        }
        captureDevice?.isFocusModeSupported(.continuousAutoFocus)
        
        captureSession = AVCaptureSession()
            
        // Config input / output
        DispatchQueue.global().async { [self] in
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
            
            
            captureSession.sessionPreset = .high
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [ (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA ]
            output.alwaysDiscardsLateVideoFrames = true
            guard captureSession.canAddOutput(output) else {
                return
            }
            captureSession.addOutput(output)
            captureSession.commitConfiguration()
            
            captureSession.startRunning()
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
    
}

extension FaceRecognitionViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        
        print(image.getExifData()!)
    }
}

extension UIImage {

    func getExifData() -> CFDictionary? {
        var exifData: CFDictionary? = nil
        if let data = self.jpegData(compressionQuality: 1.0) {
            data.withUnsafeBytes {
                let bytes = $0.baseAddress?.assumingMemoryBound(to: UInt8.self)
                if let cfData = CFDataCreate(kCFAllocatorDefault, bytes, data.count),
                    let source = CGImageSourceCreateWithData(cfData, nil) {
                    exifData = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                }
            }
        }
        return exifData
    }
}


extension SCNReferenceNode {
    convenience init(named resourceName: String, loadImmediately: Bool = true) {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "scn", subdirectory: "Models.scnassets")!
        self.init(url: url)!
        if loadImmediately {
            self.load()
        }
    }
}
