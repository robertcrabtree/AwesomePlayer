//
//  AwesomePlayer.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import AVKit

// MARK: - Delegate definition

/**
 The delegate for AwesomePlayer
 */
public protocol AwesomePlayerDelegate: AnyObject {

    /**
     Indicates the player is ready. When the player is ready the thumbs have been generated and the player play.
     */
    func awesomePlayerReady()

    /**
     Indicates that the clip has played to completion.
     */
    func awesomePlayerClipEnded()

    /**
     Indicates that the player has failed.

     - Parameter error: The error that occurred
     */
    func awesomePlayerFailed(with error: AwesomePlayer.Error)

    /**
     Indicates that the player has advanced to new time in the clip

     - Parameter seconds: The time that the player has advancd to
     */
    func awesomePlayerTimeValueReady(_ seconds: Double)
}

// MARK: - AwesomePlayer definition

/**
 The best video player there is.

 With `AwesomePlayer` you can play, pause, seek, and generate thumbnails for the specified video clip.
 */
public class AwesomePlayer {

    // MARK: - Public types

    /**
     The player's state
     */
    public enum State {

        /**
         The initial state before the player is ready.
         */
        case notReady

        /**
         The state that indicates the player is stopped.

         The player will enter the `stopped` state once the player is ready. The player will also move to the `stopped`
         state when the clip has finished playing.
         */
        case stopped

        /**
         The state while the player is playing.

         Call `play()` to enter the `playing` state.
         */
        case playing

        /**
         The state when the player has been paused.

         Call `pause()` to enter the    `paused` state.
         */
        case paused
    }

    /**
     Potential erros that may occur while interacting with the player.
     */
    public enum Error: Swift.Error {

        /**
         Indicates a method was called in the wrong state.
         */
        case invalidState

        /**
         Indicates that the player failed to generate thumbnails.
         */
        case thumbGeneration

        /**
         Indicates that an internal error occurred.
         */
        case `internal`
    }

    /**
     The layer type that is used to render video.
     */
    public typealias Layer = AVPlayerLayer

    // MARK: - Public properties

    /**
     The delegate property.
     */
    public weak var delegate: AwesomePlayerDelegate?

    /**
     The video clip thumbnails.

     The thumbnails are ready once the `awesomePlayerReady()` delegate method is called. The player will generate a
     number of thumbnails according to the interval you specify in the `init()` method.
     */
    private(set) var thumbs: [UIImage] = []

    /**
     The layer that the player will render video to.
     */
    private(set) lazy var layer: Layer = Layer(player: player)

    /**
     The length of the video clip in seconds.
     */
    public var duration: Double {
        return state == .notReady ? 0.0 : item.duration.seconds
    }

    /**
     The current time of the video clip in seconds.
     */
    public var currentTime: Double {
        return state == .notReady ? 0.0 : item.currentTime().seconds
    }

    /**
     The current state of the player.
     */
    private(set) var state: State = .notReady

    // MARK: - Private properties

    private let url: URL

    private let thumbInterval: Int

    private let log: Log

    private let asset: AVAsset

    private let item: AVPlayerItem

    private let player: AVPlayer

    private var timeObserverToken: Any?

    private var statusObserverToken: NSKeyValueObservation?

    private var playerEndObserverToken: NSObjectProtocol?

    // MARK: - Public methods

    /**
     The init method

     - Parameter url: The URL of the video clip to play.
     - Parameter thumbInterval: The thumbnail interval in seconds. The player will generate a thumbnail every
     thumbInterval seconds.
     - Parameter log: The log utility.
     */
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

    /**
     Prepares the player for use.

     When the player is ready it will call the `awesomePlayerReady()` delegate method. The `play()`, `pause()`,
     and `seek(to:)` methods cannot be called until the player is ready.

     - Throws: An AwesomePlayer.invalidState if the player is already ready
     */
    public func getReady() throws {
        guard state == .notReady else { throw Error.invalidState }
        log.high("Player getting ready")
        playerEndObserverToken = observePlayerEnd()
        statusObserverToken = observePlayerStatus()
    }

    /**
     Starts the player.

     When the `play()` method is called the player will start playing the clip. When the clip has finished playing
     the `awesomePlayerClipEnded()` delegate method is called.

     - Throws: An AwesomePlayer.invalidState if the player is not ready
     */
    public func play() throws {
        guard state != .notReady else { throw Error.invalidState }
        log.high("Start player")

        // If we are at the end of the clip we should seek to the beginning so we can play
        // from the beginning.
        if state == .stopped {
            player.seek(to: .zero)
        }

        state = .playing
        player.play()
    }

    /**
     Pauses the player.

     - Throws: An AwesomePlayer.invalidState if the player is not ready
     */
    public func pause() throws {
        guard state != .notReady else { throw Error.invalidState }
        log.high("Pause player")
        state = .paused
        player.pause()
    }

    /**
     Advances the player to the specified position.

     - Parameter value: A value between 0.0 and 1.0. 0.0 indicates the beginning of the clip, 1.0 indicates the end
     of the clip.
     - Parameter completion: A completion block that is called when complete..

     - Throws: An AwesomePlayer.invalidState if the player is not ready
     */
    public func seek(to value: Double, completion: ((Bool) -> Void)? = nil) throws {
        guard state != .notReady else { throw Error.invalidState }

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
}

// MARK: - Private methods

private extension AwesomePlayer {

    private func processPlayerReady() {
        log.high("Player ready")

        // if the app goes to the background this method will get called again
        // when re-entering the foreground. If we already have thumbs then
        // we don't need to do anything.
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
            self.delegate?.awesomePlayerClipEnded()
        }
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
            guard let self = self else { return }
            self.log.low("Time ready: \(time.seconds)")
            self.delegate?.awesomePlayerTimeValueReady(time.seconds)
        }
    }
}
