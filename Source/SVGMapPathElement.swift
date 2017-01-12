//
//  SVGMapPathElement.swift
//  SVGMap
//
//  Created by Tomas Srna on 12/01/2017.
//  Copyright © 2017 inloop. All rights reserved.
//

import UIKit

public class SVGMapPathElement {
    public var title: String?
    public var id: String?
    public var className: String?
    public var path: UIBezierPath?
    public var transform: CGAffineTransform?
    public var fill = false

    // MARK: Points
    fileprivate var minPoint = CGPoint(x: Double.infinity, y: Double.infinity)
    fileprivate var maxPoint = CGPoint(x: -Double.infinity, y: -Double.infinity)

    fileprivate var lastPoint = CGPoint.zero {
        didSet {
            minPoint = CGPoint(x: [minPoint.x, lastPoint.x].min()!, y: [minPoint.y, lastPoint.y].min()!)
            maxPoint = CGPoint(x: [maxPoint.x, lastPoint.x].max()!, y: [maxPoint.y, lastPoint.y].max()!)
        }
    }

    public var midPoint : CGPoint {
        let width = maxPoint.x - minPoint.x
        let height = maxPoint.y - minPoint.y
        return CGPoint(x: minPoint.x + width/2, y: minPoint.y + height/2)
    }

    public init?(attributes : [String:String]) {
        title = attributes["title"]
        id = attributes["id"]
        className = attributes["className"]

        if let transform = attributes["transform"] {
            self.transform = SVGMapUtils.parse(transform: transform)
        }
        if let pathData = attributes["d"] {
            parse(pathData: pathData)
        }
    }

    // MARK: Parse
    fileprivate func parse(pathData : String) {
        path = UIBezierPath()

        var command : UnicodeScalar = "\0"
        var value = ""

        for character in pathData.unicodeScalars {
            if CharacterSet.letters.contains(character) && character != "e" {
                if value.characters.count > 0 {
                    execute(command: command, value: value)
                }
                value = ""
                command = character
                continue
            }
            value.append(String(character))
        }
        execute(command: command, value: value)
    }

    // MARK: Execute
    fileprivate func execute(command: UnicodeScalar, value: String) {
        let coordinates = SVGMapUtils.parse(points: value)

        if coordinates.count == 0 && command != "z" && command != "Z" {
            return
        }

        switch command {
        case "M": executeMove(to: coordinates, absolute: true)
        case "m": executeMove(to: coordinates, absolute: false)
        case "L": executeLine(to: coordinates, absolute: true)
        case "l": executeLine(to: coordinates, absolute: false)

        case "H": executeHorizontalLine(to: coordinates, absolute: true)
        case "h": executeHorizontalLine(to: coordinates, absolute: false)
        case "V": executeVerticalLine(to: coordinates, absolute: true)
        case "v": executeVerticalLine(to: coordinates, absolute: false)

        case "C": executeCurve(to: coordinates, absolute: true)
        case "c": executeCurve(to: coordinates, absolute: false)

        case "S": executeQuadraticCurve(to: coordinates, absolute: true)
        case "s": executeQuadraticCurve(to: coordinates, absolute: false)

        case "Z": fallthrough
        case "z":
            path?.close()
            fill = true

        default: return
        }
    }

    fileprivate func executeMove(to coordinates: [Double], absolute : Bool, line: Bool = false) {
        for i in 0..<coordinates.count/2 {
            if i * 2 + 2 > coordinates.count {
                return
            }

            let p = CGPoint(x: coordinates[i*2], y: coordinates[i*2+1])
            if absolute {
                lastPoint = p
            } else {
                lastPoint = CGPoint(x: p.x + lastPoint.x, y: p.y + lastPoint.y)
            }

            if line {
                path?.addLine(to: lastPoint)
            } else {
                path?.move(to: lastPoint)
            }
        }
    }

    fileprivate func executeLine(to coordinates: [Double], absolute : Bool) {
        executeMove(to: coordinates, absolute: absolute, line: true)
    }

    fileprivate func executeHorizontalLine(to coordinates : [Double], absolute : Bool) {
        for i in 0..<coordinates.count {
            if i + 1 > coordinates.count {
                return
            }
            if absolute {
                lastPoint = CGPoint(x: CGFloat(coordinates[i]), y: lastPoint.y)
            } else {
                lastPoint = CGPoint(x: CGFloat(coordinates[i]) + lastPoint.x, y: lastPoint.y)
            }
            path?.addLine(to: lastPoint)
        }
    }

    fileprivate func executeVerticalLine(to coordinates : [Double], absolute : Bool) {
        for i in 0..<coordinates.count {
            if i + 1 > coordinates.count {
                return
            }
            if absolute {
                lastPoint = CGPoint(x: lastPoint.x, y: CGFloat(coordinates[i]))
            } else {
                lastPoint = CGPoint(x: lastPoint.x, y: CGFloat(coordinates[i]) + lastPoint.y)
            }
            path?.addLine(to: lastPoint)
        }
    }

    fileprivate func executeCurve(to coordinates: [Double], absolute: Bool) {
        for i in 0..<coordinates.count/6 {
            if i * 6 + 6 > coordinates.count {
                return
            }

            let c1 = CGPoint(x: coordinates[i*6], y: coordinates[i*6+1])
            let c2 = CGPoint(x: coordinates[i*6+2], y: coordinates[i*6+3])
            let p = CGPoint(x: coordinates[i*6+4], y: coordinates[i*6+5])

            if absolute {
                lastPoint = CGPoint(x: p.x, y: p.y)
                path?.addCurve(to: lastPoint, controlPoint1: c1, controlPoint2: c2)
            } else {
                path?.addCurve(to: CGPoint(x: lastPoint.x + p.x, y: lastPoint.y + p.y),
                               controlPoint1: CGPoint(x: c1.x + lastPoint.x, y: c1.y + lastPoint.y),
                               controlPoint2: CGPoint(x: c2.x + lastPoint.x, y: c2.y + lastPoint.y))
                lastPoint = CGPoint(x: p.x + lastPoint.x, y: p.y + lastPoint.y)
            }
        }
    }

    fileprivate func executeQuadraticCurve(to coordinates: [Double], absolute: Bool) {
        for i in 0..<coordinates.count/8 {
            if i * 4 + 4 > coordinates.count {
                return
            }

            let c = CGPoint(x: coordinates[i*4], y: coordinates[i*4+1])
            let p = CGPoint(x: coordinates[i*4+2], y: coordinates[i*4+3])

            if absolute {
                lastPoint = CGPoint(x: p.x, y: p.y)
                path?.addQuadCurve(to: lastPoint, controlPoint: c)
            } else {
                path?.addQuadCurve(to: CGPoint(x: p.x + lastPoint.x, y: p.y + lastPoint.y),
                                   controlPoint: CGPoint(x: c.x + lastPoint.x, y: c.y + lastPoint.y))
                lastPoint = CGPoint(x: p.x + lastPoint.x, y: p.y + lastPoint.y)
            }
        }
    }
}
