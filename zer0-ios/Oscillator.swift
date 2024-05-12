//
//  Oscillator.swift
//  zer0-ios
//
//  Created by Alice Grace on 5/12/24.
//

import AVFoundation
import Foundation

public enum OscillatorError: Error {
  case notStarted(String)
}

public enum OscillatorType: Int {
  case custom
  case triangle
  case sine
  case whiteNoise
  case sawtoothUp
  case sawtoothDown
  case square
}

public class Oscillator {
  let engine: AVAudioEngine
  let sampleRate: Float
  let phase: Phase

  var frequency: Float
  public var amplitude: Float
  public var type: OscillatorType
  var srcNode: AVAudioSourceNode?
  var hasStarted: Bool = false

  public init(engine: AVAudioEngine, sampleRate: Float, frequency: Float = 440, type: OscillatorType = .custom, amplitude: Float = 1.0) {
    self.engine = engine
    self.sampleRate = sampleRate
    self.phase = .init(sampleRate: sampleRate, frequency: frequency)
    self.frequency = frequency
    self.amplitude = amplitude
    self.type = type
  }

  public func setFrequency(frequency: Float) {
    self.frequency = frequency

    self.phase.setIncrement(
      sampleRate: self.sampleRate,
      frequency: self.frequency
    )
  }

  public func start(onRender: @escaping () -> ((Float) -> Float)) {
    self.srcNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
      let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

      let onFrame: ((Float) -> Float) = onRender()

      for frame in 0 ..< Int(frameCount) {
        let phaseValue: Float = self.phase.value()
        let frameValue: Float = onFrame(phaseValue)

        var value: Float

        switch self.type {
        case .custom:
          value = frameValue
        case .sawtoothDown:
          value = SignalSawtoothDown.generate(phaseValue)
        case .sawtoothUp:
          value = SignalSawtoothUp.generate(phaseValue)
        case .sine:
          value = SignalSine.generate(phaseValue)
        case .square:
          value = SignalSquare.generate(phaseValue)
        case .triangle:
          value = SignalTriangle.generate(phaseValue)
        case .whiteNoise:
          value = SignalWhiteNoise.generate(phaseValue)
        }

        value *= self.amplitude

        self.phase.advance()

        // Set the same value on all channels (due to the inputFormat, there's only one channel though).
        for buffer in ablPointer {
          let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
          buf[frame] = value
        }
      }

      return noErr
    }
    self.engine.attach(self.srcNode!)

    self.hasStarted = true
  }

  public func connect(to: AVAudioNode, format: AVAudioFormat?) throws {
    if !self.hasStarted {
      throw OscillatorError.notStarted("Oscillator not started before connect")
    }

    if self.srcNode == nil {
      return
    }

    self.engine.connect(self.srcNode!, to: to, format: format)
  }
}
