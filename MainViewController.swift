//
//  MainViewController.swift
//  MimosRAPock
//
//  Created by brq on 19/02/20.
//  Copyright © 2020 brq. All rights reserved.
//

import UIKit
import Firebase
class MainViewController: UIViewController {
    
    var inputImage = UIImageView()
    var resultLabel = UILabel()
    var imageLabeler : VisionImageLabeler?
    var bt = UIButton()
    var btGallery = UIButton()
    let imagePicker = UIImagePickerController()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeMlModel()
        setupUI()
        constrauintUI()
    }
    
    
    func setupUI(){
        bt.setTitle("Camera", for: .normal)
        btGallery.setTitle("Galeria", for: .normal)
        view.backgroundColor = .white
    }
    
    func constrauintUI(){
        view.addSubview(bt)
        view.addSubview(btGallery)
        view.addSubview(resultLabel)
        
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        resultLabel.bottomAnchor.constraint(equalTo: btGallery.topAnchor, constant: -30).isActive = true
        
        btGallery.translatesAutoresizingMaskIntoConstraints = false
        btGallery.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        btGallery.rightAnchor.constraint(equalTo: bt.leftAnchor, constant: 0).isActive = true
        btGallery.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30).isActive = true
        btGallery.heightAnchor.constraint(equalToConstant: 40).isActive = true
        btGallery.widthAnchor.constraint(equalToConstant: view.frame.size.width / 2).isActive = true
        
        btGallery.addTarget(self, action: #selector(fetchFromGallery), for: .touchUpInside)
        btGallery.backgroundColor = .blue
        
        bt.translatesAutoresizingMaskIntoConstraints = false
        bt.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        bt.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30).isActive = true
        bt.heightAnchor.constraint(equalToConstant: 40).isActive = true
        bt.addTarget(self, action: #selector(fetchFromCamera), for: .touchUpInside)
        bt.backgroundColor = .red
    }
    
    @objc func fetchFromCamera(){
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    
    @objc func fetchFromGallery(){
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    func initializeMlModel(){
        guard let manifestPath = Bundle.main.path(
            forResource: "manifest",
            ofType: "json",
            inDirectory: "bundle") else {
                print("Nao achei o manifest")
                return
        }
        let myLocalModel = AutoMLLocalModel(manifestPath: manifestPath)
        let labelerOptions = VisionOnDeviceAutoMLImageLabelerOptions(localModel: myLocalModel)
        labelerOptions.confidenceThreshold = 0.5
        imageLabeler = Vision.vision().onDeviceAutoMLImageLabeler(options: labelerOptions)
    }
    
    func performMLMagicOn(_ visionImage: VisionImage){
        imageLabeler?.process(visionImage, completion: { [weak self] (labels, error) in
            guard let self = self,
                let labels = labels else {return}
            if error != nil{
                print("ocorreu um erro")
                return
            }
            if labels.count == 0{
                return
            }
            for visionLabel in labels{
                let confidence = (visionLabel.confidence ?? 0).doubleValue * 100
                let resultString = "\(visionLabel.text) -- \(confidence.rounded())% confident"
                self.resultLabel.text = resultString
                if visionLabel.text == "blackList"{
                    break
                }
            }
        })
    }
}

extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        var imageToSave: UIImage?
        if let editedImage = info[.editedImage] as? UIImage{
            imageToSave = editedImage
        }
//        else if let originalImage = info[.originalImage] as? UIImage{
//            imageToSave = originalImage
//        }
        
        guard imageToSave != nil else{
            print("Got no image")
            return
        }
        
        let visionImage = VisionImage(image: imageToSave!)
        performMLMagicOn(visionImage)
        self.dismiss(animated: true, completion: nil)
    }
    
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
