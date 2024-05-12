//
//  Scales.swift
//  Edat
//
//  Created by Alice Grace on 5/5/24.
//

import Foundation

public struct Scale {
  public let name: String
  public let notes: [Int]
}

// C  C# D  D# E  F  F# G  G# A  A#   B

public let ScaleAll = Scale(name: "All", notes: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
public let ScaleMajor = Scale(name: "Major", notes: [0, 2, 4, 5, 7, 9, 11])
public let ScaleMinor = Scale(name: "Minor", notes: [0, 2, 3, 5, 7, 8, 10])

public let Scales: [Scale] = [ScaleAll, ScaleMajor, ScaleMinor]

public func getScaleInKey(scale: Scale, key: Int) -> Scale {
  return Scale(
    name: "\(scale.name) - Key of \(key)",
    notes: scale.notes.map { ($0 + key) % 12 }
  )
}
