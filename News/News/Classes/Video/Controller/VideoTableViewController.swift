//
//  VideoTableViewController.swift
//  News
//
//  Created by 杨蒙 on 2018/1/17.
//  Copyright © 2018年 hrscy. All rights reserved.
//

import UIKit
import SVProgressHUD
import RxSwift
import RxCocoa
import BMPlayer
import NVActivityIndicatorView
import SnapKit

class VideoTableViewController: UITableViewController {
    /// 播放器
    private lazy var player: BMPlayer = BMPlayer(customControlView: VideoPlayerCustomView())
    
    private lazy var disposeBag = DisposeBag()
    /// 标题
    var newsTitle = HomeNewsTitle()
    /// 视频数据
    var videos = [NewsModel]()
    /// 刷新时间
    private var maxBehotTime: TimeInterval = 0.0
    /// 上一次播放的 cell
    private var priorCell: VideoCell?
    /// 视频真实地址
    private var realVideo = RealVideo()
    /// 当前播放的时间
    var currentTime: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SVProgressHUD.configuration()
        player.delegate = self
        tableView.tableFooterView = UIView()
        tableView.rowHeight = screenWidth * 0.67
        tableView.ym_registerCell(cell: VideoCell.self)
        // 设置刷新控件
        setupRefresh()
    }
    
    /// 设置刷新控件
    private func setupRefresh() {
        // 刷新头部
        let header = RefreshHeader { [weak self] in
            // 如果有正在播放的视频，先停止播放，并移除播放器
            if self!.player.isPlaying { self!.removePlayer() }
            // 获取视频的新闻列表数据
            NetworkTool.loadApiNewsFeeds(category: self!.newsTitle.category, ttFrom: .pull, {
                if self!.tableView.mj_header.isRefreshing { self!.tableView.mj_header.endRefreshing() }
                self!.maxBehotTime = $0
                self!.videos = $1
                self!.tableView.reloadData()
            })
        }
        header?.isAutomaticallyChangeAlpha = true
        header?.lastUpdatedTimeLabel.isHidden = true
        tableView.mj_header = header
        tableView.mj_header.beginRefreshing()
        // 底部刷新控件
        tableView.mj_footer = RefreshAutoGifFooter(refreshingBlock: { [weak self] in
            // 获取视频的新闻列表数据，加载更多
            NetworkTool.loadMoreApiNewsFeeds(category: self!.newsTitle.category, ttFrom: .loadMore, maxBehotTime: self!.maxBehotTime, listCount: self!.videos.count, {
                    if self!.tableView.mj_footer.isRefreshing { self!.tableView.mj_footer.endRefreshing() }
                    self!.tableView.mj_footer.pullingPercent = 0.0
                    if $0.count == 0 {
                        SVProgressHUD.showInfo(withStatus: "没有更多数据啦！")
                        return
                    }
                    self!.videos += $0
                    self!.tableView.reloadData()
            })
        })
        tableView.mj_footer.isAutomaticallyChangeAlpha = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension VideoTableViewController {
    /// 视频播放时隐藏 cell 的部分子视图
    private func hideSubviews(of cell: VideoCell) {
        cell.titleLabel.isHidden = true
        cell.playCountLabel.isHidden = true
        cell.timeLabel.isHidden = true
        cell.vImageView.isHidden = true
        cell.avatarButton.isHidden = true
        cell.nameLable.isHidden = true
        cell.shareStackView.isHidden = false
    }
    
    /// 设置当前 cell 的属性
    private func showSubviews(of cell: VideoCell) {
        cell.titleLabel.isHidden = false
        cell.playCountLabel.isHidden = false
        cell.timeLabel.isHidden = false
        cell.avatarButton.isHidden = false
        cell.vImageView.isHidden = !cell.video.user_verified
        cell.nameLable.isHidden = false
        cell.shareStackView.isHidden = true
    }
    
    /// 把播放器添加到 cell 上
    private func addPlayer(on cell: VideoCell) {
        // 视频播放时隐藏 cell 的部分子视图
        hideSubviews(of: cell)
        // 解析头条的视频真实播放地址
        NetworkTool.parseVideoRealURL(video_id: cell.video.video_detail_info.video_id, completionHandler: {
            self.realVideo = $0
            cell.bgImageButton.addSubview(self.player)
            self.player.snp.makeConstraints({ $0.edges.equalTo(cell.bgImageButton) })
            // 设置视频播放地址
            self.player.setVideo(resource: BMPlayerResource(url: URL(string: $0.video_list.video_1.mainURL)!))
            self.priorCell = cell
        })
    }
    
    /// 移除播放器
    private func removePlayer() {
        player.pause()
        player.removeFromSuperview()
        priorCell = nil
    }
}

// MARK: - Table view data source
extension VideoTableViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videos.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.ym_dequeueReusableCell(indexPath: indexPath) as VideoCell
        cell.video = videos[indexPath.row]
        // 用户头像
        cell.avatarButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                let userDetailVC = UserDetailViewController2()
                userDetailVC.userId = cell.video.user_info.user_id
                self!.navigationController?.pushViewController(userDetailVC, animated: true)
            })
            .disposed(by: disposeBag)
        // 评论按钮点击
        cell.commentButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: {
                
            })
            .disposed(by: disposeBag)
        // 背景图片按钮点击
        cell.bgImageButton.rx.controlEvent(.touchUpInside)
            .subscribe(onNext: { [weak self] in
                // 如果有值，说明当前有正在播放的视频
                if let priorCell = self!.priorCell {
                    if cell != priorCell {
                        // 设置当前 cell 的属性
                        self!.showSubviews(of: priorCell)
                        // 判断当前播放器是否正在播放
                        if self!.player.isPlaying {
                            self!.player.pause()
                            self!.player.removeFromSuperview()
                        }
                        // 把播放器添加到 cell 上
                        self!.addPlayer(on: cell)
                    }
                } else { // 说明是第一次点击 cell，直接添加播放器
                    // 把播放器添加到 cell 上
                    self!.addPlayer(on: cell)
                }
            })
            .disposed(by: disposeBag)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // 当前点击的 cell
        let currentCell = tableView.cellForRow(at: indexPath) as! VideoCell
        // 如果播放器正在播放，则停止播放
        if player.isPlaying { removePlayer() }
        // 跳转到详情控制器
        let videoDetailVC = VideoDetailViewController()
        videoDetailVC.video = currentCell.video
        videoDetailVC.delegate = self
        videoDetailVC.currentTime = currentTime
        videoDetailVC.currentIndexPath = indexPath
        navigationController?.pushViewController(videoDetailVC, animated: true)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for viewController in navigationController!.viewControllers {
            if viewController is VideoViewController {
                // 说明有视频正在播放
                if player.isPlaying {
                    let imageButton = player.superview
                    let contentView = imageButton?.superview
                    let cell = contentView?.superview as! VideoCell
                    let rect = tableView.convert(cell.frame, to: viewController.view)
                    // 判断是否滑出屏幕
                    if (rect.origin.y <= -cell.height) || (rect.origin.y >= screenHeight - tabBarController!.tabBar.height) {
                        removePlayer()
                        // 设置当前 cell 的属性
                        showSubviews(of: cell)
                    }
                }
            }
        }
        
    }
}

