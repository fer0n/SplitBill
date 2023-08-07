//
//  OneHandedZoomGesture.swift
//  SplitBill
//
//  Created by fer0n on 09.12.22.
//

import Foundation
import UIKit


enum ZoomGestureStatus {
    case unknown
    case firstTouchDown
    case TouchUp
    case secondTouchDown
}

class OneHandedZoomGestureRecognizer: UIGestureRecognizer {
    var ignoreTapsAt: ((_ point: CGPoint) -> Bool)?
    
    private var lastTouchTime:CFTimeInterval = CACurrentMediaTime()
    private(set) var status = ZoomGestureStatus.unknown
    private(set) var doubleTapGestureThreshold: CFTimeInterval = 0.3
    private(set) var locationTapThreshold: Float = 15
    private var lastTapLocation: CGPoint? = nil
    
    var yOffset: CGFloat = 0
    
    func setThreshold(threshold:CFTimeInterval) {
        self.doubleTapGestureThreshold = threshold
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let currentTime = CACurrentMediaTime()
        
        let location = touches.first?.location(in: self.view?.window)
        
        let timeDiff: CFTimeInterval = currentTime - lastTouchTime
        
        if status == .TouchUp, timeDiff < doubleTapGestureThreshold,
            let location = location,
            let lastTapLocation = lastTapLocation {
            let distDiff = hypotf(Float((location.x - lastTapLocation.x)), Float((location.y - lastTapLocation.y)));
            
            if let ignoreTapsAt = ignoreTapsAt,
               let viewLocation = touches.first?.location(in: self.view){
                let ignore = ignoreTapsAt(viewLocation)
                if (ignore) {
                    return
                }
            }
            
            if (distDiff < locationTapThreshold) {
                status = .secondTouchDown
                super.touchesBegan(touches, with: event)
                self.state = .began
                self.lastTapLocation = location
            }
        
        } else {
            status = .firstTouchDown
            let location = touches.first?.location(in: self.view?.window)
            lastTapLocation = location
        }
        lastTouchTime = currentTime
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if (status == .secondTouchDown) {
            let location = touches.first?.location(in: self.view?.window)
            guard let lastTapLocation = lastTapLocation,
                  let location = location else { return }
            yOffset = location.y - lastTapLocation.y
            
            super.touchesMoved(touches, with: event)
            self.state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if (status == .firstTouchDown) {
            status = .TouchUp
        } else if (status == .secondTouchDown) {
            status = .unknown
            super.touchesEnded(touches, with: event)
            self.state = .ended
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
    }
}
