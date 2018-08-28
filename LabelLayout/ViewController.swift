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
    case newline(Layout)
    case choice(Layout, Layout)
    case empty
}

extension Layout {
    func apply(containerWidth: CGFloat) -> [UIView] {
        var result: [UIView] = []
        var origin: CGPoint = .zero
        var current: Layout = self
        var lineHeight: CGFloat = 0
        while true {
        switch current {
            case let .view(v, rest):
                result.append(v)
                let availableWidth = containerWidth - origin.x
                let size = v.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
                v.frame = CGRect(origin: origin, size: size)
                lineHeight = max(lineHeight, size.height)
                origin.x += size.width
                current = rest
            case let .newline(rest):
                origin.x = 0
                origin.y += lineHeight
                lineHeight = 0
                current = rest
            case let .choice(first, second):
                if first.fits(currentX: origin.x, containerWidth: containerWidth) {
                    current = first
                } else {
                    current = second
                }
            case .empty:
                return result
            }
        }
    }
    
    func fits(currentX: CGFloat, containerWidth: CGFloat) -> Bool {
        var x = currentX
        var current: Layout = self
        while true {
            switch current {
            case let .view(v, rest):
                let availableWidth = containerWidth - x
                let size = v.sizeThatFits(CGSize(width: availableWidth, height: .greatestFiniteMagnitude))
                x += size.width
                if x >= containerWidth { return false }
                current = rest
            case let .newline(rest):
                x = 0
                current = rest
            case let .choice(first, second):
                if first.fits(currentX: x, containerWidth: containerWidth) {
                    return true
                } else {
                    current = second
                }
            case .empty:
                return true
            }
        }
    }
}

final class LayoutContainer: UIView {
    let layout: Layout
    init(_ layout: Layout) {
        self.layout = layout
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedsLayout), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        let views = layout.apply(containerWidth: bounds.width)
        setSubviews(views)
    }
}

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel(text: "Building a Layout Library", size: .headline, multiline: true)
        let episodeNumber = UILabel(text: "Episode 123", size: .body)
        let episodeDate = UILabel(text: "September 23", size: .body)
        
        let horizontal = Layout.view(episodeNumber, Layout.view(episodeDate, .empty))
        let vertical = Layout.view(episodeNumber, .newline(Layout.view(episodeDate, .empty)))
        let layout = Layout.view(titleLabel, .newline(
            .choice(horizontal, vertical)
            ))
        
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

