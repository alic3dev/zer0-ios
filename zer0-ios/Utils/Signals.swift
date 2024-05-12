//
//  Signals.swift
//  Edat
//
//  Created by Alice Grace on 5/5/24.
//

import Foundation

public typealias SignalGenerator = (Float) -> Float

public struct Signal {
  public let name: String
  public let generate: SignalGenerator
}

public let SignalSine = Signal(name: "Sine") { (phase: Float) -> Float in
  sin(phase)
}

public let SignalWhiteNoise = Signal(name: "White Noise") { (_: Float) -> Float in
  (Float(arc4random_uniform(UINT32_MAX)) / Float(UINT32_MAX)) * 2 - 1
}

public let SignalSawtoothUp = Signal(name: "Sawtooth Up") { (phase: Float) -> Float in
  1.0 - 2.0 * (phase * (1.0 / TWO_PI))
}

public let SignalSawtoothDown = Signal(name: "Sawtooth Down") { (phase: Float) -> Float in
  (2.0 * (phase * (1.0 / TWO_PI))) - 1.0
}

public let SignalSquare = Signal(name: "Square") { (phase: Float) -> Float in
  if phase <= Float.pi {
    return 1.0
  } else {
    return -1.0
  }
}

public let SignalTriangle = Signal(name: "Triangle") { (phase: Float) -> Float in
  var value = (2.0 * (phase * (1.0 / TWO_PI))) - 1.0

  if value < 0.0 {
    value = -value
  }

  return 2.0 * (value - 0.5)
}

public let Signals: [Signal] = [SignalSine, SignalWhiteNoise, SignalSawtoothUp, SignalSawtoothDown, SignalSquare, SignalTriangle]
