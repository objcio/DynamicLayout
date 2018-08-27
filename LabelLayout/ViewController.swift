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

enum VerticalAlignment: Equatable {
    case top
    case center
    case bottom
    case stretch
}

indirect enum Layout {
    case element(Element, Width, vertical: VerticalAlignment, Layout)
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
    var elements: [(Block, BlockWidth, VerticalAlignment)]

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

extension Line.Block {
    func apply(at origin: CGPoint, absWidth: CGFloat) -> (Set<UIView>, height: CGFloat) {
        var result: Set<UIView> = []
        let height: CGFloat
        switch self {
        case let .view(view):
            height = view.sizeThatFits(CGSize(width: absWidth, height: .greatestFiniteMagnitude)).height
            let frame = CGRect(origin: origin, size: CGSize(width: absWidth, height: height))
            view.frame = frame.integral
            result.insert(view)
        case let .inlineBox(nil, lines):
            let nested = lines.apply(containerWidth: absWidth, origin: origin)
            result.formUnion(nested)
            height = nested.maxY - origin.y
        case let .inlineBox(wrapper?, lines):
            let width = absWidth - wrapper.layoutMargins.width
            let nestedOrigin = CGPoint(x: wrapper.layoutMargins.left, y: wrapper.layoutMargins.top)
            let subviews = lines.apply(containerWidth: width, origin: nestedOrigin)
            wrapper.frame = CGRect(origin: origin, size: CGSize(width: absWidth, height: subviews.maxY + wrapper.layoutMargins.height))
            wrapper.setSubviews(subviews)
            result.insert(wrapper)
            height = wrapper.frame.height
        case .space:
            height = 0
            break
        }
        return (result, height)
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
            
            var viewsThatNeedVerticalOffset: [(Set<UIView>, VerticalAlignment, height: CGFloat)] = []
            for (block, width, alignment) in line.elements {
                let origin = CGPoint(x: x, y: y)
                let absWidth = width.absolute(flexibleSpace: flexibleSpace)
                let (views, height) = block.apply(at: origin, absWidth: absWidth)
                result.formUnion(views)
                lineHeight = Swift.max(lineHeight, height)
//                assert(absWidth > 0)
                x += absWidth
                if alignment != .top {
                    viewsThatNeedVerticalOffset.append((views, alignment, height: height))
                }
            }

            for (views, alignment, height) in viewsThatNeedVerticalOffset {
                let availableSpace = lineHeight - height
                let offset: CGFloat
                switch alignment {
                case .top: continue
                case .bottom:
                    for v in views {
                        v.frame.origin.y += availableSpace
                    }

                case .center:
                    offset = availableSpace/2
                    for v in views {
                        v.frame.origin.y += offset
                    }
                case .stretch:
                    for v in views {
                        v.frame.size.height = lineHeight
                    }
                }
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
            case let .element(element, width, alignment, next):
                let blockWidth = element.width(width, availableWidth: containerWidth - currentWidth)
                currentWidth += blockWidth.min
                switch element {
                case let .view(view):
                    line.elements.append((.view(view), blockWidth, alignment))
                case .space:
                    line.elements.append((.space, blockWidth, alignment))
                case let .inlineBox(wrapper, layout):
                    // todo: we compute this twice!
                    let box = layout.computeLines(containerWidth: containerWidth - currentWidth, startingAt: 0)!
                    line.elements.append((.inlineBox(wrapper: wrapper, box), blockWidth, alignment))
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

extension Sequence where Element: UIView {
    var maxY: CGFloat {
        return map { $0.frame.maxY }.max() ?? 0
    }
}

extension UIEdgeInsets {
    var width: CGFloat { return left + right }
    var height: CGFloat { return top + bottom }
}

extension Layout {
    static func space(_ width: Width = .flexible(min: 0)) -> Layout {
        return Layout.element(.space, width, vertical: .top, .empty)
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

extension BidirectionalCollection where Element == Layout {
    func horizontal(minSpacing: CGFloat? = nil) -> Layout {
        guard let v = last else { return .empty }
        var result = v
        for e in reversed().dropFirst() {
            if let s = minSpacing {
                result = .element(.space, .flexible(min: s), vertical: .top, result)
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
    case let .element(v, w, a, x): return .element(v, w, vertical: a, x + rhs)
    }
}

extension UIView {
    func layout(width: Width = .basedOnContents, verticalAlignment: VerticalAlignment = .top) -> Layout {
        return .element(.view(self), width, vertical: verticalAlignment, .empty)
    }
}

extension Layout {
    func or(_ other: Layout) -> Layout {
        return .choice(self, other)
    }
    
    func inlineBox(width: Width = .basedOnContents, vertical: VerticalAlignment = .top, wrapper: UIView? = nil) -> Layout {
        return .element(.inlineBox(wrapper: wrapper, self), width, vertical: vertical, .empty)
    }
}

func label(text: String, size: UIFontTextStyle, textColor: UIColor = .black, multiline: Bool = false) -> UILabel {
    let label = UILabel()
    label.font = UIFont.preferredFont(forTextStyle: size)
    label.text = text
    label.textColor = textColor
    label.adjustsFontForContentSizeCategory = true
    if multiline {
        label.numberOfLines = 0
    }
    return label
}

struct Airport {
    var city: String
    var code: String
    var time: Date
}

struct Flight {
    var origin: Airport
    var destination: Airport
    var name: String
    var terminal: String
    var gate: String
    var boarding: Date
}

let sample = Flight(origin: Airport(city: "Berlin", code: "TXL", time: Date(timeIntervalSinceNow: -7200)), destination: Airport(city: "Paris", code: "CDG", time: Date()), name: "AF123", terminal: "1", gate: "14", boarding: Date())

let formatter: DateFormatter = {
	let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
//    f.locale = Locale(identifier: "de_DE")
	return f
}()

extension Layout {
    var center: Layout {
        return [Layout.space(), self, Layout.space()].horizontal(minSpacing: nil)
    }
}
extension Airport {
    func layout(text: String) -> Layout {
        let t = label(text: text, size: .caption2)
        let code = label(text: self.code, size: .largeTitle)
        let time = label(text: formatter.string(from: self.time), size: .caption1)
        return [t.layout().center, code.layout().center, time.layout().center].vertical()
    }
}

extension Flight {
    var metaData: [(String, String)] {
        return [("FLIGHT", name), ("TERMINAL", terminal), ("GATE", gate), ("BOARDING", formatter.string(from: boarding))]
    }

    var metadataLayout: Layout {
        let items: [Layout] = metaData.map { [label(text: $0, size: .caption2, textColor: .white).layout(), label(text: $1, size: .body, textColor: .white).layout()].vertical().inlineBox() }
        let wrapper = UIView()
        wrapper.backgroundColor = UIColor(red: 242/255, green: 27/255, blue: 63/255, alpha: 1)
        wrapper.layer.cornerRadius = 5
        assert(items.count == 4)
        let els = items.horizontal(minSpacing: 20).or([items[0...1].horizontal(minSpacing: 20), items[2...3].horizontal(minSpacing: 20)].vertical(space: 20)).or(items.vertical(space: 20))
        return els.inlineBox(width: .flexible(min: 0), wrapper: wrapper)
    }
}

extension Layout {
    static func verticalLine(color: UIColor, width: Width = .absolute(0.5)) -> Layout {
        let view = UIView()
        view.backgroundColor = color
        return view.layout(width: width, verticalAlignment: .stretch)
    }

    static func horizontalLine(color: UIColor, minWidth: CGFloat = 0, height: CGFloat) -> Layout {
        let view = UIView()
        view.backgroundColor = color
        view.frame.size.height = height
        return view.layout(width: .flexible(min: minWidth), verticalAlignment: .stretch)
    }
}
class ViewController: UIViewController {
    var token: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        func box() -> UIView {
            let roundedBox = UIView()
            roundedBox.layer.cornerRadius = 5
            roundedBox.backgroundColor = .white
            return roundedBox
        }
        let origin = sample.origin.layout(text: "FROM").inlineBox()
        let destination = sample.destination.layout(text: "TO").inlineBox()
        let icon = label(text: "✈", size: .largeTitle, textColor: .gray).layout(verticalAlignment: .center)
        let fromTo = [origin, icon, destination].horizontal(minSpacing: 20)
            .or([origin, Layout.verticalLine(color: .lightGray), destination].horizontal(minSpacing: 20)
            .or([origin.center, Layout.horizontalLine(color: .lightGray, height: 1), destination.center].vertical(space: 20)))
        let l = fromTo.inlineBox(width: .flexible(min: 0), wrapper: box())
        let layout = [l, sample.metadataLayout].vertical(space: 20)
        
        let container = LayoutView(layout)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        view.backgroundColor = UIColor(white: 0.9, alpha: 1)

        
        NSLayoutConstraint.activate([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: container.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

