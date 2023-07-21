//
//  VonageVideoCallPlatformView.swift
//  vonage_video_call
//
//  Created by Caciano Kroth on 20/07/23.
//

import Foundation
import UIKit
import Flutter

class VonageVideoCallPlatformView: NSObject, FlutterPlatformView {
    private let videoContainer: VonageVideoCallContainer
    private let paddingBottom: CGFloat = 96
    
    func view() -> UIView {
        return videoContainer
    }
    
    override init() {
        videoContainer = VonageVideoCallContainer()
        super.init()
    }
    
    func addSubscriberView(_ view: UIView) {
        videoContainer.insertSubview(view, at: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            view.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            view.widthAnchor.constraint(equalTo: videoContainer.widthAnchor),
            view.heightAnchor.constraint(equalTo: videoContainer.heightAnchor)
        ])
    }
    
    func addPublisherView(_ view: UIView) {
        videoContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.rightAnchor.constraint(equalTo: videoContainer.rightAnchor, constant: -24),
            view.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: -paddingBottom),
            view.widthAnchor.constraint(equalToConstant: 120),
            view.heightAnchor.constraint(equalToConstant: 160)
        ])
        
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let subview = gesture.view else { return }
        
        let translation = gesture.translation(in: subview.superview)
        var newCenter = CGPoint(x: subview.center.x + translation.x, y: subview.center.y + translation.y)
        
        let halfSubviewHeight = subview.bounds.height / 2
        let maxY = subview.superview!.bounds.height - halfSubviewHeight - paddingBottom
        let minY = halfSubviewHeight + 60
        let maxX = subview.superview!.bounds.width - subview.bounds.width / 2
        let minX = subview.bounds.width / 2
        
        newCenter.y = max(minY, min(newCenter.y, maxY))
        newCenter.x = max(minX, min(newCenter.x, maxX))
        
        subview.center = newCenter
        gesture.setTranslation(CGPoint.zero, in: subview.superview)
    }
}
