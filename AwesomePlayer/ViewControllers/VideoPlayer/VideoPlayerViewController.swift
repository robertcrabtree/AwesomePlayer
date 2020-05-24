//
//  VideoPlayerViewController.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import UIKit

// MARK: - VideoPlayerViewController definition

class VideoPlayerViewController: UIViewController {

    // MARK: - IBOutlets

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var playButton: UIButton!

    // MARK: - Dependencies

    public var videoURL: URL!

    public var log: Log!

    // MARK: - Private properties

    private lazy var playButtonImage: UIImage = {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold, scale: .large)
        return UIImage(systemName: "play.circle", withConfiguration: imageConfig) ?? UIImage()
    }()

    private lazy var pauseButtonImage: UIImage = {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold, scale: .large)
        return UIImage(systemName: "pause.circle", withConfiguration: imageConfig) ?? UIImage()
    }()

    private let thumbWidth: CGFloat = 100

    private lazy var player: AwesomePlayer = AwesomePlayer(
        url: videoURL,
        thumbInterval: 5,
        layer: videoLayer,
        log: log
    )

    private lazy var videoLayer = AwesomePlayer.Layer()

    private var thumbStripOffset: CGPoint = .zero

    private var isScrubbing: Bool = false

    private var playAfterScrubbing: Bool = false

    private var areSubviewsReady: Bool = false

    private var resignToken: NSObjectProtocol?

    // MARK: - View life cycle methods

    override func viewDidLoad() {
        super.viewDidLoad()

        log.high("viewDidLoad")

        playButton.setImage(playButtonImage, for: .normal)

        player.delegate = self

        collectionView.delegate = self
        collectionView.dataSource = self

        do {
            try player.getReady()
        } catch {
            log.error("Player failed to get ready with error: \(error)")
        }

        collectionView.backgroundColor = UIColor.black.withAlphaComponent(0.75)

        let center = NotificationCenter.default
        resignToken = center.addObserver(forName: .willResign, object: nil, queue: .main) { _ in
            self.log.high("Resigning")
            self.pause()
        }

        let tapper = UITapGestureRecognizer(target: self, action: #selector(videoTapped(_:)))
        videoView.addGestureRecognizer(tapper)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !areSubviewsReady {

            log.high("Init subviews")

            videoLayer.frame = videoView.bounds
            videoLayer.videoGravity = .resizeAspectFill
            videoView.layer.addSublayer(videoLayer)

            collectionView.contentInset = UIEdgeInsets(
                top: 0,
                left: collectionView.bounds.width / 2,
                bottom: 0,
                right: collectionView.bounds.width / 2
            )

            thumbStripOffset = collectionView.contentOffset
        }

        areSubviewsReady = true
    }

    deinit {
        if let resignToken = resignToken {
            NotificationCenter.default.removeObserver(resignToken)
        }
    }
}

// MARK: - UICollectionViewDataSource methods

extension VideoPlayerViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return player.thumbs.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "VideoThumbCell",
            for: indexPath
        )

        if let videoThumbCell = cell as? VideoThumbCell {
            videoThumbCell.imageView.image = player.thumbs[indexPath.item]
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout methods

extension VideoPlayerViewController: UICollectionViewDelegateFlowLayout {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        log.high("Start scrubbing")
        isScrubbing = true
        playAfterScrubbing = player.state == .playing
        try! player.pause()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isScrubbing {
            let totalDistance = CGFloat(player.thumbs.count) * thumbWidth
            let currentDistance = -thumbStripOffset.x + collectionView.contentOffset.x
            let percent = min(1.0, max(0.0, currentDistance / totalDistance))
            do {
                try player.seek(to: Double(percent))
            } catch {
                showOkAlert(title: "Scrubbing failed", message: nil)
            }
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            log.high("Stop scrubbing")
            finishScrubbing()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        log.high("Stop scrubbing")
        finishScrubbing()
    }
}

// MARK: - Action methods

extension VideoPlayerViewController {

    @IBAction func onPlayButtonTouched(_ sender: UIButton) {
        log.high("Play button pressed")
        togglePlay()
    }

    @objc func videoTapped(_ sender: UITapGestureRecognizer) {
        log.high("Video tapped")
        togglePlay()
    }
}

// MARK: - AwesomePlayerDelegate methods

extension VideoPlayerViewController: AwesomePlayerDelegate {

    func awesomePlayerReady() {
        collectionView.reloadData()
    }

    func awesomePlayerClipEnded() {
        playButton.setImage(playButtonImage, for: .normal)
    }

    func awesomePlayerFailed(with error: AwesomePlayer.Error) {
        showOkAlert(title: "Awesome player failed", message: "\(error)")
    }

    func awesomePlayerTimeValueReady(_ seconds: Double) {
        updateTimeLabel(seconds: seconds)

        if !isScrubbing {
            let ratio = CGFloat(seconds / player.duration)
            let totalDistance = CGFloat(player.thumbs.count) * thumbWidth
            collectionView.contentOffset = CGPoint(
                x: thumbStripOffset.x + totalDistance * ratio,
                y: thumbStripOffset.y
            )
        }
    }
}

// MARK: - Private methods

extension VideoPlayerViewController {

    private func play() {
        if player.currentTime == player.duration {
            try! player.seek(to: 0.0)
        }
        try! player.play()
        playButton.setImage(pauseButtonImage, for: .normal)
    }

    private func pause() {
        try! player.pause()
        playButton.setImage(playButtonImage, for: .normal)
    }

    private func updateTimeLabel(seconds: Double) {
        let minutes = Int(seconds / 60)
        let seconds = Int(seconds) % 60
        timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    private func togglePlay() {

        guard player.isReadyToPlay else {
            showOkAlert(title: "Player is not ready", message: nil)
            return
        }

        switch player.state {
        case .paused, .stopped:
            play()
        case .playing:
            pause()
        }
    }

    private func finishScrubbing() {
        isScrubbing = false
        if playAfterScrubbing {
            if player.currentTime != player.duration {
                try! player.play()
            } else {
                playButton.setImage(playButtonImage, for: .normal)
            }
            playAfterScrubbing = false
        }
    }
}
