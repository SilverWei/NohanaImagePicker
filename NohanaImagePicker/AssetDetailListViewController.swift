/*
 * Copyright (C) 2016 nohana, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an &quot;AS IS&quot; BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import AVFoundation
import AVKit

class AssetDetailListViewController: AssetListViewController {

    @objc var currentIndexPath: IndexPath = IndexPath() {
        willSet {
            if currentIndexPath != newValue {
                didChangeAssetDetailPage(newValue)
            }
        }
    }

    @IBOutlet weak var pickButton: UIButton!

    override var cellSize: CGSize {
        return Size.screenRectWithoutAppBar(self).size
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if nohanaImagePickerController != nil {
            pickButton.setBackgroundImage(UIImage(named: "ic_radio_button_unchecked"), for: UIControl.State())
            pickButton.setBackgroundImage(UIImage(named: "ic_check_circle"), for: .selected)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let indexPath = currentIndexPath
        view.isHidden = true
        coordinator.animate(alongsideTransition: nil) { _ in
            self.view.invalidateIntrinsicContentSize()
            self.collectionView?.reloadData()
            self.scrollCollectionView(to: indexPath)
            self.view.isHidden = false
        }
    }

    override func updateTitle() {
        self.title = ""
    }

    @objc func didChangeAssetDetailPage(_ indexPath:IndexPath) {
        guard let nohanaImagePickerController = nohanaImagePickerController else {
            return
        }
        let asset = photoKitAssetList[indexPath.item]
        pickButton.isSelected = nohanaImagePickerController.pickedAssetList.isPicked(asset)
        pickButton.isHidden = !(nohanaImagePickerController.canPickAsset(asset) )
        nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, assetDetailListViewController: self, didChangeAssetDetailPage: indexPath, photoKitAsset: asset.originalAsset)
    }

    override func scrollCollectionView(to indexPath: IndexPath) {
        let count: Int? = photoKitAssetList?.count
        guard count != nil && count! > 0 else {
            return
        }
        DispatchQueue.main.async {
            let toIndexPath = IndexPath(item: indexPath.item, section: 0)
            self.collectionView?.scrollToItem(at: toIndexPath, at: UICollectionView.ScrollPosition.centeredHorizontally, animated: false)
        }
    }

    override func scrollCollectionViewToInitialPosition() {
        guard isFirstAppearance else {
            return
        }
        let indexPath = IndexPath(row: currentIndexPath.item, section: 0)
        scrollCollectionView(to: indexPath)
        isFirstAppearance = false
    }

    // MARK: - IBAction

    @IBAction func didPushPickButton(_ sender: UIButton) {
        let asset = photoKitAssetList[currentIndexPath.row]
        if pickButton.isSelected {
            if nohanaImagePickerController!.pickedAssetList.drop(asset: asset) {
                pickButton.isSelected = false
            }
        } else {
            if nohanaImagePickerController!.pickedAssetList.pick(asset: asset) {
                pickButton.isSelected = true
            }
        }
    }

    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AssetDetailCell", for: indexPath) as? AssetDetailCell,
            let nohanaImagePickerController = nohanaImagePickerController else {
                fatalError("failed to dequeueReusableCellWithIdentifier(\"AssetDetailCell\")")
        }
        cell.scrollView.zoomScale = 1
        cell.tag = indexPath.item

        let imageSize = CGSize(
            width: cellSize.width * UIScreen.main.scale,
            height: cellSize.height * UIScreen.main.scale
        )
        let asset = photoKitAssetList[indexPath.item]
        asset.image(targetSize: imageSize, isPreview: false) { (imageData, data) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                if let imageData = imageData {
                    if cell.tag == indexPath.item {
                        if data == nil {
                            cell.imageView.image = imageData.image
                        }
                        else {
                            cell.imageView.image = UIImage.gif(data: data!)
                        }
                        cell.imageViewHeightConstraint.constant = self.cellSize.height
                        cell.imageViewWidthConstraint.constant = self.cellSize.width
                    }
                }
            })
        }
        cell.videoMainView.isHidden = asset.asset.mediaType != .video
        if !cell.videoMainView.isHidden {
            cell.asset = asset
            cell.videoPlayerButton.tag = indexPath.item
            cell.videoPlayerButton.addTarget(self, action: #selector(videoPlayButtonClick(_:)), for: .touchUpInside)
        }
        return (nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, assetDetailListViewController: self, cell: cell, indexPath: indexPath, photoKitAsset: asset.originalAsset)) ?? cell
    }

    // MARK: - UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = collectionView else {
            return
        }
        let row = Int((collectionView.contentOffset.x + cellSize.width * 0.5) / cellSize.width)
        if row < 0 {
            currentIndexPath = IndexPath(row: 0, section: currentIndexPath.section)
        } else if row >= collectionView.numberOfItems(inSection: 0) {
            currentIndexPath = IndexPath(row: collectionView.numberOfItems(inSection: 0) - 1, section: currentIndexPath.section)
        } else {
            currentIndexPath = IndexPath(row: row, section: currentIndexPath.section)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? AssetDetailCell {
            cell.avPlayerViewController?.view.removeFromSuperview()
            cell.avPlayerViewController?.removeFromParent()
            cell.avPlayerViewController = nil
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    override func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }

    // MARK: - videoPlayer
    
    @objc func videoPlayButtonClick(_ sender: UIButton) {
        let indexPath = IndexPath(item: sender.tag, section: 0)
        let asset = photoKitAssetList[indexPath.item]
        guard let collectionView = collectionView else {
            return
        }
        if let cell = collectionView.cellForItem(at: indexPath) as? AssetDetailCell {
            asset.video(asset: asset.asset, handler: { (avplayer) in
                cell.avPlayerViewController = videoPlayerViewController()
                cell.avPlayerViewController?.player = avplayer
                cell.videoMainView.addSubview((cell.avPlayerViewController?.view)!)
                cell.avPlayerViewController?.view.superview?.addConstraints(self.automaticLayout(itemView: (cell.avPlayerViewController?.view)!))
                cell.avPlayerViewController?.didMove(toParent: self)
                cell.avPlayerViewController?.player?.play()
            })
        }
    }
    
    @objc func automaticLayout(itemView: UIView) -> [NSLayoutConstraint]{
        var layoutConstraints: [NSLayoutConstraint] = []
        let leading: NSLayoutConstraint = NSLayoutConstraint(item: itemView, attribute: .leading, relatedBy: .equal, toItem: itemView.superview, attribute: .leading, multiplier: 1.0, constant: 0.0)
        let trailing: NSLayoutConstraint = NSLayoutConstraint(item: itemView, attribute: .trailing, relatedBy: .equal, toItem: itemView.superview, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        let top: NSLayoutConstraint = NSLayoutConstraint(item: itemView, attribute: .top, relatedBy: .equal, toItem: itemView.superview, attribute: .top, multiplier: 1.0, constant: 0.0)
        let bottom: NSLayoutConstraint = NSLayoutConstraint(item: itemView, attribute: .bottom, relatedBy: .equal, toItem: itemView.superview, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        itemView.translatesAutoresizingMaskIntoConstraints = false
        layoutConstraints.append(leading)
        layoutConstraints.append(trailing)
        layoutConstraints.append(top)
        layoutConstraints.append(bottom)
        return layoutConstraints
    }
}
