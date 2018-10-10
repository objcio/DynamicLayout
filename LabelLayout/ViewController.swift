//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit
import Layout

extension UILabel {
    convenience init(text: String, size: UIFont.TextStyle, textColor: UIColor = .black, numberOfLines: Int = 1) {
        self.init()
        font = UIFont.preferredFont(forTextStyle: size)
        self.text = text
        self.textColor = textColor
        adjustsFontForContentSizeCategory = true
        self.numberOfLines = numberOfLines
    }
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
        return [.space(), self, .space()].horizontal()
    }
}
extension Airport {
    func layout(text: String) -> Layout {
        let t = UILabel(text: text, size: .caption2)
        let code = UILabel(text: self.code, size: .largeTitle)
        let time = UILabel(text: formatter.string(from: self.time), size: .caption1)
        return [t.layout().center, code.layout().center, time.layout().center].vertical()
    }
}

extension Flight {
    var metaData: [(String, String)] {
        return [("FLIGHT", name), ("TERMINAL", terminal), ("GATE", gate), ("BOARDING", formatter.string(from: boarding))]
    }

    var metadataLayout: Layout {
        let items: [Layout] = metaData.map { [UILabel(text: $0, size: .caption2, textColor: .white).layout(), UILabel(text: $1, size: .body, textColor: .white).layout()].vertical().box() }
        let wrapper = UIView()
        wrapper.backgroundColor = UIColor(red: 242/255, green: 27/255, blue: 63/255, alpha: 1)
        wrapper.layer.cornerRadius = 5
        assert(items.count == 4)
        let els = items.horizontal(space: .flexible(min: .absolute(20))).or([items[0...1].horizontal(space: .flexible(min: 20)), items[2...3].horizontal(space: .flexible(min: 20))].vertical(space: 20)).or(items.vertical(space: 20))
        return els.box(width: .flexible(min: 0), wrapper: wrapper)
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
        return view.layout(width: .flexible(min: .absolute(minWidth)), verticalAlignment: .stretch)
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
//        let origin = sample.origin.layout(text: "FROM").box()
//        let destination = sample.destination.layout(text: "TO").box()
//        let icon = UILabel(text: "✈", size: .largeTitle, textColor: .gray).layout(verticalAlignment: .center)
//        let fromTo = [origin, icon, destination].horizontal(space: .flexible(min: .absolute(20)))
//            .or([origin, Layout.verticalLine(color: .lightGray), destination].horizontal(space: .flexible(min: 20))
//            .or([origin.center, Layout.horizontalLine(color: .lightGray, height: 1), destination.center].vertical(space: 20)))
//        let l = fromTo.box(width: .flexible(min: 0), wrapper: box())
//        let layout = [l, sample.metadataLayout].vertical(space: 20)
        let labels = ["one", "two", "three", "four", "five"].map { UILabel(text: $0, size: .body).layout() }
        let layout = labels.horizontal(space: .flexible(min: 10)).box(width: .flexible(min: .basedOnContents), vertical: .top, wrapper: box()).or(labels[0])
        
        let container = LayoutView(layout)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        view.backgroundColor = UIColor(white: 0.9, alpha: 1)

        view.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        NSLayoutConstraint.activate([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: container.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
    }
}

