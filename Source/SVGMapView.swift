//
//  SVGMapView.swift
//  SVGMap
//
//  Created by Tomas Srna on 12/01/2017.
//  Copyright © 2017 inloop. All rights reserved.
//

import UIKit

public class SVGMapView: UIView, SVGMapDataDelegate {

    @IBInspectable
    public var mapName : String? {
        didSet {
            clearAll()
            setMapNeedsLoad()
            setNeedsDisplay()
        }
    }

    public var fillColor = UIColor.gray { didSet { setNeedsDisplay() } }
    public var strokeColor = UIColor.black { didSet { setNeedsDisplay() } }
    public var insets = CGRect.zero { didSet { setNeedsDisplay() } }

    public var fillColors = [String:UIColor]() { didSet { setNeedsDisplay() } }
    public var strokeColors = [String:UIColor]() { didSet { setNeedsDisplay() } }

    public fileprivate(set) var layers = [String:CALayer]()

    fileprivate var originalPaths = [CALayer:UIBezierPath]()
    public fileprivate(set) var svg : SVGMapData?

    fileprivate var boundsWithInsets : CGRect {
        return CGRect(x: bounds.origin.x + insets.origin.x, y: bounds.origin.y + insets.origin.y,
                      width: bounds.size.width - (insets.size.width + insets.origin.x),
                      height: bounds.size.height - (insets.size.height + insets.origin.y))
    }

    fileprivate var mapNeedsLoad = false

    public func setMapNeedsLoad() {
        mapNeedsLoad = true
    }

    weak var delegate : SVGMapViewDelegate?

    // MARK: Scale

    /**
     * 3 types of scale not to be confused in the context of this class:
     * - scale:           Ratio of frame to svg original size
     * - zoomScale:       UIScrollView's zoom scale
     * - zoomScaleFactor: Not really a scale, just the speed of zooming
     * - screenScale:     Screen scale according to device (@2x, @3x, etc.). Result of UIScreen.main.scale
     */

    fileprivate var scaleHorizontal : CGFloat? {
        guard let svg = svg else {
            return nil
        }
        return boundsWithInsets.size.width / svg.bounds.size.width
    }

    fileprivate var scaleVertical : CGFloat? {
        guard let svg = svg else {
            return nil
        }
        return boundsWithInsets.size.height / svg.bounds.size.height
    }

    fileprivate var scale : CGFloat? {
        guard let scaleHorizontal = scaleHorizontal, let scaleVertical = scaleVertical else {
            return nil
        }
        return [scaleHorizontal, scaleVertical].min()
    }

    // MARK: Draw

    fileprivate func loadMap() {
        guard let mapName = mapName else {
            return
        }

        self.svg = SVGMapData(file: mapName, delegate: self)

        guard let svg = self.svg else {
            return
        }

        // TODO: Not sure if we need this
//        positionLabels()

        let mapTransform = self.mapTransform // Copying just not to call computation of property every time
        originalPaths.removeAll()
        layers.removeAll()

        for pathElement in svg.pathElements {
            guard let path = pathElement.path, let scaledPath = path.copy() as? UIBezierPath else {
                continue
            }

            scaledPath.apply(mapTransform)

            let shapeLayer = CAShapeLayer()
            shapeLayer.path = scaledPath.cgPath

            // Sometime in the far future, we could make this a configurable parameter
            shapeLayer.lineWidth = 0.4

            if pathElement.fill {
                if let pathElementId = pathElement.id, let pathFillColor = fillColors[pathElementId] {
                    shapeLayer.fillColor = pathFillColor.cgColor
                } else {
                    shapeLayer.fillColor = fillColor.cgColor
                }
            } else {
                shapeLayer.fillColor = UIColor.clear.cgColor
            }

            if let pathElementId = pathElement.id, let pathStrokeColor = strokeColors[pathElementId] {
                shapeLayer.strokeColor = pathStrokeColor.cgColor
            } else {
                shapeLayer.strokeColor = strokeColor.cgColor
            }

            layer.insertSublayer(shapeLayer, at: 0)

            if let id = pathElement.id {
                layers[id] = shapeLayer
            }

            originalPaths[shapeLayer] = path
        }
    }

    // MARK: UIView overrides

    override public func draw(_ rect: CGRect) {
        if mapNeedsLoad {
            loadMap()
            mapNeedsLoad = false
        }

        guard let sublayers = layer.sublayers else {
            return
        }

        for sublayer in sublayers {
            if let originalPath = originalPaths[sublayer],
                let scaledPath = originalPath.copy() as? UIBezierPath,
                let shapeLayer = sublayer as? CAShapeLayer {
                scaledPath.apply(mapTransform)
                shapeLayer.path = scaledPath.cgPath
            }
        }

        positionLabels()
    }

    fileprivate func clearLayers() {
        layer.sublayers = nil
    }

