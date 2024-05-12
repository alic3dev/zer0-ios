//
//  Frequencies.swift
//  Edat
//
//  Created by Alice Grace on 5/5/24.
//

import Foundation

//  export type Note =
//    | 'A'
//    | 'A#'
//    | 'B'
//    | 'C'
//    | 'C#'
//    | 'D'
//    | 'D#'
//    | 'E'
//    | 'F'
//    | 'F#'
//    | 'G'
//    | 'G#'
//
//  export const notes: Note[] = [
//    'C',
//    'C#',
//    'D',
//    'D#',
//    'E',
//    'F',
//    'F#',
//    'G',
//    'G#',
//    'A',
//    'A#',
//    'B',
//  ]
//
//  export type Octave = {
//    [note in Note]: number
//  }

public enum FrequencyRoot: Float {
  case standard = 440
  case magic = 432
  case scientific = 430.54
}

public func createNoteTable(startingOctave: Int = 0, endingOctave: Int = 10, frequencyRoot: FrequencyRoot = .standard) -> [[Float]] {
  var noteTable: [[Float]] = []

  for octave in startingOctave ... endingOctave {
    let octaveF = Float(octave)
    var octaveTable: [Float] = []

    for y in 0 ... 11 {
      let noteOffset: Float = (-57.0 + Float(y))
      let frequencyOffset: Float = powf(2, (noteOffset + octaveF * 12) / 12)
      let note: Float = frequencyOffset * frequencyRoot.rawValue

      octaveTable.append(note)
    }

    noteTable.append(octaveTable)
  }

  return noteTable
}
