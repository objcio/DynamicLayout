//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

extension UILabel {
    convenience init(text: String, size: UIFont.TextStyle, textColor: UIColor = .black, multiline: Bool = false) {
        self.init()
        font = UIFont.preferredFont(forTextStyle: size)
        self.text = text
        self.textColor = textColor
        adjustsFontForContentSizeCategory = true
        if multiline {
            numberOfLines = 0
        }
    }
}


struct Episode: Codable {
    var media_duration: TimeInterval
    var synopsis: String
    var title: String
    var number: Int
    var collection: String
    var released_at: Date
    var url: URL
    var small_poster_url: URL
    var subscription_only: Bool
}

let formatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    f.timeStyle = .none
    return f
}()

let shortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .none
    return f
}()

extension Episode {
    var layout: Layout {
        let title = UILabel(text: self.title, size: .headline, multiline: true).layout()
        let synopsis = UILabel(text: self.synopsis, size: .body, multiline: true)
        let dateLong = UILabel(text: formatter.string(from: self.released_at), size: .caption1).layout()
        let dateShort = UILabel(text: shortFormatter.string(from: self.released_at), size: .caption1).layout()
        //        let date = dateLong.or(dateShort)
        let epNumSmall = UILabel(text: "# \(number)", size: .caption1).layout()
        let epNumFull = UILabel(text: "Episode \(number)", size: .caption1).layout()
        //        let epNum = epNumFull.or(epNumSmall)
        
        let duration = UILabel(text: media_duration.hoursAndMinutes, size: .caption1).layout()
        let meta = [epNumFull, duration, dateLong].horizontal(space: .flexible(min: 10)).or(
            [epNumSmall, duration, dateShort].horizontal(space: .flexible(min: 10))
            ).or(
                [epNumSmall, dateShort].horizontal(space: .flexible(min: 20))
        )
        let white = UIView()
        white.backgroundColor = .white
        let i = UIImageView(image: UIImage(named: "thumbs/" + small_poster_url.lastPathComponent))
        i.contentMode = .scaleAspectFit
        let synOrImg = [i.layout(width: .flexible(min: 300), verticalAlignment: .top), synopsis.layout(width: .flexible(min: 300), verticalAlignment: .top)].horizontal(space: .absolute(20)).or(
            synopsis.layout(width: .flexible(min: 0))
        )
        return [title, meta, synOrImg].vertical(space: 10).box(width: .flexible(min: 0), vertical: .top, wrapper: white)
    }
}

let episodes: [Episode] = {
    let d = JSONDecoder()
    let url = Bundle.main.url(forResource: "episodes", withExtension: "json")!
    let data = try! Data(contentsOf: url)
    return try! d.decode([Episode].self, from: data)
}()
class ViewController: UIViewController {
    var token: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let container = LayoutView(episodes.randomElement()!.layout)
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

