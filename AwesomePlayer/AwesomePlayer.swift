//
//  AwesomePlayer.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import AVKit

// MARK: - Delegate definition

public protocol AwesomePlayerDelegate: AnyObject {
    func awesomePlayerReady()
    func awesomePlayerEnded()
    func awesomePlayerFailed(with error: Error)
    func awesomePlayerTimeValueReady(_ seconds: Double)
}

// MARK: - Props and public methods

public class AwesomePlayer: NSObject {

    public enum State {
        case notReady
        case idle
        case playing
        case paused
    }

    public enum Error: Swift.Error {
        case badState
        case thumbGeneration
        case `internal`
    }

    public typealias Layer = AVPlayerLayer

    public weak var delegate: AwesomePlayerDelegate?

    public var thumbs: [UIImage] = []

    public var duration: Double {
        return state == .notReady ? 0.0 : item.duration.seconds
    }

    public var currentTime: Double {
        return state == .notReady ? 0.0 : item.currentTime().seconds
    }

    private(set) var state: State = .notReady

    private let url: URL

    private let thumbInterval: Int

    private let log: Log

    private let asset: AVAsset

    private let item: AVPlayerItem

    private let player: AVPlayer

    private var timeObserverToken: Any?

    private var statusObserverToken: NSKeyValueObservation?

    public init(url: URL, thumbInterval: Int, log: Log) {

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        self.url = url
        self.thumbInterval = thumbInterval
        self.log = log
        self.asset = asset
        self.item = item
        self.player = player

        super.init()
    }

    deinit {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        statusObserverToken?.invalidate()
    }

    public func getReady() throws {
        guard state == .notReady else { return }
        log.high("Player getting ready")
        observePlayerEnd()
        statusObserverToken = observePlayerStatus()
    }

    public func play() throws {
        guard state != .notReady else { throw Error.badState }
        log.high("Start player")

        if state == .idle {
            player.seek(to: .zero)
        }

        state = .playing
        player.play()
    }

    public func pause() throws {
        guard state != .notReady else { throw Error.badState }
        log.high("Pause player")
        state = .paused
        player.pause()
    }

    public func seek(to value: Double, completion: ((Bool) -> Void)? = nil) throws {
        guard state != .notReady else { throw Error.badState }

        log.low("Seeking to \(value)")

        if state == .idle {
            state = .paused
        }

        let duration = item.duration.seconds
        let time = CMTime(
            value: CMTimeValue(duration * value * Double(NSEC_PER_SEC)),
            timescale: CMTimeScale(NSEC_PER_SEC)
        )
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished && self.item.duration.seconds == self.item.currentTime().seconds {
                self.state = .idle
            }
            completion?(finished)
        }
    }

    public func makeLayer() -> Layer {
        return Layer(player: player)
    }
}

// MARK: - Action methods

private extension AwesomePlayer {

    @objc private func playerDidEnd() {
        log.high("Player ended")
        state = .idle
        delegate?.awesomePlayerEnded()
    }
}

// MARK: - Private methods

private extension AwesomePlayer {

    private func processPlayerReady() {
        log.high("Player ready")
        do {
            try generateThumbs()
            state = .idle
            timeObserverToken = observeTimes()
            delegate?.awesomePlayerReady()
        } catch {
            delegate?.awesomePlayerFailed(with: Error.thumbGeneration)
        }
    }

    private func generateThumbs() throws {

        let duration = Int(item.duration.seconds)

        guard duration > 0 else { throw Error.thumbGeneration }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        var timeValue = 0
        repeat {
            let time = CMTime(value: CMTimeValue(timeValue), timescale: 1)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            thumbs.append(.init(cgImage: image))
            timeValue += thumbInterval
        } while timeValue < duration

        log.high("Generated \(thumbs.count) thumbs")
    }

    private func observePlayerEnd() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidEnd),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    private func observePlayerStatus() -> NSKeyValueObservation {
        return item.observe(\.status, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            if player.status == .readyToPlay {
                self.processPlayerReady()
            } else if player.status == .failed {
                self.state = .notReady
                self.delegate?.awesomePlayerFailed(with: Error.internal)
            }
        }
    }

    private func observeTimes() -> Any {
        let timeInSeconds = 0.001
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        return player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            self?.log.low("Time ready: \(time.seconds)")
            self?.delegate?.awesomePlayerTimeValueReady(time.seconds)
        }
    }
}
