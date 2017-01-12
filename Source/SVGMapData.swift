//
//  SVGMapData.swift
//  SVGMap
//
//  Created by Tomas Srna on 12/01/2017.
//  Copyright © 2017 inloop. All rights reserved.
//

import UIKit
import Darwin

public class SVGMapData : NSObject, XMLParserDelegate {
    fileprivate var file : String

    public fileprivate(set) var bounds : CGRect
    public fileprivate(set) var pathElements = [SVGMapPathElement]()

    fileprivate var transforms = [CGAffineTransform]()
    fileprivate var currentTransform = CGAffineTransform.identity

    public fileprivate(set) var loaded = false

    var delegate: SVGMapDataDelegate?

    init?(file : String, delegate: SVGMapDataDelegate?) {
        self.bounds = CGRect.zero
        self.file = file
        self.delegate = delegate

        super.init()

        do {
            if let filePath = Bundle.main.path(forResource: file, ofType: "svg") {
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
                computeBounds()
            }
        } catch let error {
            print(error.localizedDescription)
            return nil
        }
    }

    // MARK: XML Parsing
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "path":
            guard let element = SVGMapPathElement(attributes: attributeDict) else {
                return
            }
            pathElements.append(element)
            var t = currentTransform
            if let attTransform = attributeDict["transform"] {
                let pathTransform = SVGMapUtils.parse(transform: attTransform)
                t = pathTransform.concatenating(currentTransform)
            }
            element.path?.apply(t)
        case "g":
            var t = CGAffineTransform.identity
            if let attTransform = attributeDict["transform"] {
                t = SVGMapUtils.parse(transform: attTransform)
            }
            currentTransform = t.concatenating(currentTransform)
            transforms.append(currentTransform)
        default: break
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "g" {
            transforms.removeLast()
            if let lastTransform = transforms.last {
                currentTransform = lastTransform
            } else {
                currentTransform = CGAffineTransform.identity
            }
        }
    }

    public func parserDidEndDocument(_ parser: XMLParser) {
        loaded = true
        delegate?.mapDidLoad(svg: self)
    }

    // MARK: Compute bounds

    private func computeBounds() {
        bounds.origin.x = CGFloat(DBL_MAX)
        bounds.origin.y = CGFloat(DBL_MAX)
        var maxx = CGFloat(-DBL_MAX)
        var maxy = CGFloat(-DBL_MAX)

        for path in pathElements.flatMap({ $0.path }) {
            let b = path.cgPath.boundingBox

            if b.origin.x < bounds.origin.x {
                bounds.origin.x = b.origin.x
            }
            if b.origin.y < bounds.origin.y {
                bounds.origin.y = b.origin.y
            }
            if b.origin.x + b.size.width > maxx {
                maxx = b.origin.x + b.size.width
            }
            if b.origin.y + b.size.height > maxy {
                maxy = b.origin.y + b.size.height
            }
        }

        bounds.size.width = maxx - bounds.origin.x
        bounds.size.height = maxy - bounds.origin.y
    }
}


public protocol SVGMapDataDelegate {
    func mapDidLoad(svg : SVGMapData)
}
