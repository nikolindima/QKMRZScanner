//
//  QKMRZScannerView.swift
//  QKMRZScanner
//
//  Created by Matej Dorcak on 03/10/2018.
//

import UIKit
import AVFoundation
import SwiftyTesseract
import AudioToolbox
import Vision
import MLKitVision
import MLKitTextRecognition

enum CaptureError: Error {
    case didFinishCaptureWithError
    case bufferIsEmpty
    case couldNotConvertToJPEG
    case couldNotCreateUIImage
}

public protocol QKMRZScannerViewDelegate: class {
    func mrzScannerView(_ mrzScannerView: QKMRZScannerView, didFind scanResult: QKMRZScanResult)
}

@IBDesignable
public class QKMRZScannerView: UIView {
    fileprivate let tesseract = SwiftyTesseract(language: .custom("ocrb"), bundle: Bundle(for: QKMRZScannerView.self), engineMode: .tesseractLstmCombined)
    fileprivate let mrzParser = QKMRZParser(ocrCorrection: true)
    fileprivate let captureSession = AVCaptureSession()
    fileprivate let videoOutput = AVCaptureVideoDataOutput()
    fileprivate let videoPreviewLayer = AVCaptureVideoPreviewLayer()
    fileprivate let photoOutput = AVCapturePhotoOutput()
    fileprivate let cutoutView = QKCutoutView()
    fileprivate var isScanningPaused = false
    fileprivate var observer: NSKeyValueObservation?
    public var waithingForResult = false
    @objc public dynamic var isScanning = false
    public var vibrateOnResult = true
    public weak var delegate: QKMRZScannerViewDelegate?
    var textRecognizer: TextRecognizer!
    private var buffer: CMSampleBuffer?
    private var finalMRZResult: QKMRZResult!
    
    public var cutoutRect: CGRect {
        return cutoutView.cutoutRect
    }
    
    fileprivate var interfaceOrientation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: Initializers
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Overriden methods
    override public func prepareForInterfaceBuilder() {
        setViewStyle()
        addCutoutView()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        adjustVideoPreviewLayerFrame()
    }
    
