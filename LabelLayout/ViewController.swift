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
    convenience init(text: String, size: UIFont.TextStyle, multiline: Bool = false) {
        self.init()
        font = UIFont.preferredFont(forTextStyle: size)
        self.text = text
        adjustsFontForContentSizeCategory = true
        if multiline {
            numberOfLines = 0
        }
    }
}

enum Width {
    case absolute(CGFloat)
    case flexible(min: CGFloat)
    
    var min: CGFloat {
        switch self {
        case let .absolute(x): return x
        case let .flexible(min: x): return x
        }
    }
    
    var isFlexible: Bool {
        switch self {
        case .absolute: return false
        case .flexible: return true
        }
    }
    
    func absolute(flexibleSpace: CGFloat) -> CGFloat {
        switch self {
        case let .absolute(w): return w
        case let .flexible(min): return min + flexibleSpace
        }
    }
}

indirect enum Layout {
    case view(UIView, Layout)
    case space(Width, Layout)
    case box(contents: Layout, wrapper: UIView?, Layout)
    case newline(space: CGFloat, Layout)
    case choice(Layout, Layout)
    case empty
}

extension Layout {
    func apply(containerWidth: CGFloat) -> [UIView] {
        let lines = computeLines(containerWidth: containerWidth, currentX: 0)
        return lines.apply(containerWidth: containerWidth, startAt: .zero)
    }
}

extension Array where Element == Line {
    func apply(containerWidth: CGFloat, startAt: CGPoint) -> [UIView] {
        var origin = startAt
        var result: [UIView] = []
        for line in self {
            origin.x = startAt.x
            origin.y += line.space
            let availableSpace = containerWidth - line.minWidth
            let flexibleSpace = availableSpace / CGFloat(line.numberOfFlexibleSpaces)
            var lineHeight: CGFloat = 0
            for element in line.elements {
                switch element {
                case let .box(contents, nil):
                    let width = element.minWidth
                    let views = contents.apply(containerWidth: width, startAt: origin)
                    origin.x += width
                    let height = (views.map { $0.frame.maxY }.max() ?? origin.y) - origin.y
                    lineHeight = Swift.max(lineHeight, height)
                    result.append(contentsOf: views)
                case let .box(contents, wrapper?):
                    let width = element.minWidth
                    let margins = wrapper.layoutMargins.left + wrapper.layoutMargins.right
                    let start = CGPoint(x: wrapper.layoutMargins.left, y: wrapper.layoutMargins.top)
                    let subviews = contents.apply(containerWidth: width - margins, startAt: start)
                    wrapper.setSubviews(subviews)
                    let contentMaxY = subviews.map { $0.frame.maxY }.max() ?? 0
                    let size = CGSize(width: width, height: contentMaxY + wrapper.layoutMargins.bottom)
                    wrapper.frame = CGRect(origin: origin, size: size)

                    origin.x += size.width
                    lineHeight = Swift.max(lineHeight, size.height)
                    result.append(wrapper)
                case .space(let width):
                    origin.x += width.absolute(flexibleSpace: flexibleSpace)
                case let .view(v, size):
                    result.append(v)
                    v.frame = CGRect(origin: origin, size: size)
                    origin.x += size.width
                    lineHeight = Swift.max(lineHeight, size.height)
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
        case space(Width)
        case box([Line], wrapper: UIView?)
    }
    
    var elements: [Element]
    var space: CGFloat
    
    var minWidth: CGFloat {
        return elements.reduce(0) { $0 + $1.minWidth }
    }
    
    var numberOfFlexibleSpaces: Int {
        return elements.filter { $0.isFlexible }.count
    }
}

extension Line.Element {
    var isFlexible: Bool {
        switch self {
        case .view: return false
        case .box: return false
        case let .space(width): return width.isFlexible
        }
    }
    
    var minWidth: CGFloat {
        switch self {
        case let .view(_, size): return size.width
        case let .box(lines, wrapper):
            let margins = (wrapper?.layoutMargins).map { $0.left + $0.right } ?? 0
            return (lines.map { $0.minWidth }.max() ?? 0) + margins
        case let .space(width): return width.min
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
                x += width.min
                //if x >= containerWidth { return false }
                line.elements.append(.space(width))
                current = rest
            case let .box(contents, wrapper, rest):
                let margins = (wrapper?.layoutMargins).map { $0.left + $0.right } ?? 0
                let availableWidth = containerWidth - x - margins
                let lines = contents.computeLines(containerWidth: availableWidth, currentX: x)
                let result = Line.Element.box(lines, wrapper: wrapper)
                x += result.minWidth
                line.elements.append(result)
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
                let tooWide = firstLines.contains { $0.minWidth >= containerWidth }
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedsLayout), name: UIContentSizeCategory.didChangeNotification, object: nil)
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
    func horizontal(space: Width? = nil) -> Layout {
        guard var result = last else { return .empty }
        for l in dropLast().reversed() {
            if let width = space {
                result = .space(width, result)
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
    case let .view(v, remainder):
        return .view(v, remainder+rhs)
    case let .box(contents, wrapper, remainder):
        return .box(contents: contents, wrapper: wrapper, remainder + rhs)
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
    
    func box(wrapper: UIView? = nil) -> Layout {
        return .box(contents: self, wrapper: wrapper, .empty)
    }
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel(text: "Building a Layout Library", size: .headline, multiline: true).layout
        
        let episodeNumberTitle = UILabel(text: "Episode", size: .headline).layout
        let episodeNumber = UILabel(text: "123", size: .body).layout
        let numberWrapper = UIView()
        numberWrapper.backgroundColor = .red
        numberWrapper.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        numberWrapper.layer.cornerRadius = 10
        
        let episodeDateTitle = UILabel(text: "Date", size: .headline).layout
        let episodeDate = UILabel(text: "September 23", size: .body).layout
        let dateWrapper = UIView()
        dateWrapper.backgroundColor = .green
        dateWrapper.layoutMargins = .zero
        
        let number = [episodeNumberTitle, episodeNumber].vertical().box(wrapper: numberWrapper)
        let date = [episodeDateTitle, episodeDate].vertical().box(wrapper: dateWrapper)
        
        let blueBox = UIView()
        blueBox.backgroundColor = .blue
        blueBox.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        blueBox.layer.cornerRadius = 10
        
        let horizontal: Layout = [number, date].horizontal(space: .flexible(min: 20))
        let vertical = [number, date].vertical(space: 10)
        let layout = [
            titleLabel, horizontal.or(vertical).box(wrapper: blueBox)
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

