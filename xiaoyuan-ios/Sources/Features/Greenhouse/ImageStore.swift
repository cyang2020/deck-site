import Foundation
import SwiftUI
import UIKit
import ImageIO

/// 花房照片仓库:JPEG(质量 .72)存在 Documents/photos/ 下。
/// PhotoCard.imagePath 只存相对路径("photos/UUID.jpg"),换设备/换容器也不失效。
enum ImageStore {

    enum StoreError: Error { case jpegEncodingFailed }

    private static let folder = "photos"

    static var documentsURL: URL { URL.documentsDirectory }

    static func url(for relativePath: String) -> URL {
        URL.documentsDirectory.appending(path: relativePath)
    }

    // MARK: - 存

    /// 居中裁方 + 压到 1400px 内 + JPEG 0.72,返回相对路径(存进 PhotoCard.imagePath)
    @discardableResult
    static func save(_ image: UIImage) throws -> String {
        let squared = squareCropped(image)
        guard let data = squared.jpegData(compressionQuality: 0.72) else {
            throw StoreError.jpegEncodingFailed
        }
        let dir = URL.documentsDirectory.appending(path: folder, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        try data.write(to: dir.appending(path: name), options: .atomic)
        return folder + "/" + name
    }

    // MARK: - 取(异步,不挡主线程)

    /// maxPixel 给缩略图用(ImageIO 降采样,省内存);nil = 原尺寸
    static func load(_ relativePath: String, maxPixel: CGFloat? = nil) async -> UIImage? {
        let fileURL = url(for: relativePath)
        if let maxPixel {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            ]
            guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { return nil }
            return UIImage(cgImage: cg)
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - 删

    static func delete(_ relativePath: String) {
        try? FileManager.default.removeItem(at: url(for: relativePath))
    }

    // MARK: - 居中裁方 + 缩放

    /// 裁成正方形并把边长压到 maxSide(像素)以内,同时抹平 EXIF 方向。
    static func squareCropped(_ image: UIImage, maxSide: CGFloat = 1400) -> UIImage {
        let pixelW = image.size.width * image.scale
        let pixelH = image.size.height * image.scale
        guard pixelW > 0, pixelH > 0 else { return image }
        if pixelW == pixelH, pixelW <= maxSide, image.scale == 1, image.imageOrientation == .up {
            return image
        }
        let side = min(pixelW, pixelH)
        let out = min(side, maxSide)
        let ratio = out / side
        let drawW = pixelW * ratio
        let drawH = pixelH * ratio
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(x: (out - drawW) / 2,
                                  y: (out - drawH) / 2,
                                  width: drawW,
                                  height: drawH))
        }
    }
}

/// 从 ImageStore 异步取图的小视图:先垫一块奶油色,取到再淡入。
/// 自带一点旧胶卷的暖调(轻微降饱和 + 暖色薄纱)。
struct StoredImageView: View {
    let path: String
    var maxPixel: CGFloat? = nil

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.cream)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .saturation(0.92)
        .contrast(0.98)
        .overlay(Color(hex: 0xC98A3D).opacity(0.06))
        .animation(.easeOut(duration: 0.25), value: image == nil)
        .task(id: path) {
            image = await ImageStore.load(path, maxPixel: maxPixel)
        }
    }
}
