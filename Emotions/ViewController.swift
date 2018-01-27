//
//  ViewController.swift
//  Emotions
//
//  Created by Denes Csizmadia on 2017. 08. 16..
//  Copyright © 2017. Denes Csizmadia. All rights reserved.
//


import UIKit
import CoreML
import Foundation
import AVFoundation
import CoreAudio
import Charts
import SwiftSiriWaveformView
import AudioKit



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, ChartViewDelegate {
    
    
    @IBOutlet weak var cameraView: UIView!
    //Chart
    @IBOutlet weak var lineChartView: LineChartView!
    var timerChart:Timer?
    var predTimer = Timer()
    var image : UIImage?
    var faceImage : UIImage?
    
    //emotions
    
    var anger = 0
    var disgust = 0
    var fear = 0
    var happy = 0
    var sad = 0
    var suprise = 0
    
    var emotions : MLMultiArray?
    
    
    
    //audio
    var audioTimer = Timer()
    let microphone = AKMicrophone()
    var tracker: AKAmplitudeTracker?
    var fftTracker: AKFFTTap?
    var silence: AKBooster?
    let minimum: Double = 60
    let maximum: Double = 560
    @IBOutlet weak var waveformView: SwiftSiriWaveformView!
    var change:CGFloat = 0.01
    
    
    
    
    // add point
    var i = 1
    
    var boolVal: Bool = true
    var boolValPred: Bool = true

    var timer:Timer?
    // @IBOutlet weak var cameraView: UIView!
    
    var cameraStatus = AVCaptureDevice.Position.back
    
   // @IBOutlet weak var labelText: UITextField!
    
    var gru1:MLMultiArray?
    var gru2:MLMultiArray?
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lineChartView.tintColor = UIColor.white
        lineChartView.descriptionText = "Emotions"
        
        //audio
        tracker = AKAmplitudeTracker(microphone)
        silence = AKBooster(tracker!, gain: 0)
        
        fftTracker = AKFFTTap(microphone)
        
        //charts
        self.lineChartView.delegate = self
        let set_a: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Anger")
        set_a.drawCirclesEnabled = false
        set_a.setColor(UIColor.blue)
        
        let set_b: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Disgust")
        set_b.drawCirclesEnabled = false
        set_b.setColor(UIColor.green)
        
        let set_c: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Fear")
        set_c.drawCirclesEnabled = false
        set_c.setColor(UIColor.red)
        
        let set_d: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Happin")
        set_d.drawCirclesEnabled = false
        set_d.setColor(UIColor.purple)
        
        let set_e: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Sadn")
        set_e.drawCirclesEnabled = false
        set_e.setColor(UIColor.cyan)
        
        let set_f: LineChartDataSet = LineChartDataSet(values: [ChartDataEntry](), label: "Suprise")
        set_f.drawCirclesEnabled = false
        set_f.setColor(UIColor.orange)
        
        self.lineChartView.data = LineChartData(dataSets: [set_a, set_b, set_c, set_d, set_e, set_f])
        
        timerChart = Timer.scheduledTimer(timeInterval: 0.1, target:self, selector: #selector(ViewController.updateCounter), userInfo: nil, repeats: true)
        
        
        
         self.waveformView.density = 1.0
        
        
        
        setupCameraSession()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setBool(_:)), userInfo: nil, repeats: true)
        
        predTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.setBoolValPred(_:)), userInfo: nil, repeats: true)
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        audioTimer = Timer.scheduledTimer(timeInterval: 0.009, target: self, selector: #selector(ViewController.measure(_:)), userInfo: nil, repeats: true)
        AudioKit.output = silence
        AudioKit.start()
        microphone.start()
        tracker?.start()
        
        //cameraView.layer.addSublayer(previewLayer)
        
//        previewLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
//        previewLayer.backgroundColor = UIColor.clear.cgColor
        self.cameraView.layer.addSublayer(previewLayer)
        
        cameraSession.startRunning()
    }
    
    
    
    
    @objc internal func measure(_:Timer) {
        if let amplitude = tracker?.amplitude {
            self.waveformView.amplitude = CGFloat(amplitude*10)
        }
        
        
        if let fftData = fftTracker?.fftData {
            //let sum = fftData.reduce(0, +)
            //self.waveformView.amplitude = CGFloat(sum*10)
            let model = RNN()
            guard let mlMultiArray = try? MLMultiArray(shape:[512], dataType:MLMultiArrayDataType.double) else {
                fatalError("Unexpected runtime error. MLMultiArray")
            }
            for i in 0..<512 {
                mlMultiArray[i] = NSNumber(value: fftData[i])
            }
            
            //mlMultiArray[0] = frequency
            guard let result = try? model.prediction(input1: mlMultiArray , gru_5_h_in: gru1, gru_6_h_in: gru2) else {
                print("prediction failed")
                return
            }
            gru1 = result.gru_5_h_out
            gru2 = result.gru_6_h_out
            print(result.output1)
        }
           
      

        
        
    }
    
    
    
    internal func refreshAudioView(_:Timer) {
        if self.waveformView.amplitude <= self.waveformView.idleAmplitude || self.waveformView.amplitude > 1.0 {
            self.change *= -1.0
        }
        
        // Simply set the amplitude to whatever you need and the view will update itself.
        self.waveformView.amplitude += self.change
    }
    
    
    lazy var cameraSession: AVCaptureSession = {
        let s = AVCaptureSession()
        s.sessionPreset = AVCaptureSession.Preset.low
        return s
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.bounds = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        preview.position = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        preview.videoGravity = AVLayerVideoGravity.resize
        return preview
    }()
    
    func setupCameraSession() {
        let captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video, position: AVCaptureDevice.Position.front)
        //default(for: .video)
        
        //AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice
        
        
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            
            
            cameraSession.beginConfiguration()
            
            cameraSession.sessionPreset = AVCaptureSession.Preset.high
            
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
            //   dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.invasivecode.videoQueue")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // Here you collect each frame and process it
        
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        if boolVal {
            if let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) {
               
                
                self.image = image
  
                
               
                self.detectFace(imageToDetect: image)
                if let image = self.faceImage {
                    emotions = predictEmotions(image: image)
                    self.faceImage = nil
                }

                

            }
            boolVal = false

        }
    //        if boolValPred {

      //  }
            
            
            
                
