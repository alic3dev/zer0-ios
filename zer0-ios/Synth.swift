//
//  Synth.swift
//  zer0-ios
//
//  Created by Alice Grace on 5/12/24.
//

import AVFAudio
import Foundation

public struct SynthModifier: Identifiable {
  public var id: UUID = .init()
  public var name: String
  public var iconMin: String = ""
  public var iconMax: String = ""
  public var value: Float
  public var valueMin: Float = 0.0
  public var valueMax: Float = 1.0
}

public typealias onSynthRenderFunc = () -> Void

open class Synth: Identifiable {
  public let id: UUID = .init()

  private var srcNode: AVAudioSourceNode?
  private var onRender: onSynthRenderFunc = {}

  private var engine: AVAudioEngine
  private var mixer: AVAudioMixerNode = .init()
  private var sampleRate: Float
  private var oscillators: [[Oscillator]] = []
  private var oscillatorMixers: [AVAudioMixerNode] = []
  private var volume: Float
  private var polyphony: UInt8
  private var currentPolyphonyChannel: Int = 0
  private var playIndex: [UInt64] = []

  public var name: String = "Default Synth"
  public var enabled: Bool = true
  public var stopped: Bool = false

  public var attack: Float = 1.0
  public var decay: Float = 1.0
  public var sustain: Float = 0.75
  public var sustainDuration: Float = 0.5
  public var release: Float = 2.0

  public var modifiers: [SynthModifier] = []
  public var delays: [AVAudioUnitDelay] = []
  public var reverbs: [AVAudioUnitReverb] = []
  public var eqs: [AVAudioUnitEQ] = []
  public var distortions: [AVAudioUnitDistortion] = []

  public var resetVolumeOnNote: Bool = true

  public init(engine: AVAudioEngine, sampleRate: Float, oscillators: [Oscillator]? = nil, volume: Float = 1.0, polyphony: UInt8 = 1) {
    self.engine = engine
    self.sampleRate = sampleRate
    self.volume = volume

    self.mixer.outputVolume = self.volume
    self.engine.attach(self.mixer)

    self.polyphony = polyphony

    for _ in 1 ... self.polyphony {
      self.oscillators.append([])

      let oscillatorMixer: AVAudioMixerNode = .init()
      oscillatorMixer.outputVolume = 0.0
      self.engine.attach(oscillatorMixer)
      self.oscillatorMixers.append(oscillatorMixer)

      self.playIndex.append(0)
    }

    if oscillators != nil {
      self.addOscillator(oscillators!)
    }
  }

  public func addOscillator(_ oscillator: Oscillator) {
    var oscillatorToAppend: Oscillator = oscillator
    for i in 1 ... self.oscillators.count {
      if i > 1 {
        oscillatorToAppend = oscillator.copy()
      }

      self.oscillators[i - 1].append(oscillatorToAppend)
    }
  }

  public func addOscillator(_ oscillators: [Oscillator]) {
    var oscillatorsToAppend: [Oscillator] = oscillators

    for i in 1 ... self.oscillators.count {
      if i > 1 {
        oscillatorsToAppend = oscillators.map { $0.copy() }
      }

      self.oscillators[i - 1].append(contentsOf: oscillatorsToAppend)
    }
  }

  open func start(onRender: @escaping onSynthRenderFunc) {
    self.onRender = onRender

    if self.srcNode != nil {
      return
    }

    self.srcNode = .init { _, _, _, _ -> OSStatus in
      self.onRender()

      return noErr
    }
    self.engine.attach(self.srcNode!)
  }

  open func connect(to: AVAudioNode, format: AVAudioFormat?) throws {
    self.engine.connect(self.srcNode!, to: self.mixer, format: format)

    for (index, oscillatorGroup) in self.oscillators.enumerated() {
      for oscillator in oscillatorGroup {
        try! oscillator.connect(to: self.oscillatorMixers[index], format: format)
      }

      self.engine.connect(self.oscillatorMixers[index], to: self.mixer, format: format)
    }

    self.engine.connect(self.mixer, to: to, format: format)
  }

  open func playNote(frequency: Float) {
    if !self.enabled || self.stopped {
      return
    }

    let polyphonyChannel: Int = self.currentPolyphonyChannel

    self.playIndex[polyphonyChannel] += 1

    if self.playIndex[polyphonyChannel] + 2 >= UInt64.max {
      self.playIndex[polyphonyChannel] = 0
    }

    let currentPlayIndex: UInt64 = self.playIndex[polyphonyChannel]

    func fadeTo(from: Float, to: Float, duration: Float = 1.0, onComplete: @escaping (() -> Void) = {}) {
      if currentPlayIndex != self.playIndex[polyphonyChannel] {
        return
      }

      let steps: Int = .init(duration * 60.0)

      for i in 0 ... steps {
        let delayTime: Double = .init(duration / Float(steps) * Float(i))

        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
          if currentPlayIndex != self.playIndex[polyphonyChannel] {
            return
          }

          let step: Float = (from - to) / Float(steps)
          var newVolume: Float = from - (Float(i) * step)

          if from > to {
            newVolume = max(min(newVolume, from), to)
          } else {
            newVolume = min(max(newVolume, from), to)
          }

          self.oscillatorMixers[polyphonyChannel].outputVolume = newVolume

          if i == steps {
            onComplete()
          }
        }
      }
    }

    if self.resetVolumeOnNote {
      self.oscillatorMixers[polyphonyChannel].outputVolume = 0
    }

    for oscillator in self.oscillators[polyphonyChannel] {
      oscillator.setFrequency(frequency: frequency)
    }

    fadeTo(from: self.oscillatorMixers[polyphonyChannel].outputVolume, to: 1, duration: self.attack) {
      fadeTo(from: 1, to: self.sustain, duration: self.decay) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.sustainDuration)) {
          fadeTo(from: self.sustain, to: 0, duration: self.release)
        }
      }
    }

    self.currentPolyphonyChannel += 1

    if self.currentPolyphonyChannel >= self.oscillators.count {
      self.currentPolyphonyChannel = 0
    }
  }
}
