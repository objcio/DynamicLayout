//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

enum Width {
    case basedOnContents
    case flexible(min: CGFloat)
    case absolute(CGFloat)
}

extension UIEdgeInsets {
    var width: CGFloat { return left + right }
    var height: CGFloat { return top + bottom }
}

enum Element {
    case view(UIView)
    case space
    case inlineBox(wrapper: UIView?, Layout)
    
    func width(_ width: Width, availableWidth: CGFloat) -> Line.BlockWidth {
        switch width {
        case let .absolute(x):
            return .absolute(x)
        case let .flexible(min: x):
            return .flexible(min: x)
        case .basedOnContents:
            switch self {
            case let .inlineBox(wrapper, layout):
                let contentWidth = layout.computeLines(containerWidth: availableWidth, startingAt: 0)?.map { $0.minWidth }.max() ?? 0
                return .absolute(contentWidth + (wrapper?.layoutMargins.width ?? 0))
            case let .view(view):
                let size = view.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
                return .absolute(size.width)
            case .space:
                return .absolute(0)
            }
        }
    }
}

indirect enum Layout {
    case element(Element, Width, Layout)
    case newline(space: CGFloat, Layout)
    case choice(Layout, Layout)
    case empty

    func apply(containerWidth: CGFloat) -> Set<UIView> {
        let lines = computeLines(containerWidth: containerWidth, startingAt: 0) ?? []
        return lines.apply(containerWidth: containerWidth, origin: .zero)
    }
}

struct Line {
    enum Block {
        case inlineBox(wrapper: UIView?, [Line])
        case view(UIView)
        case space
    }
    
    enum BlockWidth {
        case absolute(CGFloat)
        case flexible(min: CGFloat)
        
        var isFlexible: Bool {
            guard case .flexible = self else { return false }
            return true
        }
        
        func absolute(flexibleSpace: CGFloat) -> CGFloat {
            switch self {
            case let .absolute(w): return w
            case let .flexible(min: min): return min + flexibleSpace
            }
        }

        var min: CGFloat {
            switch self {
            case let .absolute(w): return w
            case let .flexible(w): return w
            }
        }
    }
        
    var leadingSpace: CGFloat
    var elements: [(Block, BlockWidth)]

    var minWidth: CGFloat {
        return elements.reduce(0) { result, el in
            result + el.1.min
        }
    }

    var numberOfFlexibleElements: Int {
        return elements.lazy.filter { $0.1.isFlexible }.count
    }
    
    mutating func join(_ other: Line) {
        elements += other.elements
    }
}


extension Sequence where Element: UIView {
    var maxY: CGFloat {
        return map { $0.frame.maxY }.max() ?? 0
    }
}

extension Array where Element == Line {
    func apply(containerWidth: CGFloat, origin: CGPoint) -> Set<UIView> {
        var result: Set<UIView> = []
        var y: CGFloat = origin.y
        for line in self {
            y += line.leadingSpace
            let flexibleSpace = (containerWidth - line.minWidth) / CGFloat(line.numberOfFlexibleElements)
            var x: CGFloat = origin.x
            var lineHeight: CGFloat = 0
            
            for (block, width) in line.elements {
                let origin = CGPoint(x: x, y: y)
                let absWidth = width.absolute(flexibleSpace: flexibleSpace)
                switch block {
                case let .view(view):
                    let height = view.sizeThatFits(CGSize(width: absWidth, height: .greatestFiniteMagnitude)).height
                    let frame = CGRect(origin: origin, size: CGSize(width: absWidth, height: height))
                    view.frame = frame.integral
                    lineHeight = Swift.max(lineHeight, frame.height)
                    result.insert(view)
                case let .inlineBox(nil, lines):
                    let nested = lines.apply(containerWidth: absWidth, origin: origin)
                    result.formUnion(nested)
                    lineHeight = Swift.max(lineHeight, nested.maxY - y)
                case let .inlineBox(wrapper?, lines):
                    let width = absWidth - wrapper.layoutMargins.width
                    let nestedOrigin = CGPoint(x: wrapper.layoutMargins.left, y: wrapper.layoutMargins.top)
                    let subviews = lines.apply(containerWidth: absWidth - width, origin: nestedOrigin)
                    wrapper.frame = CGRect(origin: origin, size: CGSize(width: absWidth, height: subviews.maxY + wrapper.layoutMargins.height))
                    wrapper.setSubviews(subviews)
                    result.insert(wrapper)
                    lineHeight = Swift.max(lineHeight, wrapper.frame.height)
                case .space:
                    break
                }
                x += absWidth
            }
            y += lineHeight
        }
        return result
    }
}

