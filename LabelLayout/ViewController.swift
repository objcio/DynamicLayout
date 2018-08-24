//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

indirect enum Layout {
    case view(UIView, Layout)
    case space(CGFloat, Layout)
    case newline(space: CGFloat, Layout)
    case choice(Layout, Layout)
    case empty
}

struct Line {
    enum Element {
        case view(UIView, CGFloat)
        case space(CGFloat)
    }
    
    var elements: [Element]
    var topSpace: CGFloat
    
    var width: CGFloat {
        return elements.reduce(0) { $0 + $1.width }
    }
}

extension Line.Element {
    var width: CGFloat {
        switch self {
        case let .view(_, w): return w
        case let .space(w): return w
        }
    }
}

extension Layout {
    func apply(containerWidth: CGFloat) -> Set<UIView> {
        let lines = computeLines(containerWidth: containerWidth)
        
        var p = CGPoint.zero
        var result: Set<UIView> = []
        for line in lines {
            p.y += line.topSpace
            var lineHeight: CGFloat = 0
            for el in line.elements {
                switch el {
                case let .view(view, width):
                    let size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
                    view.frame = CGRect(origin: p, size: CGSize(width: width, height: size.height)).integral
                    p.x += width
                    lineHeight = max(lineHeight, size.height)
                    result.insert(view)
                case let .space(width):
                    p.x += width
                }
            }
            p.x = 0
            p.y += lineHeight
        }
        return result
    }

    func computeLines(containerWidth: CGFloat, start: CGFloat = 0) -> [Line] {
        var result: [Line] = []
        var line = Line(elements: [], topSpace: 0)
        var el = self
        var x = start
        while true {
            switch el {
            case let .view(view, next):
                let size = view.sizeThatFits(CGSize(width: containerWidth - x, height: .greatestFiniteMagnitude))
                x += size.width
                line.elements.append(.view(view, size.width))
                el = next
            case let .space(space, next):
                x += space
                line.elements.append(.space(space))
                el = next
            case let .newline(space, next):
                x = 0
                result.append(line)
                line = Line(elements: [], topSpace: space)
                el = next
            case let .choice(first, second):
                let lines = first.computeLines(containerWidth: containerWidth, start: x)
                let tooWide = lines.contains { $0.width >= containerWidth }
                if !tooWide {
                    line.elements.append(contentsOf: lines[0].elements)
                    result.append(line)
                    result.append(contentsOf: lines.dropFirst())
                    return result
                } else {
                    el = second
                }
            case .empty:
                result.append(line)
                return result
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

func label(text: String, size: UIFontTextStyle, multiline: Bool = false) -> UILabel {
    let label = UILabel()
    label.font = UIFont.preferredFont(forTextStyle: size)
    label.text = text
    label.adjustsFontForContentSizeCategory = true
    if multiline {
        label.numberOfLines = 0
    }
    return label
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

extension UIView {
    var layout: Layout {
        return .view(self, .empty)
    }
}

func +(lhs: Layout, rhs: Layout) -> Layout {
    switch lhs {
    case let .view(v, next): return .view(v, next + rhs)
    case let .space(space, next): return .space(space, next + rhs)
    case let .newline(space, next): return .newline(space: space, next + rhs)
    case let .choice(l, r): return .choice(l + rhs, r + rhs)
    case .empty: return rhs
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
        
        let titleLabel = label(text: "Building a Layout Library", size: .headline, multiline: true)
        let episodeNumber = label(text: "Episode 123", size: .caption1)
        let episodeDate = label(text: "September 23", size: .caption1)

        let metadata = [episodeNumber.layout, episodeDate.layout]
        let layout: Layout =
            .view(titleLabel,
            .newline(space: 10,
            metadata.horizontal(space: 20).or(metadata.vertical())
            ))

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

