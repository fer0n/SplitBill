//
//  ButtonsOverlayLogic.swift
//  SplitBill
//
//  Created by fer0n on 16.08.23.
//

import Foundation
import SwiftUI
import LinkPresentation

extension ButtonsOverlayView {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return nil
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let image = UIImage(named: "YourImage")!
        let imageProvider = NSItemProvider(object: image)
        let metadata = LPLinkMetadata()
        metadata.imageProvider = imageProvider
        return metadata
    }
}

struct ImageModel: Transferable {
    let getImage: () async -> UIImage?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { item in
            try await { () -> Data in
                if let img = await item.getImage(), let jpeg = img.jpegData(compressionQuality: 0.6) {
                    return jpeg
                } else {
                    throw ExportImageError.noImageFound
                }
            }()
        }
    }
}
