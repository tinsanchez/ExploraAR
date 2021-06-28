//
//  Scene.swift
//  Que hay de nuevo
//
//  Created by Valentin Sanchez on 23/04/2020.
//  Copyright © 2020 Valentin Sanchez. All rights reserved.
//

import SpriteKit
import ARKit

class Scene: SKScene {
    
    override func didMove(to view: SKView) {
        // Setup your scene here
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {return}
        let location = touch.location(in: self)
        let hit = nodes(at: location)
    
        if let sprite = hit.first {
            /*let scaleOut = SKAction.scale(to: 2, duration: 0.4)
            let fadeOut = SKAction.fadeOut(withDuration: 0.4)
            let remove = SKAction.removeFromParent()
            
            print(sprite.description)
            let groupAction = SKAction.group([scaleOut, fadeOut])
            let sequenceAction = SKAction.sequence([groupAction, remove])
            
            sprite.run(sequenceAction)*/
            if let url = URL(string: sprite.name ?? "") {
                UIApplication.shared.open(url)
            }
            print(sprite.description)

        }
    }
    
}

//let url: NSURL = URL(string: "https://www.landrover.es/index.html")! as NSURL

//UIApplication.shared.open(url as URL)
