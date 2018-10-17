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
import Photos

public class PhotoKitAsset: Asset {

    let asset: PHAsset

    public init(asset: PHAsset) {
        self.asset = asset
    }

    public var originalAsset: PHAsset {
        return asset as PHAsset
    }

    // MARK: - Asset

    public var identifier: Int {
        return asset.localIdentifier.hash
    }

    public func image(targetSize:CGSize, isPreview: Bool, handler: @escaping (ImageData?,Data?) -> Void) {
        let option = PHImageRequestOptions()
        option.isNetworkAccessAllowed = true

        _ = PHImageManager.default().requestImage(
            for: self.asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: option ) { (image, info) -> Void in
                guard let image = image else {
                    handler(nil, nil)
                    return
                }
                handler(ImageData(image: image, info: info as Dictionary<NSObject, AnyObject>?), nil)
                if !isPreview{
                    if #available(iOS 9.0, *) {
                        let resources = PHAssetResource.assetResources(for: self.asset)
                        if let resource = resources.first{
                            let filename = resource.originalFilename as NSString
                            if filename.pathExtension.lowercased() == "gif" {
                                _ = PHImageManager.default().requestImageData(
                                    for: self.asset,
                                    options: option, resultHandler: { (data, _, _, _) in
                                        handler(ImageData(image: image, info: info as Dictionary<NSObject, AnyObject>?), data)
                                })
                            }
                        }
                    }
                }
        }
    }
    
    public func video(asset: PHAsset, handler: @escaping (AVPlayer?) -> Void) {
        let option = PHVideoRequestOptions()
        option.isNetworkAccessAllowed = true
        PHCachingImageManager().requestAVAsset(forVideo: asset, options: option) { (asset:AVAsset?, audioMix:AVAudioMix?, info:[AnyHashable : Any]?) in
            DispatchQueue.main.async {
                if let asset = asset as? AVURLAsset {
                    let player = AVPlayer(url: asset.url)
                    handler(player)
                }
                else {
                    handler(nil)
                }
            }
        }
    }
}