    // MARK: Scanning
    public func startScanning() {
        guard !captureSession.inputs.isEmpty else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async { [weak self] in self?.adjustVideoPreviewLayerFrame() }
        }
    }
    
    public func stopScanning() {
        captureSession.stopRunning()
    }
    
    // MARK: MRZ
    fileprivate func mrz(from cgImage: CGImage) -> QKMRZResult? {
        let mrzTextImage = UIImage(cgImage: preprocessImage(cgImage))
        var recognizedString: String?
        let visionImage = VisionImage(image: mrzTextImage)
        visionImage.orientation = .up
        
        do {
            let result = try textRecognizer.results(in: visionImage)
            
            if var mrzLines = self.mrzLines(from: result.text) {
                
                tesseract.performOCR(on: mrzTextImage) { recognizedString = $0 }
                
                if let string = recognizedString, let tesseractmrzLines = self.mrzLines(from: string) {
                    var canContinue = false
                    if tesseractmrzLines == mrzLines
                    {
                        canContinue = true
                    }
                    
                    if tesseractmrzLines.count == mrzLines.count {
                        for i in 0..<tesseractmrzLines.count  {
                            if tesseractmrzLines[i].count == mrzLines[i].count {
                                for j in 0..<tesseractmrzLines[i].count {
                                    let substrT = tesseractmrzLines[i].substring(j, to: j)
                                    let substrG = mrzLines[i].substring(j, to: j)
                                    if substrT != substrG {
                                        if (substrT == "0" || substrT == "O") && (substrG == "0" || substrG == "O") {
                                        }
                                        else if substrT == "<" && substrG == "K" {
                                            let str = mrzLines[i].replace(j, "<")
                                            mrzLines[i] = str
                                        }
                                        else {
                                            break
                                        }
                                    }
                                }
                                
                            }
                        }
                    }
                    
                    if canContinue {
                        return self.mrzParser.parse(mrzLines: mrzLines)
                    }
                }
                
            }
        }
        catch {
            return nil
        }
        
        return nil
    }
    
    fileprivate func mrzLines(from recognizedText: String) -> [String]? {
        let mrzString = recognizedText.replacingOccurrences(of: " ", with: "")
        do {
            let regex = try NSRegularExpression(pattern: #"^[A-Z0-9\<\n]*$"#)
            if regex.matches(mrzString) {
                var mrzLines = mrzString.components(separatedBy: "\n").filter({ !$0.isEmpty })
                if !mrzLines.isEmpty {
                    let averageLineLength = (mrzLines.reduce(0, { $0 + $1.count }) / mrzLines.count)
                    mrzLines = mrzLines.filter({ $0.count >= averageLineLength })
                }
                
                return mrzLines.isEmpty ? nil : mrzLines
            }
        }
        catch {
            return nil
        }
        
        return nil
        
    }
    
    // MARK: Document Image from Photo cropping
    fileprivate func cutoutRect(for cgImage: CGImage) -> CGRect {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: cutoutRect)
        let videoOrientation = videoPreviewLayer.connection!.videoOrientation
        
        if videoOrientation == .portrait || videoOrientation == .portraitUpsideDown {
            return CGRect(x: (rect.minY * imageWidth), y: (rect.minX * imageHeight), width: (rect.height * imageWidth), height: (rect.width * imageHeight))
        }
        else {
            return CGRect(x: (rect.minX * imageWidth), y: (rect.minY * imageHeight), width: (rect.width * imageWidth), height: (rect.height * imageHeight))
        }
    }
    
    fileprivate func documentImage(from cgImage: CGImage) -> CGImage {
        let croppingRect = cutoutRect(for: cgImage)
        return cgImage.cropping(to: croppingRect) ?? cgImage
    }
    fileprivate func takePhoto() {
        guard let photoOutputConnection = photoOutput.connection(with: AVMediaType.video) else {fatalError("Unable to establish input>output connection")}// setup a connection that manages input > output
        photoOutputConnection.videoOrientation = .portrait // update photo's output connection to match device's orientation
        
        
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.isAutoStillImageStabilizationEnabled = photoOutput.isStillImageStabilizationSupported
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    fileprivate func enlargedDocumentImage(from cgImage: CGImage) -> UIImage {
        var croppingRect = cutoutRect(for: cgImage)
        let margin = (0.05 * croppingRect.height) // 5% of the height
        croppingRect = CGRect(x: (croppingRect.minX - margin), y: (croppingRect.minY - margin), width: croppingRect.width + (margin * 2), height: croppingRect.height + (margin * 2))
        return UIImage(cgImage: cgImage.cropping(to: croppingRect)!)
    }
    
    // MARK: UIApplication Observers
    @objc fileprivate func appWillEnterForeground() {
        if isScanningPaused {
            isScanningPaused = false
            startScanning()
        }
    }
    
    @objc fileprivate func appDidEnterBackground() {
        if isScanning {
            isScanningPaused = true
            stopScanning()
        }
    }
    
    // MARK: Init methods
    fileprivate func initialize() {
        textRecognizer = TextRecognizer.textRecognizer()
        photoOutput.isHighResolutionCaptureEnabled = true
        FilterVendor.registerFilters()
        setViewStyle()
        addCutoutView()
        initCaptureSession()
        addAppObservers()
    }
    
    fileprivate func setViewStyle() {
        backgroundColor = .black
    }
    
    fileprivate func addCutoutView() {
        cutoutView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cutoutView)
        
        NSLayoutConstraint.activate([
            cutoutView.topAnchor.constraint(equalTo: topAnchor),
            cutoutView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cutoutView.leftAnchor.constraint(equalTo: leftAnchor),
            cutoutView.rightAnchor.constraint(equalTo: rightAnchor)
        ])
    }
    
    fileprivate func initCaptureSession() {
        captureSession.sessionPreset = .hd1920x1080
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Camera not accessible")
            return
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: camera) else {
            print("Capture input could not be initialized")
            return
        }
        
        observer = captureSession.observe(\.isRunning, options: [.new]) { [unowned self] (model, change) in
            // CaptureSession is started from the global queue (background). Change the `isScanning` on the main
            // queue to avoid triggering the change handler also from the global queue as it may affect the UI.
            DispatchQueue.main.async { [weak self] in self?.isScanning = change.newValue! }
        }
        
        if captureSession.canAddInput(deviceInput) && captureSession.canAddOutput(videoOutput) && captureSession.canAddOutput(photoOutput) {
            captureSession.addInput(deviceInput)
            captureSession.addOutput(photoOutput)
            captureSession.addOutput(videoOutput)
            captureSession.sessionPreset = .photo
            
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video_frames_queue", qos: .userInteractive, attributes: [], autoreleaseFrequency: .workItem))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
            videoOutput.connection(with: .video)!.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
            
            videoPreviewLayer.session = captureSession
            videoPreviewLayer.videoGravity = .resizeAspectFill
            
            layer.insertSublayer(videoPreviewLayer, at: 0)
        }
        else {
            print("Input & Output could not be added to the session")
        }
    }
    
    fileprivate func addAppObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // MARK: Misc
    fileprivate func adjustVideoPreviewLayerFrame() {
        videoOutput.connection(with: .video)?.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
        videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation(orientation: interfaceOrientation)
        videoPreviewLayer.frame = bounds
    }
    
    fileprivate func preprocessImage(_ image: CGImage) -> CGImage {
        var inputImage = CIImage(cgImage: image)
        let averageLuminance = inputImage.averageLuminance
        var exposure = 0.5
        let threshold = (1 - pow(1 - averageLuminance, 0.2))
        
        if averageLuminance > 0.8 {
            exposure -= ((averageLuminance - 0.5) * 2)
        }
        
        if averageLuminance < 0.35 {
            exposure += pow(2, (0.5 - averageLuminance))
        }
        
        inputImage = inputImage.applyingFilter("CIExposureAdjust", parameters: ["inputEV": exposure])
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2])
            .applyingFilter("LuminanceThresholdFilter", parameters: ["inputThreshold": threshold])
        
        return CIContext.shared.createCGImage(inputImage, from: inputImage.extent)!
    }
}
extension QKMRZScannerView: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let data = photo.fileDataRepresentation() else {
            waithingForResult = false
            return
        }
        if  let image = UIImage(data: data)?.cgImage {
            
            let orientation = photo.metadata[kCGImagePropertyOrientation as String] as! NSNumber
            let uiOrientation = UIImage.Orientation(rawValue: orientation.intValue)!
            if let finalImage = self.createMatchingBackingDataWithImage(imageRef: image, orienation: uiOrientation) {
                let documentImage = self.documentImage(from: finalImage)
                let uidocImage = UIImage(cgImage: documentImage, scale: 1, orientation: .up)
                let scanResult = QKMRZScanResult(mrzResult: finalMRZResult, documentImage: uidocImage)
                DispatchQueue.main.async {
                    self.delegate?.mrzScannerView(self, didFind: scanResult)
                    if self.vibrateOnResult {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                }
            }
        }
        
    }
    
    func createMatchingBackingDataWithImage(imageRef: CGImage?, orienation: UIImage.Orientation) -> CGImage?
    {
        var orientedImage: CGImage?
        
        if let imageRef = imageRef {
            let originalWidth = imageRef.width
            let originalHeight = imageRef.height
            let bitsPerComponent = imageRef.bitsPerComponent
            let bytesPerRow = imageRef.bytesPerRow
            
            let bitmapInfo = imageRef.bitmapInfo
            
            guard let colorSpace = imageRef.colorSpace else {
                return nil
            }
            
            var degreesToRotate: Double
            var swapWidthHeight: Bool
            var mirrored: Bool
            switch orienation {
            case .up:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = false
                break
            case .upMirrored:
                degreesToRotate = 0.0
                swapWidthHeight = false
                mirrored = true
                break
            case .right:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .rightMirrored:
                degreesToRotate = 90.0
                swapWidthHeight = true
                mirrored = true
                break
            case .down:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = false
                break
            case .downMirrored:
                degreesToRotate = 180.0
                swapWidthHeight = false
                mirrored = true
                break
            case .left:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = false
                break
            case .leftMirrored:
                degreesToRotate = -90.0
                swapWidthHeight = true
                mirrored = false
                break
            @unknown default:
                fatalError()
            }
            let radians = degreesToRotate * Double.pi / 180.0
            
            var width: Int
            var height: Int
            if swapWidthHeight {
                width = originalHeight
                height = originalWidth
            } else {
                width = originalWidth
                height = originalHeight
            }
            
            let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
            contextRef?.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            if mirrored {
                contextRef?.scaleBy(x: -1.0, y: 1.0)
            }
            contextRef?.rotate(by: CGFloat(radians))
            if swapWidthHeight {
                contextRef?.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
            } else {
                contextRef?.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
            }
            contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(originalWidth), height: CGFloat(originalHeight)))
            orientedImage = contextRef?.makeImage()
        }
        
        return orientedImage
    }
}
// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension QKMRZScannerView: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if waithingForResult {
            return
        }
        guard let cgImage = CMSampleBufferGetImageBuffer(sampleBuffer)?.cgImage else {
            return
        }
        
        let documentImage = self.documentImage(from: cgImage)
        let imageRequestHandler = VNImageRequestHandler(cgImage: documentImage, options: [:])
        
        let detectTextRectangles = VNDetectTextRectanglesRequest { [unowned self] request, error in
            guard error == nil else {
                return
            }
            
            guard let results = request.results as? [VNTextObservation] else {
                return
            }
            
            let imageWidth = CGFloat(documentImage.width)
            let imageHeight = CGFloat(documentImage.height)
            let transform = CGAffineTransform.identity.scaledBy(x: imageWidth, y: -imageHeight).translatedBy(x: 0, y: -1)
            let mrzTextRectangles = results.map({ $0.boundingBox.applying(transform) }).filter({ $0.width > (imageWidth * 0.8) })
            let mrzRegionRect = mrzTextRectangles.reduce(into: CGRect.null, { $0 = $0.union($1) })
            
            guard mrzRegionRect.height <= (imageHeight * 0.4) else { // Avoid processing the full image (can occur if there is a long text in the header)
                return
            }
            
            if let mrzTextImage = documentImage.cropping(to: mrzRegionRect) {
                if let mrzResult = self.mrz(from: mrzTextImage), mrzResult.allCheckDigitsValid {
                    self.waithingForResult = true
                    self.finalMRZResult = mrzResult
                    self.takePhoto()
                    
                }
            }
        }
        
        try? imageRequestHandler.perform([detectTextRectangles])
    }
    
}
