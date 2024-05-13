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

public typealias onOscillatorRenderFrameFunc = (Float) -> Float
public typealias onOscillatorRenderFunc = () -> onOscillatorRenderFrameFunc

public final class Oscillator {
  private let engine: AVAudioEngine
  private let sampleRate: Float
  private let phase: Phase

  private var srcNode: AVAudioSourceNode?
  private var onRender: onOscillatorRenderFunc = { { _ in 0.0 }}
  private var frequency: Float

  public var hasStarted: Bool = false
  public var amplitude: Float
  public var volume: Float = 1.0
  public var type: OscillatorType

  public init(engine: AVAudioEngine, sampleRate: Float, frequency: Float = 0, type: OscillatorType = .custom, amplitude: Float = 1.0) {
    self.engine = engine
    self.sampleRate = sampleRate
    self.phase = .init(sampleRate: sampleRate, frequency: frequency)
    self.frequency = frequency
    self.amplitude = amplitude
    self.type = type
  }

  public func copy() -> Oscillator {
    let oscillator = Oscillator(engine: self.engine, sampleRate: self.sampleRate, frequency: self.frequency, type: self.type, amplitude: self.amplitude)
    oscillator.volume = self.volume
    oscillator.start(onRender: self.onRender)

    return oscillator
  }

  public func setFrequency(frequency: Float) {
    self.frequency = frequency

    self.phase.setIncrement(
      sampleRate: self.sampleRate,
      frequency: self.frequency
    )
  }

  public func start(onRender: @escaping onOscillatorRenderFunc) {
    self.onRender = onRender

    if self.srcNode != nil || self.hasStarted {
      return
    }

    self.srcNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
      let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

      let onFrame: onOscillatorRenderFrameFunc = self.onRender()

      let amplitude = self.amplitude
      let volume = self.volume

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

        value *= amplitude
        value *= volume

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