extension Layout {
    fileprivate func computeLines(containerWidth: CGFloat, startingAt start: CGFloat, cancelOnOverflow: Bool = false) -> [Line]? {
        var lines: [Line] = [Line(leadingSpace: 0, elements: [])]
        var line: Line {
            get { return lines[lines.endIndex-1] }
            set { lines[lines.endIndex-1] = newValue }
        }
        var el = self
        var currentWidth = start
        while true {
            switch el {
            case let .element(element, width, next):
                let blockWidth = element.width(width, availableWidth: containerWidth - currentWidth)
                currentWidth += blockWidth.min
                switch element {
                case let .view(view):
                    line.elements.append((.view(view), blockWidth))
                case .space:
                    line.elements.append((.space, blockWidth))
                case let .inlineBox(wrapper, layout):
                    // todo: we compute this twice!
                    let box = layout.computeLines(containerWidth: containerWidth - currentWidth, startingAt: 0)!
                    line.elements.append((.inlineBox(wrapper: wrapper, box), blockWidth))
                }
                if cancelOnOverflow && currentWidth > containerWidth {
                    return nil
                }
                el = next
            case let .newline(space, next):
                currentWidth = 0
                lines.append(Line(leadingSpace: space, elements: []))
                el = next
            case let .choice(first, second):
                if let firstLayout = first.computeLines(containerWidth: containerWidth, startingAt: currentWidth, cancelOnOverflow: true) {
                    guard let cont = firstLayout.first else { return lines}
                    line.join(cont)
                    lines.append(contentsOf: firstLayout.dropFirst())
                    return lines
                } else {
                    el = second
                }
            case .empty:
                return lines
            }
        }
    }
}

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

final class LayoutView: UIView {
    private let _layout: Layout
    
    init(_ layout: Layout) {
        self._layout = layout
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedsLayout), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        setSubviews(_layout.apply(containerWidth: bounds.width))
    }
}

extension Array where Element == Layout {
    func horizontal(minSpacing: CGFloat? = nil) -> Layout {
        guard let v = last else { return .empty }
        var result = v
        for e in reversed().dropFirst() {
            if let s = minSpacing {
                result = .element(.space, .flexible(min: s), result)
            }
            result = e + result
        }
        return result
    }

    func vertical(space: CGFloat = 0) -> Layout {
        var result = Layout.empty
        for e in reversed() {
            result = e + .newline(space: space, result)
        }
        return result
    }
}

func +(lhs: Layout, rhs: Layout) -> Layout {
    switch lhs {
    case let .choice(l, r): return .choice(l + rhs, r + rhs)
    case .empty: return rhs
    case let .newline(s,x): return .newline(space: s, x + rhs)
    case let .element(v, w, x): return .element(v, w, x + rhs)
    }
}

extension UIView {
    var layout: Layout {
        return .element(.view(self), .basedOnContents, .empty)
    }
}

extension Layout {
    func or(_ other: Layout) -> Layout {
        return .choice(self, other)
    }
    
    func inlineBox(width: Width = .basedOnContents, wrapper: UIView? = nil) -> Layout {
        return .element(.inlineBox(wrapper: wrapper, self), width, .empty)
    }
}

class ViewController: UIViewController {
    var token: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.text = "Building a Layout Library"
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        
        let episodeNumber = UILabel()
        episodeNumber.text = "Episode 123"
        episodeNumber.font = UIFont.preferredFont(forTextStyle: .caption1)
        episodeNumber.adjustsFontForContentSizeCategory = true

        
        let episodeDate = UILabel()
        episodeDate.text = "September 23"
        episodeDate.font = UIFont.preferredFont(forTextStyle: .caption1)
        episodeDate.adjustsFontForContentSizeCategory = true
        
        let episodeDuration = UILabel()
        episodeDuration.text = "23 min"
        episodeDuration.font = UIFont.preferredFont(forTextStyle: .caption1)
        episodeDuration.adjustsFontForContentSizeCategory = true
        
        let roundedBox = UIView()
        roundedBox.layer.cornerRadius = 5
        roundedBox.backgroundColor = .lightGray
        
        let synopsis = UILabel()
        synopsis.text = "We start building a descriptive layout library that can be used to support the wide range of screen widths and font size options available on iOS today."
        synopsis.font = UIFont.preferredFont(forTextStyle: .body)
        synopsis.numberOfLines = 0
        synopsis.adjustsFontForContentSizeCategory = true

        let metadata = [episodeDate, episodeDuration].map { $0.layout }.vertical(space: 0)
        let secondLine: Layout = [episodeNumber.layout, metadata.inlineBox(wrapper: roundedBox)].horizontal(minSpacing: 20)
        let layout = [titleLabel.layout, secondLine.or([episodeNumber.layout, metadata].vertical()), synopsis.layout].vertical(space: 15)

        let container = LayoutView(layout)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: container.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

