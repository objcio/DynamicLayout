//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

extension UIView {
    func setSubviews<S: Sequence>(_ other: S) where S.Element == UIView {
        let views = Set(other)
        let sub = Set(subviews)
        for v in sub.subtracting(views) {
            v.removeFromSuperview()
        }
        for v in views.subtracting(sub) {
            addSubview(v)
        }
    }
}


extension UILabel {
    convenience init(text: String, size: UIFontTextStyle, multiline: Bool = false) {
        self.init()
        font = UIFont.preferredFont(forTextStyle: size)
        self.text = text
        adjustsFontForContentSizeCategory = true
        if multiline {
            numberOfLines = 0
        }
    }
}

indirect enum Layout {
    case view(UIView, Layout)
    case space(CGFloat, Layout)
    case newline(space: CGFloat, Layout)
    case choice(Layout, Layout)
    case empty
}

extension Layout {
    func apply(containerWidth: CGFloat) -> [UIView] {
        let lines = computeLines(containerWidth: containerWidth, currentX: 0)
        var origin = CGPoint.zero
        var result: [UIView] = []
        for line in lines {
            origin.x = 0
            origin.y += line.space
            var lineHeight: CGFloat = 0
            for element in line.elements {
                switch element {
                case .space(let width):
                    origin.x += width
                case let .view(v, size):
                    result.append(v)
                    v.frame = CGRect(origin: origin, size: size)
                    origin.x += size.width
                    lineHeight = max(lineHeight, size.height)
                }
            }
            origin.y += lineHeight
        }
        return result
    }
}

struct Line {
    enum Element {
        case view(UIView, CGSize)
        case space(CGFloat)
    }
    
    var elements: [Element]
    var space: CGFloat
    
    var width: CGFloat {
        return elements.reduce(0) { $0 + $1.width }
    }
}

extension Line.Element {
    var width: CGFloat {
        switch self {
        case let .view(_, size): return size.width
        case let .space(width): return width
        }
    }
}

extension Layout {
    func computeLines(containerWidth: CGFloat, currentX: CGFloat) -> [Line] {
        var x = currentX
        var current: Layout = self
        var lines: [Line] = []
        var line: Line = Line(elements: [], space: 0)
        while true {
            switch current {
            case let .view(v, rest):
                let availableWidth = containerWidth - x
                let size = v.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
                x += size.width
                line.elements.append(.view(v, size))
                //if x >= containerWidth { return false }
                current = rest
            case let .space(width, rest):
                x += width
                //if x >= containerWidth { return false }
                line.elements.append(.space(width))
                current = rest
            case let .newline(space, rest):
                x = 0
                lines.append(line)
                line = Line(elements: [], space: space)
                current = rest
            case let .choice(first, second):
                var firstLines = first.computeLines(containerWidth: containerWidth, currentX: x)
                firstLines[0].elements.insert(contentsOf: line.elements, at: 0)
                firstLines[0].space += line.space
                let tooWide = firstLines.contains { $0.width >= containerWidth }
                if tooWide {
                    current = second
                } else {
                    return lines + firstLines
                }
            case .empty:
                lines.append(line)
                return lines
            }
        }

    }
}


final class LayoutContainer: UIView {
    private let _layout: Layout
    init(_ layout: Layout) {
        self._layout = layout
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedsLayout), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        let views = _layout.apply(containerWidth: bounds.width)
        setSubviews(views)
    }
}

extension Array where Element == Layout {
    func horizontal(space: CGFloat = 0) -> Layout {
        guard var result = last else { return .empty }
        for l in dropLast().reversed() {
            if space > 0 {
                result = .space(space, result)
            }
            result = l + result
        }
        return result
    }
    
    func vertical(space: CGFloat = 0) -> Layout {
        guard var result = last else { return .empty }
        for l in dropLast().reversed() {
            result = l + .newline(space: space, result)
        }
        return result
    }
}

func +(lhs: Layout, rhs: Layout) -> Layout {
    switch lhs {
    case let .view(v, remainder): return .view(v, remainder+rhs)
    case let .space(w, r):
        return .space(w, r + rhs)
    case let .newline(space, r):
        return .newline(space: space, r + rhs)
    case let .choice(l, r):
        return .choice(l + rhs, r + rhs)
    case .empty:
        return rhs
    }
}

extension UIView {
    var layout: Layout {
        return .view(self, .empty)
    }
}

extension Layout {
    func or(_ other: Layout) -> Layout {
        return .choice(self, other)
    }
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel(text: "Building a Layout Library", size: .headline, multiline: true)
        let episodeNumber = UILabel(text: "Episode 123", size: .body)
        let episodeDate = UILabel(text: "September 23", size: .body)
        
        let horizontal: Layout = [episodeNumber.layout, episodeDate.layout].horizontal(space: 20)
        let vertical = [episodeNumber.layout, episodeDate.layout].vertical()
        let layout = [
            titleLabel.layout, horizontal.or(vertical)
        ].vertical(space: 20)
        
        let container = LayoutContainer(layout)
        container.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(container)
        view.addConstraints([
            container.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
       
    }
}

