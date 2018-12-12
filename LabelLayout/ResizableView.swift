//
//  ResizableView.swift
//  LabelLayout
//
//  Created by Chris Eidhof on 19.09.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit



class ResizableView: UIView {
    let dragger = UIView()
    var trailingConstraint: NSLayoutConstraint!
    var nested: UIView
    
    init(frame: CGRect, nested: UIView) {
        self.nested = nested
        super.init(frame: frame)
        addSubview(nested)
        addSubview(dragger)
        dragger.backgroundColor = .red
        dragger.translatesAutoresizingMaskIntoConstraints = false
        trailingConstraint = nested.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor)
        addConstraints([
            nested.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            trailingConstraint,
            nested.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            nested.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
            ])
        addConstraints([
            dragger.widthAnchor.constraint(equalToConstant: 20),
            dragger.heightAnchor.constraint(equalToConstant: 20),
            dragger.trailingAnchor.constraint(equalTo: nested.trailingAnchor),
            dragger.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        dragger.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(_:))))
        bringSubviewToFront(dragger)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func didPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let offset = gestureRecognizer.location(in: self)
        trailingConstraint.constant = min(0, -(frame.width - offset.x))
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
}

