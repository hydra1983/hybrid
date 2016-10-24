//
//  Canvas.swift
//  hybrid
//
//  Created by alastair.coote on 21/10/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import JavaScriptCore
import UIKit

class HexColor {
    
    let red:CGFloat
    let blue:CGFloat
    let green:CGFloat
    
    init(hexString:String) {
        let hexString:NSString = hexString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        let scanner = NSScanner(string: hexString as String)
        
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        
        var color:UInt32 = 0
        scanner.scanHexInt(&color)
        
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        
        red   = CGFloat(r) / 255.0
        green = CGFloat(g) / 255.0
        blue  = CGFloat(b) / 255.0
        
    }
    
    func toString() -> String {
        let rgb:Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        
        return NSString(format:"#%06x", rgb) as String
    }
    
}

@objc protocol TwoDContextExports : JSExport {
    init(width: Int, height: Int)
    func clearRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    func fillRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    func strokeRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    func beginPath()
    func closePath()
    func moveTo(x:CGFloat, y:CGFloat)
    func lineTo(x:CGFloat, y:CGFloat)
    func bezierCurveTo(cp1x:CGFloat, cp1y:CGFloat, cp2x: CGFloat, cp2y:CGFloat, x:CGFloat, y:CGFloat)
    func quadraticCurveTo(cpx:CGFloat, cpy:CGFloat, x:CGFloat, y:CGFloat)
    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    func arc(x:CGFloat, y: CGFloat, radius:CGFloat, startAngle: CGFloat, endAngle:CGFloat, antiClockwise:Bool)
    func arcTo(x1:CGFloat, y1: CGFloat, x2: CGFloat, y2:CGFloat, radius: CGFloat)
    func fill()
    func stroke()
    
    var fillStyle:String {get set }
    var strokeStyle:String {get set}
    var lineWidth:Float {get set}
    
}

@objc class TwoDContext: NSObject, TwoDContextExports {
    
    let context: CGContextRef
    
    required init(width: Int, height: Int) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.context = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue).rawValue)!
    }
    
    func toImage() -> CGImage {
        let imageRef = CGBitmapContextCreateImage(self.context)
        return imageRef!
    }
    
    func clearRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextClearRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    func fillRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextFillRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    func strokeRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextStrokeRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    func beginPath() {
        CGContextBeginPath(self.context)
    }
    
    func closePath() {
        CGContextClosePath(self.context)
    }
    
    func moveTo(x:CGFloat, y:CGFloat) {
        CGContextMoveToPoint(self.context, x, y)
    }
    
    func lineTo(x:CGFloat, y:CGFloat) {
        CGContextAddLineToPoint(self.context, x, y)
    }
    
    func bezierCurveTo(cp1x:CGFloat, cp1y:CGFloat, cp2x: CGFloat, cp2y:CGFloat, x:CGFloat, y:CGFloat) {
        CGContextAddCurveToPoint(self.context, cp1x, cp1y, cp2x, cp2y, x, y)
    }
    
    func quadraticCurveTo(cpx:CGFloat, cpy:CGFloat, x:CGFloat, y:CGFloat) {
        CGContextAddQuadCurveToPoint(self.context, cpx, cpy, x, y)
    }
    
    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextAddRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    func arc(x:CGFloat, y: CGFloat, radius:CGFloat, startAngle: CGFloat, endAngle:CGFloat, antiClockwise:Bool) {
        CGContextAddArc(self.context, x, y, radius, startAngle, endAngle, antiClockwise ? 1 : 0)
    }
    
    func arcTo(x1:CGFloat, y1: CGFloat, x2: CGFloat, y2:CGFloat, radius: CGFloat) {
        CGContextAddArcToPoint(self.context, x1, y1, x2, y2, radius)
    }
    
    func fill() {
        CGContextFillPath(self.context)
    }
    
    func stroke() {
        CGContextStrokePath(self.context)
    }
    

    private var fillStyleColor = HexColor(hexString: "#000000")
    
    var fillStyle:String {
        
        get {
            return fillStyleColor.toString()
        }
        
        set {
            self.fillStyleColor = HexColor(hexString: newValue)
            CGContextSetRGBFillColor(self.context, self.fillStyleColor.red, self.fillStyleColor.green, self.fillStyleColor.blue, 1)
        }
        
    }
    
    private var strokeStyleColor = HexColor(hexString: "#000000")
    
    var strokeStyle:String {
        
        get {
            return strokeStyleColor.toString()
        }
        
        set {
            self.strokeStyleColor = HexColor(hexString: newValue)
            CGContextSetRGBFillColor(self.context, self.strokeStyleColor.red, self.strokeStyleColor.green, self.strokeStyleColor.blue, 1)
        }
        
    }
    
    // We can't get line width back out of CGContext, so we store a reference here too
    private var currentLineWidth:Float = 1.0
    
    var lineWidth:Float {
        get {
            return self.currentLineWidth
        }
        
        set {
            self.currentLineWidth = newValue
            CGContextSetLineWidth(self.context, CGFloat(newValue))
        }
    }
    
}

@objc protocol OffscreenCanvasExports : JSExport {
    func getContext(contextType:String) -> TwoDContext?
}


@objc class OffscreenCanvas : NSObject, OffscreenCanvasExports {
    
    private let twoDContext: TwoDContext
    
    init(width: Int, height: Int) {
        self.twoDContext = TwoDContext(width: width, height: height)
    }
    
    func getContext(contextType:String) -> TwoDContext? {
    
        if contextType != "2d" {
            return nil
        }
        
        return self.twoDContext
    }
}
