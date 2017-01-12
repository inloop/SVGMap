//
//  SVGMapUtils.swift
//  SVGMap
//
//  Created by Tomas Srna on 12/01/2017.
//  Copyright © 2017 inloop. All rights reserved.
//

import Foundation

internal class SVGMapUtils {
    public static func parse(transform str: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        if str.characters.count > 0 {
            transform = transform.concatenating(parse(matrix: str))
            transform = transform.concatenating(parse(translate: str))
        }
        return transform
    }

    public static func parse(translate str: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        let nsStr = str as NSString

        do {
            let patternMatrix = "matrix\\((.*)\\)"
            let regexMatrix = try NSRegularExpression(pattern: patternMatrix, options: .caseInsensitive)
            let matches = regexMatrix.matches(in: str, options: .withoutAnchoringBounds,
                                              range: NSRange(location: 0, length: nsStr.length))
            if matches.count > 0 {
                let entry = matches[0]
                let parameters = nsStr.substring(with: entry.rangeAt(1))
                let coordinates = parse(points: parameters)

                if coordinates.count == 6 {
                    transform = CGAffineTransform(a: CGFloat(coordinates[0]), b: CGFloat(coordinates[1]),
                                                  c: CGFloat(coordinates[2]), d: CGFloat(coordinates[3]),
                                                  tx: CGFloat(coordinates[4]), ty: CGFloat(coordinates[5]))
                }
            }

        } catch let error {
            print(error.localizedDescription)
        }

        return transform
    }

    public static func parse(matrix str: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        let nsStr = str as NSString

        do {
            let patternMatrix = "translate\\((.*)\\)"
            let regexMatrix = try NSRegularExpression(pattern: patternMatrix, options: .caseInsensitive)
            let matches = regexMatrix.matches(in: str, options: .withoutAnchoringBounds,
                                              range: NSRange(location: 0, length: nsStr.length))
            if matches.count > 0 {
                let entry = matches[0]
                let parameters = nsStr.substring(with: entry.rangeAt(1))
                let coordinates = parse(points: parameters)

                if coordinates.count == 2 {
                    transform = CGAffineTransform(translationX: CGFloat(coordinates[0]), y: CGFloat(coordinates[1]))
                } else if coordinates.count == 1 {
                    transform = CGAffineTransform(translationX: CGFloat(coordinates[0]), y: 0)
                }
            }

        } catch let error {
            print(error.localizedDescription)
        }

        return transform
    }

    public static func parse(points : String) -> [Double] {
        let scanner = Scanner(string: points)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "\n, ")
        var ret = [Double]()
        var val : Double = 0
        while scanner.scanDouble(&val) {
            ret.append(val)
        }
        return ret
    }
}
