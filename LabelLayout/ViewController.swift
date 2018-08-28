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
    case newline(Layout)
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
            case let .newline(next):
                p.x = 0
                p.y += lineHeight
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
            case let .newline(next):
                x = 0
                el = next
            case let .choice(first, second):
                if first.fits(containerWidth: containerWidth - x) {
                    return true
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

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel(text: "Building a Layout Library", size: .headline, multiline: true)
        let episodeNumber = UILabel(text: "Episode 123", size: .caption1)
        let episodeDate = UILabel(text: "September 23", size: .caption1)

        let layout: Layout =
            .view(titleLabel,
            .newline(
            .choice(
                .view(episodeNumber, .view(episodeDate, .empty)),
                .view(episodeNumber, .newline(.view(episodeDate, .empty)))
            )))

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

