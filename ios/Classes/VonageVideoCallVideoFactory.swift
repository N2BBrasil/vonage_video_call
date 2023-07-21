//
//  VonageVideoCallVideoFactory.swift
//  vonage_video_call
//
//  Created by Caciano Kroth on 20/07/23.
//

import Foundation
import Flutter

class VonageVideoCallVideoFactory: NSObject, FlutterPlatformViewFactory {
    public var view: VonageVideoCallPlatformView?
    public var subscriberView: UIView?
    public var publisherView: UIView?
    private let binaryMessenger: FlutterBinaryMessenger
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.binaryMessenger = binaryMessenger
        super.init()
    }
    
    func getViewInstance(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger?) -> VonageVideoCallPlatformView {
        if view == nil {
            view = VonageVideoCallPlatformView()
            
            if let subscriberView = subscriberView {
                view?.addSubscriberView(subscriberView)
            }
            
            if let publisherView = publisherView {
                view?.addPublisherView(publisherView)
            }
        }
        return view!
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return getViewInstance(frame: frame, viewIdentifier: viewId, arguments: args, messenger: binaryMessenger)
    }
}
