//
//  ViewController.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 23.08.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        titleLabel.text = "Building a Layout Library"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 0
        
        let episodeNumber = UILabel()
        episodeNumber.text = "Episode 123"
        episodeNumber.font = UIFont.preferredFont(forTextStyle: .body)
        episodeNumber.translatesAutoresizingMaskIntoConstraints = false
        
        let episodeDate = UILabel()
        episodeDate.text = "September 23"
        episodeDate.font = UIFont.preferredFont(forTextStyle: .body)
        episodeDate.translatesAutoresizingMaskIntoConstraints = false
        
        let horizontal = UIStackView(arrangedSubviews: [episodeNumber, episodeDate])
        horizontal.axis = .horizontal
        horizontal.distribution = .equalSpacing
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            horizontal
        ])
        stack.axis = .vertical
        
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints([
            view.layoutMarginsGuide.topAnchor.constraint(equalTo: stack.topAnchor),
            view.layoutMarginsGuide.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            view.layoutMarginsGuide.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
    }


}

