//
//  ViewController.swift
//  Que hay de nuevo
//
//  Created by Valentin Sanchez on 23/04/2020.
//  Copyright © 2020 Valentin Sanchez. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit

import CoreLocation
import GameplayKit

class ViewController: UIViewController, ARSKViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet var sceneView: ARSKView!
    
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    var sitesJSON : JSON!
    var userHeading = 0.0
    var headingStep = 0
    var sites = [UUID : String]()
    var sitesMio : [Sites] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /*let labelTitle = SKLabelNode(text: "Apunta con tu cámara para descubrir lugares cerca de ti")
        labelTitle.fontSize = 12
        labelTitle.color = UIColor.lightGray
        labelTitle.fontName = "Gill Sans"
        labelTitle.horizontalAlignmentMode = .center
        labelTitle.verticalAlignmentMode = .center
        labelTitle.numberOfLines = 2
        labelTitle.lineBreakMode = .byCharWrapping
        labelTitle.isUserInteractionEnabled = true
        labelTitle.position = CGPoint(x: 10, y: -25)*/
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and node count
        sceneView.showsFPS = true
        sceneView.showsNodeCount = true
        
        // Load the SKScene from 'Scene.sks'
        if let scene = SKScene(fileNamed: "Scene") {
            sceneView.presentScene(scene)
        }
        //print(NSLocale.current.languageCode!)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSKViewDelegate
    
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        
        self.createViewForNode(anchor: anchor)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    
    //MARK: CLLocationManager
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        DispatchQueue.global().async {
            self.updateSites()
        }
        print(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        DispatchQueue.main.async {
            self.headingStep += 1
            if self.headingStep < 2 { return }
            self.userHeading = newHeading.magneticHeading
            self.locationManager.stopUpdatingHeading()
            self.createSites()
        }
        //print("direccion camara")
    }
    
    func updateSites(){
        let urlString = "https://\(NSLocale.current.languageCode!).wikipedia.org/w/api.php?ggscoord=\(userLocation.coordinate.latitude)%7C\(userLocation.coordinate.longitude)&action=query&prop=coordinates%7Cpageimages%7Cpageterms&colimit=50&piprop=thumbnail&pithumbsize=500&pilimit=50&wbptterms=description&generator=geosearch&ggsradius=10000&ggslimit=25&format=json"
        guard let url = URL(string: urlString) else {return}
        
        if let data = try? Data(contentsOf: url){
            sitesJSON = JSON(data)
            //print(sitesJSON!)
            locationManager.startUpdatingHeading()
        }
    }
    
    func createSites(){
        
        for page in sitesJSON["query"]["pages"].dictionaryValue.values {
            //Ubicar latitud y longitud de esos lugares -> CLLocation
            let lat = page["coordinates"][0]["lat"].doubleValue
            let lon = page["coordinates"][0]["lon"].doubleValue
            let location = CLLocation(latitude: lat, longitude: lon)
            let distance = Float(userLocation.distance(from: location))
            let azimut = direction(from: userLocation, to: location)
            let angle = azimut - userHeading
            let angleRad = deg2Rad(angle)
            let horizontalRotation = float4x4.init(SCNMatrix4MakeRotation(Float(angleRad), 1, 0, 0))
            let verticalRotation = float4x4.init(SCNMatrix4MakeRotation(-0.1 + Float(distance/5000), 0, 1, 0))
            let rotation = simd_mul(horizontalRotation, verticalRotation)
            guard let sceneView = self.view as? ARSKView else { return }
            guard let currentFrame = sceneView.session.currentFrame else { return }
            let rotation2 = simd_mul(currentFrame.camera.transform, rotation)
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -clamp(value:distance / 100, lower: 0.5, upper: 4.0)
            let transform = simd_mul(rotation2, translation)
            let anchor = ARAnchor(transform: transform)
            sceneView.session.add(anchor: anchor)
            
            sites[anchor.identifier] = "\(page["title"].string!) - \(Int(distance)) metros"
            
            sitesMio.append(Sites(id: anchor.identifier, name: "\(page["title"].string!) - \(Int(distance)) metros", image: page["thumbnail"]["source"].string ?? "", url: "\(createWebLinks(title: page["title"].string!))"))
        }
    }
    
    func createWebLinks(title: String) -> String{
        let locale = NSLocale.current.languageCode
        let titleFormatter = title.replacingOccurrences(of: " ", with: "_")
        let titleFormatter2 = titleFormatter.replacingOccurrences(of: "á", with: "a")
        let titleFormatter3 = titleFormatter2.replacingOccurrences(of: "é", with: "e")
        let titleFormatter4 = titleFormatter3.replacingOccurrences(of: "í", with: "i")
        let titleFormatter5 = titleFormatter4.replacingOccurrences(of: "ó", with: "o")
        let titleFormatter6 = titleFormatter5.replacingOccurrences(of: "ú", with: "u")
        let titleFormatter7 = titleFormatter6.replacingOccurrences(of: "ñ", with: "n")
        let webLink = "https://\(locale!).wikipedia.org/wiki/\(titleFormatter7)"
        return webLink
    }
    
    func createViewForNode(anchor: ARAnchor) -> SKNode? {
        
        let backgroundNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 200, height: 200))
        backgroundNode.fillColor = .white
        
        for sites in sitesMio {
            if sites.id == anchor.identifier{
                let labelNodeMio = SKLabelNode(text: sites.name)
                labelNodeMio.fontName = "Gill Sans Bold"
                labelNodeMio.horizontalAlignmentMode = .center
                labelNodeMio.verticalAlignmentMode = .center
                labelNodeMio.fontColor = UIColor.black
                
                let nodeFor = SKShapeNode(circleOfRadius: 0.1)
                
                let sizeBackLabel = labelNodeMio.frame.size.applying(CGAffineTransform(scaleX: 1.2, y: 1.8))
                let backLabel = SKShapeNode(rectOf: sizeBackLabel, cornerRadius: 10)
                let randomColor = UIColor.init(hue: CGFloat(GKRandomSource.sharedRandom().nextUniform()), saturation: 0.5, brightness: 0.4, alpha: 1)
                backLabel.fillColor = randomColor
                backLabel.strokeColor = randomColor.withAlphaComponent(1.0)
                backLabel.lineWidth = 2
                backLabel.addChild(labelNodeMio)
                nodeFor.addChild(backLabel)
                
                let urlString = sites.image
                guard let url = URL(string: urlString!) else { return nil}
                
                let imageNode = SKSpriteNode(texture: SKTexture(image: UIImage(data: NSData(contentsOf: url)! as Data) ?? UIImage()))
                imageNode.scale(to: CGSize(width: backgroundNode.frame.width - 10, height: backgroundNode.frame.height - 10))
                imageNode.alpha = 0.8
                imageNode.position = CGPoint(x: backgroundNode.frame.midX, y: backgroundNode.frame.midY)
                
                labelNodeMio.isUserInteractionEnabled = false
                backLabel.isUserInteractionEnabled = false
                nodeFor.isUserInteractionEnabled = false
                nodeFor.position = CGPoint(x: 0, y: -200 - nodeFor.frame.height/2)
                imageNode.addChild(nodeFor)
                imageNode.isUserInteractionEnabled = false
                backgroundNode.addChild(imageNode)
                backgroundNode.name = sites.url
                labelNodeMio.name = sites.url
                backLabel.name = sites.url
                nodeFor.name = sites.url
                imageNode.name = sites.url
            }
        }
        
        return backgroundNode
    }

    //MARK: Mathematical library
    
    func deg2Rad(_ degrees: Double) -> Double {
        return degrees * Double.pi / 180.0
    }
    
    func rad2deg(_ radians: Double) -> Double {
        return radians * 180.0 / Double.pi
    }
    
    func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
        return min(max(value, lower), upper)
    }
    
    func direction(from p1:CLLocation, to p2: CLLocation) -> Double {
        let dif_long = p2.coordinate.longitude - p1.coordinate.longitude
        let y = sin(dif_long) * cos(p2.coordinate.longitude)
        let x = cos(p1.coordinate.latitude) * sin(p2.coordinate.latitude) - sin(p1.coordinate.latitude) * cos(p2.coordinate.latitude) * cos(dif_long)
        let atan_rad = atan2(y, x)
        return rad2deg(atan_rad)
    }
}


private func _swizzling(forClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
    if let originalMethod = class_getInstanceMethod(forClass, originalSelector),
       let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector) {
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension UIViewController {

    static let preventPageSheetPresentation: Void = {
        if #available(iOS 13, *) {
            _swizzling(forClass: UIViewController.self,
                       originalSelector: #selector(present(_: animated: completion:)),
                       swizzledSelector: #selector(_swizzledPresent(_: animated: completion:)))
        }
    }()

    @available(iOS 13.0, *)
    @objc private func _swizzledPresent(_ viewControllerToPresent: UIViewController,
                                        animated flag: Bool,
                                        completion: (() -> Void)? = nil) {
        if viewControllerToPresent.modalPresentationStyle == .pageSheet
                   || viewControllerToPresent.modalPresentationStyle == .automatic {
            viewControllerToPresent.modalPresentationStyle = .fullScreen
        }
        _swizzledPresent(viewControllerToPresent, animated: flag, completion: completion)
    }
}
