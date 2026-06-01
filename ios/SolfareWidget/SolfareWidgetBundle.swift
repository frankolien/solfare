//
//  SolfareWidgetBundle.swift
//  SolfareWidget
//
//  Created by Olien on 6/1/26.
//

import WidgetKit
import SwiftUI

@main
struct SolfareWidgetBundle: WidgetBundle {
  var body: some Widget {
    PriceTrackerWidget()
    WalletGlanceWidget()
  }
}
