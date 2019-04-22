import Foundation
import UIKit
import Photos
fileprivate func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}
open class AssetManager {

  public static func getImage(_ name: String) -> UIImage {
    let traitCollection = UITraitCollection(displayScale: 3)
    var bundle = Bundle(for: AssetManager.self)

    if let resource = bundle.resourcePath, let resourceBundle = Bundle(path: resource + "/ImagePicker.bundle") {
      bundle = resourceBundle
    }

    return UIImage(named: name, in: bundle, compatibleWith: traitCollection) ?? UIImage()
  }

  public static func fetch(_ completion: @escaping (_ assets: [PHAsset]) -> Void) {
    let fetchOptions = PHFetchOptions()
    let authorizationStatus = PHPhotoLibrary.authorizationStatus()
    var fetchResult: PHFetchResult<PHAsset>?

    guard authorizationStatus == .authorized else { return }

    if fetchResult == nil {
      fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }

    if fetchResult?.count > 0 {
      var assets = [PHAsset]()
      fetchResult?.enumerateObjects({ object, index, stop in
        assets.insert(object, at: 0)
      })

      DispatchQueue.main.async(execute: {
        completion(assets)
      })
    }
  }

  public static func resolveAsset(_ asset: PHAsset, size: CGSize = CGSize(width: 720, height: 1280), completion: @escaping (_ image: UIImage?) -> Void) {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.deliveryMode = .highQualityFormat

    imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, info in
      if let info = info, info["PHImageFileUTIKey"] == nil {
        DispatchQueue.main.async(execute: {
          completion(image)
        })
      }
    }
  }

  public static func resolveAssets(_ assets: [PHAsset], size: CGSize = CGSize(width: 720, height: 1280)) -> [UIImage] {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.isSynchronous = true

    var images = [UIImage]()
    for asset in assets {
      imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, info in
        if let image = image {
          images.append(image)
        }
      }
    }
    return images
  }
  
  public static func resolveAssets(_ assets: [PHAsset], size: CGSize = CGSize(width: 720, height: 1280), isNetworkAccessAllowed: Bool = false,
                                 onBeginLoading: @escaping (_ asset: PHAsset) -> Void,
                                 onCompleted: @escaping (_ images: [UIImage]) -> Void) {
    
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    let requestOptionsLocal = PHImageRequestOptions()
    
    requestOptions.isSynchronous = false
    requestOptions.deliveryMode = .highQualityFormat
    requestOptions.isNetworkAccessAllowed = true
    
    requestOptionsLocal.isSynchronous = true
    requestOptionsLocal.deliveryMode = .highQualityFormat
    requestOptionsLocal.isNetworkAccessAllowed = false
    
    var images = [UIImage]()
    let loadAssetsGroup = DispatchGroup()
    
    for asset in assets {
      loadAssetsGroup.enter()
      
      // Sync load from device local storage
      imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptionsLocal) { image, _ in
        if let image = image {
          images.append(image)
          loadAssetsGroup.leave()
          
        } else {
          
          onBeginLoading(asset)
          
          // Async load from device local storage
          imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, _ in
            if let image = image {
              images.append(image)
            }
            loadAssetsGroup.leave()
          }
        }
      }
    }
    
    loadAssetsGroup.notify(queue: DispatchQueue.main) {
      onCompleted(images)
    }
  }
}
