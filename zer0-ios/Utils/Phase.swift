//
//  Phase.swift
//  Edat
//
//  Created by Alice Grace on 5/5/24.
//

import Foundation

class Phase {
  private var phase: Float = 0
  private var increment: Float = (TWO_PI / 44000) * 440

  init(increment: Float) {
    self.increment = increment
  }

  init(sampleRate: Float, frequency: Float) {
    self.setIncrement(sampleRate: sampleRate, frequency: frequency)
  }

  static func generateIncrement(sampleRate: Float, frequency: Float) -> Float {
    return (TWO_PI / sampleRate) * frequency
  }

  func setIncrement(increment: Float) {
    self.increment = increment
  }

  func setIncrement(sampleRate: Float, frequency: Float) {
    self.increment = Phase.generateIncrement(sampleRate: sampleRate, frequency: frequency)
  }

  func value() -> Float {
    return self.phase
  }

  func advance() {
    self.phase += self.increment

    if self.phase >= TWO_PI {
      self.phase -= TWO_PI
    }

    if self.phase < 0.0 {
      self.phase += TWO_PI
    }
  }
}