extension VideoTableViewController: BMPlayerDelegate {
    
    func bmPlayer(player: BMPlayer, playerStateDidChange state: BMPlayerState) {
        
    }
    
    func bmPlayer(player: BMPlayer, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval) {
        
    }
    
    func bmPlayer(player: BMPlayer, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval) {
        self.currentTime = currentTime
    }
    
    func bmPlayer(player: BMPlayer, playerIsPlaying playing: Bool) {
        
    }
    
    func bmPlayer(player: BMPlayer, playerOrientChanged isFullscreen: Bool) {
        
    }
}

// MARK: - VideoDetailViewControllerDelegate
extension VideoTableViewController: VideoDetailViewControllerDelegate {
    /// 详情控制器将要消失
    func VideoDetailViewControllerViewWillDisappear(_ realVideo: RealVideo, _ currentTime: TimeInterval, _ currentIndexPath: IndexPath) {
        let currentCell = tableView.cellForRow(at: currentIndexPath) as! VideoCell
        currentCell.bgImageButton.addSubview(player)
        player.snp.makeConstraints({ $0.edges.equalTo(currentCell.bgImageButton) })
        // 设置视频播放地址
        player.setVideo(resource: BMPlayerResource(url: URL(string: realVideo.video_list.video_1.mainURL)!))
        // 设置当前播放时间
        player.seek(currentTime)
        // 视频播放时隐藏 cell 的部分子视图
        hideSubviews(of: currentCell)
        self.priorCell = currentCell
    }
}



