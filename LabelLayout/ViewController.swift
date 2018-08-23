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

struct Line {
    var elements: [(UIView, CGRect)]
    var height: CGFloat {
        return elements.map { $0.1.height }.max() ?? 0
    }
}

extension Line {
    mutating func join(_ other: Line) {
        elements += other.elements
    }
}

extension Layout {
    func apply(containerWidth: CGFloat) {
        let lines = computeLines(containerWidth: containerWidth, startingAt: .zero) ?? []
        for line in lines {
            for (view, frame) in line.elements {
                view.frame = frame
            }
        }
    }

    private func computeLines(containerWidth: CGFloat, startingAt start: CGPoint, cancelOnOverflow: Bool = false) -> [Line]? {
        var lines: [Line] = [Line(elements: [])]
        var line: Line {
            get { return lines[lines.endIndex-1] }
            set { lines[lines.endIndex-1] = newValue }
        }
        var current = self
        var p = start
        while true {
            switch current {
            case let .view(view, next):
                let size = view.sizeThatFits(CGSize(width: containerWidth - p.x, height: .greatestFiniteMagnitude))
                line.elements.append((view, CGRect(origin: p, size: size)))
                p.x += size.width
                if cancelOnOverflow && p.x > containerWidth {
                    return nil
                }
                current = next
            case let .newline(next):
                p.x = 0
                p.y += line.height
                lines.append(Line(elements: []))
                current = next
            case let .choice(first, second):
                if let firstLayout = first.computeLines(containerWidth: containerWidth, startingAt: p, cancelOnOverflow: true) {
                    guard let cont = firstLayout.first else { return lines}
                    line.join(cont)
                    lines.append(contentsOf: firstLayout.dropFirst())
                    return lines
                } else {
                    current = second
                }
            case .empty:
                return lines
            }
        }
    }
}

final class LayoutView: UIView {
    let layout: Layout
    
    init(_ layout: Layout) {
        self.layout = layout
        super.init(frame: .zero)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedsLayout), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        layout.apply(containerWidth: bounds.width)
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
        episodeNumber.font = UIFont.preferredFont(forTextStyle: .body)
        episodeNumber.adjustsFontForContentSizeCategory = true

        
        let episodeDate = UILabel()
        episodeDate.text = "September 23"
        episodeDate.font = UIFont.preferredFont(forTextStyle: .body)
        episodeDate.adjustsFontForContentSizeCategory = true

        let layout = Layout.view(titleLabel, .newline(.choice(.view(episodeNumber, .view(episodeDate, .empty)), .view(episodeNumber, .newline(.view(episodeDate, .empty))))))

        let container = LayoutView(layout)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(episodeNumber)
        container.addSubview(episodeDate)
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: container.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

