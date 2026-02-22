//
//  Data+Audio.swift
//  BookVoice
//

import Foundation

extension Data {
    enum AudioFileType {
        case wav, mp3, m4a, flac, unknown
    }

    var detectedAudioType: AudioFileType {
        guard count >= 4 else { return .unknown }
        let header = [UInt8](prefix(4))

        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            return .wav
        }
        if header[0] == 0xFF && (header[1] & 0xE0) == 0xE0 {
            return .mp3
        }
        if header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33 {
            return .mp3
        }
        if count >= 8 {
            let extended = [UInt8](prefix(8))
            if extended[4] == 0x66 && extended[5] == 0x74 && extended[6] == 0x79 && extended[7] == 0x70 {
                return .m4a
            }
        }
        if header[0] == 0x66 && header[1] == 0x4C && header[2] == 0x61 && header[3] == 0x43 {
            return .flac
        }

        return .unknown
    }
}
