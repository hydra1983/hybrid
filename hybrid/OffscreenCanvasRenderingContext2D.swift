//
//  CanvasRenderingContext2D.swift
//  hybrid
//
//  Created by alastair.coote on 17/11/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import JavaScriptCore
import UIKit

@objc protocol OffscreenCanvasRenderingContext2DExports : JSExport {
    init(width: Int, height: Int)
    
    @objc(translate::)
    func translate(x: CGFloat, y: CGFloat)
    
    func rotate(angle: CGFloat)
    
    func save()
    
    func restore()
    
    @objc(clearRect::::)
    func clearRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    
    @objc(fillRect::::)
    func fillRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    
    @objc(strokeRect::::)
    func strokeRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    
    func beginPath()
    func closePath()
    
    @objc(moveTo::)
    func moveTo(x:CGFloat, y:CGFloat)
    
    @objc(lineTo::)
    func lineTo(x:CGFloat, y:CGFloat)
    
    @objc(bezierCurveTo::::::)
    func bezierCurveTo(cp1x:CGFloat, cp1y:CGFloat, cp2x: CGFloat, cp2y:CGFloat, x:CGFloat, y:CGFloat)
    
    @objc(quadraticCurveTo::::)
    func quadraticCurveTo(cpx:CGFloat, cpy:CGFloat, x:CGFloat, y:CGFloat)
    
    @objc(rect::::)
    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    
    @objc(arc::::::)
    func arc(x:CGFloat, y: CGFloat, radius:CGFloat, startAngle: CGFloat, endAngle:CGFloat, antiClockwise:Bool)
    
    @objc(arcTo:::::)
    func arcTo(x1:CGFloat, y1: CGFloat, x2: CGFloat, y2:CGFloat, radius: CGFloat)
    
    func fill()
    func stroke()
    
    @objc(drawImage:::::::::)
    func drawImage(bitmap:JSValue, arg1: JSValue, arg2: JSValue, arg3: JSValue, arg4: JSValue, arg5:JSValue, arg6: JSValue, arg7:JSValue, arg8:JSValue)
    
    var fillStyle:String {get set }
    var strokeStyle:String {get set}
    var lineWidth:Float {get set}
    var globalAlpha:CGFloat {get set}
    
    func setLineDash(dashes:[CGFloat]?)
    
}

@objc class OffscreenCanvasRenderingContext2D: NSObject, OffscreenCanvasRenderingContext2DExports {
    
    let context: CGContext
    
