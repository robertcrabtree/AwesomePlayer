//
//  VideoPlayerViewController.swift
//  AwesomePlayer
//
//  Created by Rob Crabtree on 5/24/20.
//  Copyright © 2020 Certified Organic Software. All rights reserved.
//

import UIKit

class VideoPlayerViewController: UIViewController {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var playButton: UIButton!

    lazy var playButtonImage: UIImage = {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold, scale: .large)
        return UIImage(systemName: "play.circle", withConfiguration: imageConfig) ?? UIImage()
    }()

    lazy var pauseButtonImage: UIImage = {
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .bold, scale: .large)
        return UIImage(systemName: "pause.circle", withConfiguration: imageConfig) ?? UIImage()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        playButton.setImage(playButtonImage, for: .normal)
    }
}

