//
//  SVGMapLabel.swift
//  SVGMap
//
//  Created by Tomas Srna on 12/01/2017.
//  Copyright © 2017 inloop. All rights reserved.
//

import UIKit

public enum SVGMapLabelAlignment {
    case left
    case right
    case center
    case bottom
    case top
}

public class SVGMapLabel {
    public var title : String
    public var tag : String
    public var color: UIColor?
    public var font : UIFont?
    public var position : CGPoint
    public var uiLabel : UILabel?
    public var alignment : SVGMapLabelAlignment
    public var zoomScaleFactor : CGFloat
    public var minSize : CGFloat

    public init(title : String, tag : String, color: UIColor?, font : UIFont?, position : CGPoint,
                alignment : SVGMapLabelAlignment, scaleAt zoomScaleFactor : CGFloat, minSize : CGFloat = 0) {
        self.title = title
        self.tag = tag
        self.color = color
        self.font = font
        self.position = position
        self.alignment = alignment
        self.zoomScaleFactor = zoomScaleFactor
        self.minSize = minSize
    }
}
