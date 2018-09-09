//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit



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

let start: TimeInterval = 3600*7
let sample = Flight(origin: Airport(city: "Berlin", code: "TXL", time:
    Date(timeIntervalSince1970: start)), destination: Airport(city: "Paris", code: "CDG", time: Date(timeIntervalSince1970: start + 2*3600)), name: "AF123", terminal: "1", gate: "14", boarding: Date(timeIntervalSince1970: start - 1800))

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
        let resizable = ResizableView(frame: .zero, nested: container)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.9, alpha: 1)
        view.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        view.addSubview(resizable)
        resizable.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: resizable.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: resizable.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: resizable.trailingAnchor),
            view.layoutMarginsGuide.bottomAnchor.constraint(equalTo: resizable.bottomAnchor)
            ])
        
    }
}

