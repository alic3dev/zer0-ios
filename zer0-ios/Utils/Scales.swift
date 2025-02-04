//
//  Scales.swift
//  Edat
//
//  Created by Alice Grace on 5/5/24.
//

import Foundation

public struct Scale: Hashable {
  public let name: String
  public let notes: [Int]

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.name)
  }
}

// C  C# D  D# E  F  F# G  G# A  A#   B

public let ScaleAll = Scale(name: "All", notes: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
public let ScaleMajor = Scale(name: "Major", notes: [0, 2, 4, 5, 7, 9, 11])
public let ScaleMinor = Scale(name: "Minor", notes: [0, 2, 3, 5, 7, 8, 10])

public let Scales: [Scale] = [ScaleAll, ScaleMajor, ScaleMinor]

public enum Note: Int {
  case C = 0
  case Cs = 1
  case D = 2
  case Ds = 3
  case E = 4
  case F = 5
  case Fs = 6
  case G = 7
  case Gs = 8
  case A = 9
  case As = 10
  case B = 11
}

public func getNoteLabel(note: Note) -> String {
  switch note {
  case .C: "C"
  case .Cs: "C#"
  case .D: "D"
  case .Ds: "D#"
  case .E: "E"
  case .F: "F"
  case .Fs: "F#"
  case .G: "G"
  case .Gs: "G#"
  case .A: "A"
  case .As: "A#"
  case .B: "B"
  }
}

public let Notes: [Note] = [.C, .Cs, .D, .Ds, .E, .F, .Fs, .G, .Gs, .A, .As, .B]

public func getScaleInKey(scale: Scale, key: Note) -> Scale {
  return Scale(
    name: "\(scale.name) - Key of \(key)",
    notes: scale.notes.map { ($0 + key.rawValue) % 12 }
  )
}