    // MARK: Labels
    public fileprivate(set) var labels = [SVGMapLabel]()

    public func clearAll() {
        clearLayers()
        clearLabels()
    }

    public func addLabel(label : SVGMapLabel) {
        let uiLabel = UILabel()
        uiLabel.text = label.title
        uiLabel.numberOfLines = 2
        if let font = label.font {
            uiLabel.font = font
        }
        if let color = label.color {
            uiLabel.textColor = color
        }
        addSubview(uiLabel)
        label.uiLabel = uiLabel
        positionLabel(label: label)
        labels.append(label)
    }

    public func clearLabels() {
        labels.removeAll()
    }

    fileprivate func positionLabel(label: SVGMapLabel, withScale zoomScale : CGFloat = 1) {
        guard let uiLabel = label.uiLabel else {
            return
        }

        // This is not ideal, but otherwise it won't size to fit
        uiLabel.frame = CGRect(x: 0, y: 0,
                               width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
        uiLabel.sizeToFit()

        var position = label.position.applying(mapTransform)

        switch label.alignment {
        case .left:
            position.y -= uiLabel.frame.size.height / 2
        case .right:
            position.x -= uiLabel.frame.size.width
            position.y -= uiLabel.frame.size.height / 2
        case .center:
            position.x -= uiLabel.frame.size.width / 2
            position.y -= uiLabel.frame.size.height / 2
        case .top:
            position.x -= uiLabel.frame.size.width / 2
        case .bottom:
            position.x -= uiLabel.frame.size.width / 2
            position.y -= uiLabel.frame.size.height
        }

        if label.minSize > shorterSideZoomed(withScale: zoomScale) {
            label.uiLabel?.isHidden = true
        } else {
            label.uiLabel?.isHidden = false
        }

        uiLabel.frame = CGRect(x: position.x, y: position.y,
                               width: uiLabel.frame.size.width, height: uiLabel.frame.size.height)
    }

    fileprivate func positionLabels(withScale zoomScale : CGFloat = 1) {
        labels.forEach({ positionLabel(label: $0, withScale: zoomScale) })
    }

    // MARK: Zooming
    func zoomLabels(withScale zoomScale: CGFloat, screenScale: CGFloat) {
        for label in labels {
            guard let uiLabel = label.uiLabel, let font = label.font else {
                continue
            }
            if label.zoomScaleFactor > 0 {
                uiLabel.font = uiLabel.font.withSize((font.pointSize / zoomScale) * pow(zoomScale, label.zoomScaleFactor))
                uiLabel.contentScaleFactor = zoomScale * screenScale * pow(zoomScale, label.zoomScaleFactor)
            } else {
                uiLabel.font = uiLabel.font.withSize(font.pointSize / zoomScale)
                uiLabel.contentScaleFactor = zoomScale * screenScale
            }
            positionLabel(label: label, withScale: zoomScale)
        }
    }

    fileprivate func shorterSideZoomed(withScale zoomScale: CGFloat) -> CGFloat {
        let shorterSide = [bounds.size.width, bounds.size.height].min() ?? 0
        return shorterSide * zoomScale
    }

    // MARK: Transform
    var mapTransform : CGAffineTransform {
        var mt = CGAffineTransform.identity
        guard let scale = scale, let svg = svg else {
            return mt
        }

        // Move to SVG origin
        mt = mt.translatedBy(x: -svg.bounds.origin.x, y: -svg.bounds.origin.y)

        // Scale (scale calculates already with insets)
        mt = mt.scaledBy(x: scale, y: scale)

        // Move to center (insets are obeyed because of above)
        mt = mt.translatedBy(x: (bounds.size.width - svg.bounds.size.applying(mt).width) / 2,
                             y: (bounds.size.height - svg.bounds.size.applying(mt).height) / 2)

        return mt
    }

    // MARK: SVGMapDataDelegate
    public func mapDidLoad(svg: SVGMapData) {
        setNeedsDisplay()
    }

    // MARK: Touch
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let scaledLocation = location.applying(mapTransform.inverted())
            guard let svg = self.svg else {
                continue
            }
            var id : String?
            for pathElement in svg.pathElements {
                if let path = pathElement.path, path.contains(scaledLocation) {
                    id = pathElement.id
                }
            }
            var lay : CALayer?
            if let sublayers = layer.sublayers {
                for sublayer in sublayers {
                    if let shapeLayer = sublayer as? CAShapeLayer, let sp = shapeLayer.path {
                        if sp.contains(location) {
                            lay = sublayer
                            break
                        }
                    }

                }
            }
            if let lay = lay, let id = id {
                delegate?.didSelectLayer(id, layer: lay)
            }
        }
    }

}

public protocol SVGMapViewDelegate: class {
    func didSelectLayer(_ name: String?, layer: CALayer?)
}