//                let prediction = predictWithInceptionV3(image: image)
//
//                DispatchQueue.main.async(){
//                    self.labelText.text = "Item: \(prediction?.0 as! String) Confidence: \(prediction?.1 as! Double)"
//                }
        
            }
    
        

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
    }
    
    
    
    
    @objc func updateCounter() {
        if let emotions = emotions{
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[0].doubleValue), dataSetIndex: 0)
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[1].doubleValue), dataSetIndex: 1)
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[2].doubleValue), dataSetIndex: 2)
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[3].doubleValue), dataSetIndex: 3)
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[4].doubleValue), dataSetIndex: 4)
        self.lineChartView.data?.addEntry(ChartDataEntry(x: Double(i), y: emotions[5].doubleValue), dataSetIndex: 5)
        
        if (i>300) {
            self.lineChartView.setVisibleXRange(minXRange: Double(1), maxXRange: Double(300))
        }
        self.lineChartView.notifyDataSetChanged()
        self.lineChartView.moveViewToX(Double(CGFloat(i)))
        i = i + 1
        }
    }
    
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        if let context = context {
            let quartzImage = context.makeImage()
            
            // Unlock the pixel buffer
            
            CVPixelBufferUnlockBaseAddress(imageBuffer!,CVPixelBufferLockFlags(rawValue: 0));
            
            // Create an image object from the Quartz image
            let image = UIImage(cgImage: quartzImage!)
            
            return image
        }
        else {
            return nil}
    }
    
    @IBAction func change(_ sender: UIButton) {
        switch cameraStatus {
        case AVCaptureDevice.Position.back:
            cameraStatus = AVCaptureDevice.Position.front
        default:
            cameraStatus = AVCaptureDevice.Position.back
        }
        
        setupCameraSession()
        
        
    }
    
    @objc func setBool(_ sender: Any) {
        boolVal = true
    }
    
    
    @objc func setBoolValPred(_ sender: Any) {
        boolValPred = true

        }



//Image processing


func detectFace(imageToDetect: UIImage){
    
    
    let rotatedimage = imageRotatedByDegrees(oldImage: imageToDetect, deg: 90)
    
    guard let personciImage = CIImage(image: rotatedimage) else {
        return
    }
    
    
    let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
    let faces = faceDetector?.features(in: personciImage)
    
    if (faces?.count)! > 0 {

        if let face = faces?[0]{
            self.faceImage = cropImage(imageToCrop: rotatedimage, toRect: (face.bounds))
            print("Face found")
                  DispatchQueue.main.async {
                    
                let drawing =  CGRect(x: 375 - face.bounds.maxX/2, y: 667 - face.bounds.maxY/2, width: face.bounds.width/2, height: face.bounds.height/2)
          
                let k = Draw(frame:drawing)
                
                // Add the view to the view hierarchy so that it shows up on screen
                k.tag = 10
                if let foundView = self.view.viewWithTag(10) {
                        foundView.removeFromSuperview()
                }
                self.view.addSubview(k)
            }
           
            }
        }



        
    }
    
    func cropImage(imageToCrop:UIImage, toRect rect:CGRect) -> UIImage{
        
        let imageRef:CGImage = imageToCrop.cgImage!.cropping(to: rect)!
        let cropped:UIImage = UIImage(cgImage:imageRef)
        return cropped
    }

    

func imageRotatedByDegrees(oldImage: UIImage, deg degrees: CGFloat) -> UIImage {
    //Calculate the size of the rotated view's containing box for our drawing space
    let rotatedViewBox: UIView = UIView(frame: CGRect(x: 0, y: 0, width: oldImage.size.width, height: oldImage.size.height))
    let t: CGAffineTransform = CGAffineTransform(rotationAngle: degrees * CGFloat(M_PI / 180))
    rotatedViewBox.transform = t
    let rotatedSize: CGSize = rotatedViewBox.frame.size
    //Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize)
    let bitmap: CGContext = UIGraphicsGetCurrentContext()!
    //Move the origin to the middle of the image so we will rotate and scale around the center.
    bitmap.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
    //Rotate the image context
    bitmap.rotate(by: (degrees * CGFloat(M_PI / 180)))
    //Now, draw the rotated/scaled image into the context
    bitmap.scaleBy(x: 1.0, y: -1.0)
    bitmap.draw(oldImage.cgImage!, in: CGRect(x: -oldImage.size.width / 2, y: -oldImage.size.height / 2, width: oldImage.size.width, height: oldImage.size.height))
    let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return newImage
}



    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    
    
}


class Draw: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let h = rect.height
        let w = rect.width
        var color:UIColor = UIColor.yellow
    
        
        var drect = CGRect(x: 0,y: 0 ,width: w,height: h)
        var bpath:UIBezierPath = UIBezierPath(rect: drect)
        
        color.set()
        bpath.stroke()
        
    }
    
}









