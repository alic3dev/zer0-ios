//
//  Synth.swift
//  zer0-ios
//
//  Created by Alice Grace on 5/12/24.
//

import AVFAudio
import Foundation

public enum PlayMode {
  case device, sequencer
}

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
  
  public var playMode: PlayMode = .device

  private var srcNode: AVAudioSourceNode?
  private var onRender: onSynthRenderFunc = {}

  private var engine: AVAudioEngine
  private var sampleRate: Float
  private var connectedTo: AVAudioNode?
  private var connectedFormat: AVAudioFormat?
  private var oscillators: [[Oscillator]] = []
  private var oscillatorMixers: [AVAudioMixerNode] = []
  private var preMixer: AVAudioMixerNode = .init()
  private var volume: Float
  private var polyphony: UInt8
  private var currentPolyphonyChannel: Int = 0
  private var playIndex: [UInt64] = []

  public var name: String = "Default Synth"
  public var enabled: Bool = true
  public var stopped: Bool = false

  public var mixer: AVAudioMixerNode = .init()

  public var bpm: Float = 90.0
  public var attack: Float = 0.19 * 6
  public var decay: Float = 0.19 * 6
  public var sustain: Float = 0.75
  public var sustainDuration: Float = 0.1 * 2
  public var release: Float = 0.38 * 6

  public var modifiers: [SynthModifier] = []

  public var effectChain: [AVAudioUnit] = []

  public var resetVolumeOnNote: Bool = true

  public init(engine: AVAudioEngine, sampleRate: Float, oscillators: [Oscillator]? = nil, volume: Float = 1.0, polyphony: UInt8 = 1, bpm: Float = 90.0) {
    self.engine = engine
    self.sampleRate = sampleRate
    self.volume = volume

    self.engine.attach(self.preMixer)
    self.preMixer.outputVolume = 1.0

    self.engine.attach(self.mixer)
    self.mixer.outputVolume = self.volume

    self.polyphony = polyphony
    self.bpm = bpm

    for _ in 1 ... self.polyphony {
      self.oscillators.append([])

      let oscillatorMixer: AVAudioMixerNode = .init()
      self.engine.attach(oscillatorMixer)
      oscillatorMixer.outputVolume = 1.0

      self.oscillatorMixers.append(oscillatorMixer)

      self.playIndex.append(0)
    }

    if oscillators != nil {
      self.addOscillator(oscillators!)
    }
  }
  
  public func getPolyphony() -> UInt8 {
    return self.polyphony;
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

  public func addEffect(effect: AVAudioUnit, reconnect: Bool = true) {
    self.engine.attach(effect)
    self.effectChain.append(effect)

    if reconnect && self.connectedTo != nil {
      self.connectEffects()
    }
  }

  public func removeEffect(at: Int) {
    self.effectChain.remove(at: at)
  }

  public func removeEffect(effect: AVAudioUnit) {
    self.effectChain.removeAll { $0 == effect }
  }

  open func start() {
    self.start {}
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

  public func connectEffects() {
    self.engine.disconnectNodeInput(self.mixer)
    self.engine.disconnectNodeOutput(self.preMixer)

    let effectsCount: Int = self.effectChain.count

    if effectsCount > 0 {
      for effect in self.effectChain {
        self.engine.disconnectNodeOutput(effect)
        self.engine.disconnectNodeInput(effect)
      }

      for i in 0 ... (effectsCount - 1) {
        if i == 0 {
          self.engine.connect(self.preMixer, to: self.effectChain[i], format: self.connectedFormat)
        }

        if i + 1 == effectsCount {
          self.engine.connect(self.effectChain[i], to: self.mixer, format: self.connectedFormat)
        } else {
          self.engine.connect(
            self.effectChain[i],
            to: self.effectChain[i + 1],
            format: self.connectedFormat
          )
        }
      }
    } else {
      self.engine.connect(self.preMixer, to: self.mixer, format: self.connectedFormat)
    }
  }

  public func connect(to: AVAudioNode, format: AVAudioFormat?) throws {
    self.connectedTo = to
    self.connectedFormat = format

    self.engine.disconnectNodeOutput(self.srcNode!)
    self.engine.disconnectNodeInput(self.mixer)
    self.engine.disconnectNodeInput(self.preMixer)
    self.engine.disconnectNodeOutput(self.preMixer)

    self.engine.connect(self.srcNode!, to: self.mixer, format: self.connectedFormat)

    for (index, oscillatorGroup) in self.oscillators.enumerated() {
      self.engine.disconnectNodeInput(self.oscillatorMixers[index])
      self.engine.disconnectNodeOutput(self.oscillatorMixers[index])

      for oscillator in oscillatorGroup {
        try! oscillator.connect(to: self.oscillatorMixers[index], format: self.connectedFormat)
      }

      self.engine.connect(
        self.oscillatorMixers[index],
        to: self.preMixer,
        format: self.connectedFormat
      )
    }

    self.connectEffects()

    self.engine.connect(self.mixer, to: self.connectedTo!, format: self.connectedFormat)
  }

  public func playNote(frequency: Float) {
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

//      let bpmRatio: Float = (60 / self.bpm)

      //  5.25 seconds
      //  public var attack: Float = 1.0
      //  public var decay: Float = 1.0
      //  public var sustain: Float = 0.75
      //  public var sustainDuration: Float = 0.5
      //  public var release: Float = 2.0

      let steps = 60
      var curStep = 0

      let stepInterval: Float = (from - to) / Float(steps)

      let delayTimeInterval: Double = .init((duration * (60.0 / self.bpm)) / Float(steps))

      for i in 0 ... steps {
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTimeInterval * Double(i)) {
          if currentPlayIndex != self.playIndex[polyphonyChannel] || i < curStep {
            return
          }

          curStep = i

          var newVolume: Float = from - (Float(i) * stepInterval)

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

    func playRelease() {
      if self.release <= 0 {
        self.oscillatorMixers[polyphonyChannel].outputVolume = 0
      } else {
        fadeTo(from: self.sustain, to: 0, duration: self.release)
      }
    }

    func playSustain() {
      if self.sustainDuration <= 0 {
        playRelease()
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.sustainDuration * (60.0 / self.bpm))) {
          playRelease()
        }
      }
    }

    func playDecay() {
      if self.decay <= 0 {
        self.oscillatorMixers[polyphonyChannel].outputVolume = self.sustain
        playSustain()
      } else {
        fadeTo(from: 1, to: self.sustain, duration: self.decay) {
          playSustain()
        }
      }
    }

    func playAttack() {
      if self.attack <= 0 {
        self.oscillatorMixers[polyphonyChannel].outputVolume = 1
        playDecay()
      } else {
        fadeTo(from: self.oscillatorMixers[polyphonyChannel].outputVolume, to: 1, duration: self.attack) {
          playDecay()
        }
      }
    }

    playAttack()

//    fadeTo(from: self.oscillatorMixers[polyphonyChannel].outputVolume, to: 1, duration: self.attack) {
//      fadeTo(from: 1, to: self.sustain, duration: self.decay) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.sustainDuration)) {
//          fadeTo(from: self.sustain, to: 0, duration: self.release)
//        }
//      }
//    }

//    fadeTo(from: self.oscillatorMixers[polyphonyChannel].outputVolume, to: 1, duration: self.attack) {
//      fadeTo(from: 1, to: self.sustain, duration: self.decay) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.sustainDuration)) {
//          fadeTo(from: self.sustain, to: 0, duration: self.release)
//        }
//      }
//    }

    self.currentPolyphonyChannel += 1

    if self.currentPolyphonyChannel >= self.oscillators.count {
      self.currentPolyphonyChannel = 0
    }
  }
}
