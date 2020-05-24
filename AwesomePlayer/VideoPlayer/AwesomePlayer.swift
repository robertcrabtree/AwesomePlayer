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
    func awesomePlayerFailed(with error: AwesomePlayer.Error)
    func awesomePlayerTimeValueReady(_ seconds: Double)
}

// MARK: - Props and public methods

public class AwesomePlayer {

    public enum State {
        case none
        case stopped
        case playing
        case paused
    }

    public enum Error: Swift.Error {
        case invalidState
        case thumbGeneration
        case `internal`
    }

    public typealias Layer = AVPlayerLayer

    public weak var delegate: AwesomePlayerDelegate?

    private(set) var thumbs: [UIImage] = []

    public var duration: Double {
        return state == .none ? 0.0 : item.duration.seconds
    }

    public var currentTime: Double {
        return state == .none ? 0.0 : item.currentTime().seconds
    }

    private(set) var state: State = .none

    private let url: URL

    private let thumbInterval: Int

    private let log: Log

    private let asset: AVAsset

    private let item: AVPlayerItem

    private let player: AVPlayer

    private var timeObserverToken: Any?

    private var statusObserverToken: NSKeyValueObservation?

    private var playerEndObserverToken: NSObjectProtocol?

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
    }

    deinit {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
        if let playerEndObserverToken = playerEndObserverToken {
            NotificationCenter.default.removeObserver(playerEndObserverToken)
        }
        statusObserverToken?.invalidate()
    }

    public func getReady() throws {
        guard state == .none else { return }
        log.high("Player getting ready")
        playerEndObserverToken = observePlayerEnd()
        statusObserverToken = observePlayerStatus()
    }

    public func play() throws {
        guard state != .none else { throw Error.invalidState }
        log.high("Start player")

        // If we are at the end of the clip we should seek to the beginning so we can play
        // from the beginning.
        if state == .stopped {
            player.seek(to: .zero)
        }

        state = .playing
        player.play()
    }

    public func pause() throws {
        guard state != .none else { throw Error.invalidState }
        log.high("Pause player")
        state = .paused
        player.pause()
    }

    public func seek(to value: Double, completion: ((Bool) -> Void)? = nil) throws {
        guard state != .none else { throw Error.invalidState }

        log.low("Seeking to \(value)")

        // If play hasn't been called but seeking is occurring then go to the paused state.
        // If play is called then it will play from the time we seeked to.
        if state == .stopped {
            state = .paused
        }

        let duration = item.duration.seconds
        let time = CMTime(
            value: CMTimeValue(duration * value * Double(NSEC_PER_SEC)),
            timescale: CMTimeScale(NSEC_PER_SEC)
        )
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in

            // If we arrived to the end of the clip then move out of the playing/paused state.
            // When play is called again the clip will start at the beginning.
            if finished && self.item.duration.seconds == self.item.currentTime().seconds {
                self.state = .stopped
            }
            completion?(finished)
        }
    }

    public func makeLayer() -> Layer {
        return Layer(player: player)
    }
}

// MARK: - Private methods

private extension AwesomePlayer {

    private func processPlayerReady() {
        log.high("Player ready")

        // if the app goes to the background this method will get called again
        // when re-entering the foreground. if we already have thumbs then
        // we don't need to do anything
        guard thumbs.count == 0 else { return }

        do {
            try generateThumbs()
            state = .stopped
            timeObserverToken = observeTimes()
            delegate?.awesomePlayerReady()
        } catch {
            delegate?.awesomePlayerFailed(with: Error.thumbGeneration)
        }
    }

    private func generateThumbs() throws {

        log.high("Generating thumbs")

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

    private func observePlayerEnd() -> NSObjectProtocol {
        let center = NotificationCenter.default
        return center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            self.log.high("Player ended")
            self.state = .stopped
            self.delegate?.awesomePlayerEnded()
        }
    }

    private func observePlayerStatus() -> NSKeyValueObservation {
        return item.observe(\.status, options: [.initial, .new]) { [weak self] player, _ in
            guard let self = self else { return }
            if player.status == .readyToPlay {
                self.processPlayerReady()
            } else if player.status == .failed {
                self.state = .none
                self.delegate?.awesomePlayerFailed(with: Error.internal)
            }
        }
    }

    private func observeTimes() -> Any {
        let timeInSeconds = 0.001
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        return player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.log.low("Time ready: \(time.seconds)")
            self.delegate?.awesomePlayerTimeValueReady(time.seconds)
        }
    }
}
