//
//  VonageVideoCallContainer.swift
//  vonage_video_call
//
//  Created by Caciano Kroth on 20/07/23.
//

import Foundation
import UIKit

class VonageVideoCallContainer: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.autoresizesSubviews = true
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
