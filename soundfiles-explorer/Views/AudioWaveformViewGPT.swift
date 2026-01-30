//
//  AudioWaveformView.swift
//  soundfiles-explorer
//
//  Created by Américo Cot  on 28/1/26.
//

import AppKit
import AVFoundation
import QuartzCore

final class AudioWaveformViewGPT: NSView {

    // MARK: - Public Configuration

    var samplesPerPixel: Int = 200
    var channelSpacing: CGFloat = 12
    var rulerHeight: CGFloat = 24
    var waveformColor: NSColor = .systemBlue
    var playheadColor: NSColor = .systemRed
    var rulerTextColor: NSColor = .secondaryLabelColor

    // MARK: - Private State

    private var asset: AVAsset?
    private var duration: CMTime = .zero
    private var channelWaveforms: [[Float]] = []
    private var channelCount: Int = 0

    private weak var player: AVPlayer?
    private var displayLink: CVDisplayLink?

    // Layers
    private let contentLayer = CALayer()
    private let playheadLayer = CALayer()
    private let rulerLayer = CALayer()

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layer Setup

    private func setupLayers() {
        guard let root = layer else { return }

        contentLayer.frame = bounds
        contentLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        root.addSublayer(contentLayer)

        rulerLayer.frame = CGRect(x: 0, y: bounds.height - rulerHeight,
                                  width: bounds.width, height: rulerHeight)
        root.addSublayer(rulerLayer)

        playheadLayer.backgroundColor = playheadColor.cgColor
        playheadLayer.frame = CGRect(x: 0, y: 0, width: 1, height: bounds.height)
        root.addSublayer(playheadLayer)
    }

    override func layout() {
        super.layout()
        contentLayer.frame = bounds
        rulerLayer.frame = CGRect(x: 0, y: bounds.height - rulerHeight,
                                  width: bounds.width, height: rulerHeight)
        playheadLayer.frame.size.height = bounds.height
        redrawWaveforms()
        drawRuler()
    }

    // MARK: - Public API

    func loadAudio(url: URL) async {
        asset = AVAsset(url: url)
        // duration = asset?.duration ?? .zero
        do {
            self.duration = try await (asset?.load(.duration))!
            await extractWaveforms()
        } catch {
            print("Error: \(error)")
        }
        
    }

    func attachPlayer(_ player: AVPlayer) {
        self.player = player
        startDisplayLink()
    }

    // MARK: - Waveform Extraction

    private func extractWaveforms() async {
        guard let asset else { return }
        do {
            let track = try await asset.load(.tracks).first! //tracks(withMediaType: .audio).first!
            channelCount = try await track.load(.formatDescriptions)
                .compactMap {
                    CMAudioFormatDescriptionGetStreamBasicDescription($0 )
                        .map { Int($0.pointee.mChannelsPerFrame) }
                }
                .max() ?? 1

            channelWaveforms = Array(repeating: [], count: Int(channelCount))
            let reader = try! AVAssetReader(asset: asset)

            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false
            ]

            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(output)
            reader.startReading()

            var sampleBufferCount = 0

            while let buffer = output.copyNextSampleBuffer(),
                  let block = CMSampleBufferGetDataBuffer(buffer) {

                let length = CMBlockBufferGetDataLength(block)
                var data = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                CMBlockBufferCopyDataBytes(block, atOffset: 0,
                                           dataLength: length, destination: &data)

                for i in stride(from: 0, to: data.count, by: Int(channelCount)) {
                    if sampleBufferCount % samplesPerPixel == 0 {
                        for ch in 0..<Int(channelCount) {
                            channelWaveforms[ch].append(abs(data[i + ch]))
                        }
                    }
                    sampleBufferCount += 1
                }
            }
        } catch {
            print("Error: \(error)")
        }

        redrawWaveforms()
    }

    // MARK: - Drawing

    private func redrawWaveforms() {
        guard bounds.width >= 1, bounds.height >= 1 else { return }

        contentLayer.sublayers?.removeAll()
        guard channelCount > 0 else { return }

        let availableHeight = bounds.height - rulerHeight
        let channelHeight = (availableHeight - CGFloat(channelCount - 1) * channelSpacing) / CGFloat(channelCount)

        for ch in 0..<channelCount {
            let y = availableHeight - CGFloat(ch + 1) * channelHeight - CGFloat(ch) * channelSpacing
            let layer = waveformLayer(for: channelWaveforms[ch],
                                      frame: CGRect(x: 0, y: y,
                                                    width: bounds.width,
                                                    height: channelHeight))
            contentLayer.addSublayer(layer)
        }
    }

    private func waveformLayer(for samples: [Float], frame: CGRect) -> CALayer {
        let layer = CALayer()
        layer.frame = frame

        guard !samples.isEmpty else { return layer }

        let pixelWidth = max(1, Int(frame.width.rounded(.down)))
        let step = max(1, samples.count / pixelWidth)

        let path = CGMutablePath()
        let midY = frame.height / 2

        for x in 0..<pixelWidth {
            let index = x * step
            guard index < samples.count else { break }

            let amplitude = CGFloat(samples[index]) * midY
            path.move(to: CGPoint(x: CGFloat(x), y: midY - amplitude))
            path.addLine(to: CGPoint(x: CGFloat(x), y: midY + amplitude))
        }

        let shape = CAShapeLayer()
        shape.path = path
        shape.strokeColor = waveformColor.cgColor
        shape.lineWidth = 1
        layer.addSublayer(shape)

        return layer
    }

    // MARK: - Ruler

    private func drawRuler() {
        rulerLayer.sublayers?.removeAll()
        guard duration.seconds > 0 else { return }

        let seconds = Int(duration.seconds)
        let pixelsPerSecond = bounds.width / CGFloat(duration.seconds)

        for s in 0...seconds {
            let x = CGFloat(s) * pixelsPerSecond

            let tick = CALayer()
            tick.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            tick.frame = CGRect(x: x, y: 0, width: 1, height: 8)
            rulerLayer.addSublayer(tick)

            let text = CATextLayer()
            text.string = "\(s)s"
            text.fontSize = 10
            text.foregroundColor = rulerTextColor.cgColor
            text.frame = CGRect(x: x + 2, y: 8, width: 30, height: 14)
            rulerLayer.addSublayer(text)
        }
    }

    // MARK: - Playhead Tracking

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        displayLink = link

        CVDisplayLinkSetOutputCallback(displayLink!, { _, _, _, _, _, context in
            let view = Unmanaged<AudioWaveformViewGPT>
                .fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                view.updatePlayhead()
            }
            return kCVReturnSuccess
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        CVDisplayLinkStart(displayLink!)
    }

    private func updatePlayhead() {
        guard let player else { return }
        let current = player.currentTime().seconds
        let progress = current / duration.seconds
        playheadLayer.frame.origin.x = bounds.width * CGFloat(progress)
    }

    deinit {
        if let displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}

