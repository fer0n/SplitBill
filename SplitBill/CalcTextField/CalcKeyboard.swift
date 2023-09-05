//
//  CalcKeyboard.swift
//  ScorePad
//
//  Created by fer0n on 12.07.21.
//

import UIKit
import SwiftUI

// The view controller will adopt this protocol (delegate)
// and thus must contain the keyWasTapped method
protocol KeyboardDelegate: AnyObject {
    func keyWasTapped(action: KeyboardAction, character: String)
}

class CalcKeyboard: UIView {

    // This variable will be set as the view controller so that
    // the keyboard can send messages to the view controller.
    var delegate: KeyboardDelegate?
    var accentColor: UIColor
    var bgColor: UIColor
    var initialDeleteTimer: Timer?
    var continuousDeleteTimer: Timer?

    // MARK:- keyboard initialization
    required init?(coder aDecoder: NSCoder) {
        self.accentColor = UIColor.systemBlue
        self.bgColor = UIColor.systemBlue
        super.init(coder: aDecoder)
        initializeSubviews()
    }

    override init(frame: CGRect) {
        self.accentColor = UIColor.systemBlue
        self.bgColor = UIColor.systemBlue
        super.init(frame: frame)
        initializeSubviews()
    }
    
    func setAccentColor(color: UIColor,
                        bgColor: UIColor) {
        self.accentColor = color
        self.bgColor = bgColor
    }
    
    func initializeSubviews() {
        let xibFileName = "CalcKeyboard" // xib extention not included
        let view = Bundle.main.loadNibNamed(xibFileName, owner: self, options: nil)![0] as! UIView
        self.addSubview(view)
        view.frame = self.bounds
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            // UIView disappear
        } else {
            // UIView appear
            updateColor()
        }
    }

    @objc func startContinuousDelete() {
        self.delegate?.keyWasTapped(action: .delete, character: "")
        
        // Start the continuous delete timer for faster deletion
        continuousDeleteTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(performDeleteAction), userInfo: nil, repeats: true)
    }

    
    @objc func performDeleteAction() {
        self.delegate?.keyWasTapped(action: .delete, character: "")
    }

    
    func updateColor() {
        let allSubViews = self.allSubviews
        for view in allSubViews {
            if let button = view as? UIButton {
                switch button.tag {
                case KeyboardAction.insertNumber.rawValue,
                     KeyboardAction.point.rawValue:
                    button.setTitleColor(self.accentColor, for: .normal)
                default:
                    button.backgroundColor = self.bgColor
                }
            }
        }
    }

    @IBAction func TouchDown(_ sender: UIButton) {
        switch sender.tag {
        case KeyboardAction.delete.rawValue:
            performDeleteAction()
            initialDeleteTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(startContinuousDelete), userInfo: nil, repeats: false)
        default:
            return
        }
    }
    
    @IBAction func TouchUp(_ sender: UIButton) {
        initialDeleteTimer?.invalidate()
        continuousDeleteTimer?.invalidate()
        initialDeleteTimer = nil
        continuousDeleteTimer = nil
    }
    
    // MARK:- Button actions from .xib file
    @IBAction func CalcKeyboard(sender: UIButton) {
        // When a button is tapped, send that information to the
        // delegate (ie, the view controller)
        let text = sender.titleLabel?.text
        self.delegate?.keyWasTapped(action: KeyboardAction(rawValue: sender.tag) ?? KeyboardAction.insertNumber, character: text ?? "")
    }
}

enum KeyboardAction: Int {
    case insertNumber = 0
    case submit = 1
    case delete = 2
    case point = 3
    case insertOperand = 4
}
