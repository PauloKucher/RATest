//
//  CameraViewController.swift
//  RATest
//
//  Created by brq on 26/02/20.
//  Copyright © 2020 brq. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase
import RxSwift
class CameraViewController: UIViewController {
    var session = AVCaptureSession()
    var input : AVCaptureDeviceInput?
    var output = AVCaptureVideoDataOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var cameraPreview = UIView()
    var closeButton = UIButton()
    let context = CIContext()
    var imageLabeler : VisionImageLabeler?
    var visionImage : VisionImage?
    var disposeBag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        previewLayer.frame = cameraPreview.frame
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.session.stopRunning()
    }
    
    func setupUI(){
        closeButton.setTitle("<", for: .normal)
        closeButton.titleLabel?.textColor = .blue
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = .clear
    }
    
//    func setupButton()
//    }
    
    func setupCameraView(){
        view.addSubview(cameraPreview)
        
        cameraPreview.translatesAutoresizingMaskIntoConstraints = false
        cameraPreview.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        cameraPreview.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        cameraPreview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        cameraPreview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "BUFFER"))
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
    }
    
    func checkCamera(){
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            initializeMlModel()
            setupCameraView()
            addInputDevice()
            break
            
        case .notDetermined:
            print("Nao determinado")
            break
            
        case .restricted:
            print("restrito")
            break
            
        case .denied:
            print("Negado")
            break
        }
    }
    
    func initializeMlModel(){
        guard let manifestPath = Bundle.main.path(
            forResource: "manifest",
            ofType: "json",
            inDirectory: "NextCardModel") else {
                print("Nao achei o manifest")
                return
        }
        let myLocalModel = AutoMLLocalModel(manifestPath: manifestPath)
        let labelerOptions = VisionOnDeviceAutoMLImageLabelerOptions(localModel: myLocalModel)
        labelerOptions.confidenceThreshold = 0.5
        imageLabeler = Vision.vision().onDeviceAutoMLImageLabeler(options: labelerOptions)
    }
    
    func addInputDevice(){
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        input = try? AVCaptureDeviceInput(device: camera)
        
        guard let input = input else {return}
        
        if session.canAddInput(input) {session.addInput(input)}
        previewLayer.session = session
        previewLayer.videoGravity = .resize
        previewLayer.connection?.videoOrientation = .portrait
        session.startRunning()
        cameraPreview.layer.addSublayer(previewLayer)
    }
    
    //Apresenta a imagem para o modelo para que seja feita a comparação
    @objc func performMLMagicOn(){
        guard let visionImage = try? visionImage else { return }
        imageLabeler?.process(visionImage, completion: { [weak self] (labels, error) in
            guard let self = self,
                let labels = labels else {return}
            if error != nil{
                print("ocorreu um erro")
                return
            }
            if labels.count == 0 { return }
            for visionLabel in labels{
                if visionLabel.text == "Blacklist" { break }
                let confidence = (visionLabel.confidence ?? 0).doubleValue * 100
                if confidence < 85 {return}
                let resultString = "\(visionLabel.text) -- \(confidence.rounded())% confident"
                print("\(resultString)")
                self.session.removeOutput(self.output)
                guard let input = self.input else { return }
                self.session.removeInput(input)
                break
            }
        })
    }
    
    //converte o frame pego pela camera e transforma em image
    func imageSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage?{
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return UIImage() }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage =  context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}


extension CameraViewController : AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {         guard let uiImage = self.imageSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        self.visionImage = VisionImage(image: uiImage)
        self.performMLMagicOn()
    }
}

