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

extension Layout {
    func apply(containerWidth: CGFloat) -> Set<UIView> {
        var el = self
        var p = CGPoint.zero
        var lineHeight: CGFloat = 0
        var result: Set<UIView> = []
        while true {
            switch el {
            case let .view(view, next):
                let size = view.sizeThatFits(CGSize(width: containerWidth - p.x, height: .greatestFiniteMagnitude))
                view.frame = CGRect(origin: p, size: size).integral
                p.x += size.width
                lineHeight = max(lineHeight, size.height)
                result.insert(view)
                el = next
            case let .space(space, next):
                p.x += space
                el = next
            case let .newline(space, next):
                p.x = 0
                p.y += lineHeight + space
                lineHeight = 0
                el = next
            case let .choice(first, second):
                if first.fits(containerWidth: containerWidth - p.x) {
                    el = first
                } else {
                    el = second
                }
            case .empty:
                return result
            }
        }
    }

    func fits(containerWidth: CGFloat) -> Bool {
        var el = self
        var x: CGFloat = 0
        while true {
            switch el {
            case let .view(view, next):
                let size = view.sizeThatFits(CGSize(width: containerWidth - x, height: .greatestFiniteMagnitude))
                x += size.width
                if x >= containerWidth {
                    return false
                }
                el = next
            case let .space(space, next):
                x += space
                el = next
            case let .newline(_, next):
                x = 0
                el = next
            case let .choice(first, second):
                if first.fits(containerWidth: containerWidth - x) {
                    el = first
                } else {
                    el = second
                }
            case .empty:
                return true
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