    required init(width: Int, height: Int) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        self.context = CGBitmapContextCreate(nil, width, height, 8, 0, colorSpace, CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue).rawValue)!
    }
    
    
    init(context:CGContext) {
        self.context = context;
    }
    
    @objc(translate::)
    func translate(x: CGFloat, y:CGFloat) {
        CGContextTranslateCTM(self.context, x, y)
    }
    
    func rotate(angle:CGFloat) {
        CGContextRotateCTM(self.context, angle)
    }
    
    func save() {
        CGContextSaveGState(self.context)
    }
    
    func restore() {
        CGContextRestoreGState(self.context)
    }
    
    func toImage() -> CGImage {
        let imageRef = CGBitmapContextCreateImage(self.context)
        return imageRef!
    }
    
    
    
    @objc(clearRect::::)
    func clearRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextClearRect(self.context, CGRect(x: x, y: y, width: width, height: height))
        
    }
    
    @objc(fillRect::::)
    func fillRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextFillRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    @objc(strokeRect::::)
    func strokeRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextStrokeRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    func beginPath() {
        CGContextBeginPath(self.context)
    }
    
    func closePath() {
        CGContextClosePath(self.context)
    }
    
    @objc(moveTo::)
    func moveTo(x:CGFloat, y:CGFloat) {
        CGContextMoveToPoint(self.context, x, y)
    }
    
    @objc(lineTo::)
    func lineTo(x:CGFloat, y:CGFloat) {
        CGContextAddLineToPoint(self.context, x, y)
    }
    
    @objc(bezierCurveTo::::::)
    func bezierCurveTo(cp1x:CGFloat, cp1y:CGFloat, cp2x: CGFloat, cp2y:CGFloat, x:CGFloat, y:CGFloat) {
        CGContextAddCurveToPoint(self.context, cp1x, cp1y, cp2x, cp2y, x, y)
    }
    
    @objc(quadraticCurveTo::::)
    func quadraticCurveTo(cpx:CGFloat, cpy:CGFloat, x:CGFloat, y:CGFloat) {
        CGContextAddQuadCurveToPoint(self.context, cpx, cpy, x, y)
    }
    
    @objc(rect::::)
    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        CGContextAddRect(self.context, CGRect(x: x, y: y, width: width, height: height))
    }
    
    @objc(arc::::::)
    func arc(x:CGFloat, y: CGFloat, radius:CGFloat, startAngle: CGFloat, endAngle:CGFloat, antiClockwise:Bool) {
        CGContextAddArc(self.context, x, y, radius, startAngle, endAngle, antiClockwise ? 1 : 0)
    }
    
    @objc(arcTo:::::)
    func arcTo(x1:CGFloat, y1: CGFloat, x2: CGFloat, y2:CGFloat, radius: CGFloat) {
        CGContextAddArcToPoint(self.context, x1, y1, x2, y2, radius)
    }
    
    func fill() {
        CGContextFillPath(self.context)
    }
    
    func stroke() {
        CGContextStrokePath(self.context)
    }
    
    func getBitmapFromArgument(arg:JSValue) -> ImageBitmap? {
        
        var targetBitmap:ImageBitmap?
        
        if arg.isInstanceOf(ImageBitmap.self) {
            targetBitmap = arg.toObjectOfClass(ImageBitmap.self) as! ImageBitmap
        } else if arg.isInstanceOf(OffscreenCanvas.self) {
            let canvas = arg.toObjectOfClass(OffscreenCanvas.self) as! OffscreenCanvas
            targetBitmap = ImageBitmap(image: canvas.getContext("2d")!.toImage())
        }
        
        return targetBitmap
    }
    
    func drawImage(bitmap:ImageBitmap, dx: CGFloat, dy: CGFloat) {
        self.drawImage(bitmap, dx: dx, dy: dy, dWidth: CGFloat(bitmap.width), dHeight: CGFloat(bitmap.height))
    }
    
    func drawImage(bitmap:ImageBitmap, dx: CGFloat, dy: CGFloat, dWidth:CGFloat, dHeight: CGFloat) {
        
        // -dy because of this transform stuff
        
        let canvasHeight = CGFloat(CGBitmapContextGetHeight(self.context))
        
        let destRect = CGRect(x: dx, y: canvasHeight - dHeight - dy, width: dWidth, height: dHeight)
        
        // Have to do this to avoid image drawing upside down
        
        
        CGContextSaveGState(self.context)
        
        let flipVertical:CGAffineTransform = CGAffineTransformMake(1,0,0,-1,0, canvasHeight)
        CGContextConcatCTM(context, flipVertical)
        
//        CGContextScaleCTM(self.context, 1.0, -1.0)
//        CGContextTranslateCTM(self.context, 0, CGFloat(bitmap.height))
//
        
        CGContextDrawImage(self.context, destRect, bitmap.image)
        
        CGContextRestoreGState(self.context)
        //
        //        CGContextScaleCTM(self.context, -1.0, 1.0)
        //        CGContextTranslateCTM(self.context, 0, CGFloat(-bitmap.height))
    }
    
    @objc(drawImage:::::::::)
    func drawImage(bitmap:JSValue, arg1: JSValue, arg2: JSValue, arg3: JSValue, arg4: JSValue, arg5:JSValue, arg6: JSValue, arg7:JSValue, arg8:JSValue) {
        
        let targetBitmap = getBitmapFromArgument(bitmap)
        
        if arg8.isUndefined == false {
            // it's the 8 arg variant
            
            self.drawImage(
                targetBitmap!,
                sx: CGFloat(arg1.toDouble()),
                sy: CGFloat(arg2.toDouble()),
                sWidth: CGFloat(arg3.toDouble()),
                sHeight: CGFloat(arg4.toDouble()),
                dx: CGFloat(arg5.toDouble()),
                dy: CGFloat(arg6.toDouble()),
                dWidth: CGFloat(arg7.toDouble()),
                dHeight: CGFloat(arg8.toDouble())
            )
        } else if arg4.isUndefined == false {
            
            self.drawImage(
                targetBitmap!,
                dx: CGFloat(arg1.toDouble()),
                dy: CGFloat(arg2.toDouble()),
                dWidth: CGFloat(arg3.toDouble()),
                dHeight: CGFloat(arg4.toDouble())
            )
        } else {
            self.drawImage(
                targetBitmap!,
                dx: CGFloat(arg1.toDouble()),
                dy: CGFloat(arg2.toDouble())
            )
        }
        
        
    }
    
    func drawImage(bitmap:ImageBitmap, sx: CGFloat, sy: CGFloat, sWidth: CGFloat, sHeight: CGFloat, dx:CGFloat, dy: CGFloat, dWidth:CGFloat, dHeight:CGFloat) {
        
        let sourceRect = CGRect(x: sx, y: sy, width: sWidth, height: sHeight)
        
        let imgCrop = CGImageCreateWithImageInRect(bitmap.image, sourceRect)!
        
        let bitmapCrop = ImageBitmap(image: imgCrop)
        
        self.drawImage(bitmapCrop, dx: dx, dy: dy, dWidth: dWidth, dHeight: dHeight)
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
            
            CGContextSetRGBStrokeColor(self.context, self.strokeStyleColor.red, self.strokeStyleColor.green, self.strokeStyleColor.blue, 1)
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
    
    private var currentGlobalAlpha:CGFloat = 1.0
    
    var globalAlpha:CGFloat {
        get {
            return currentGlobalAlpha
        }
        set(value) {
            currentGlobalAlpha = value
            CGContextSetAlpha(self.context, value)
        }
    }
    
    func setLineDash(dashes:[CGFloat]?) {
        
        if dashes == nil {
            CGContextSetLineDash(self.context, 0, nil, 0)
        } else {
            CGContextSetLineDash(self.context, 0, dashes!, dashes!.count)
        }
    }
    
}
