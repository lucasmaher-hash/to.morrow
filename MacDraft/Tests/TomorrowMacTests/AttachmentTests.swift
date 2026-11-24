import Testing
import SwiftData
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Shove95Kit
@testable import TomorrowMac

@Suite @MainActor struct AttachmentTests {
    private func image(width: Int = 64, height: Int = 32, orientation: Int = 1) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.4, green: 0.2, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()),
            [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return bytes as Data
    }

    @Test func invalidImageIsRejected() {
        #expect(MacImageImport.prepare(Data("not an image".utf8)) == nil)
    }

    @Test func importResizesAndBakesOrientationWithoutUpscaling() throws {
        let prepared = try #require(MacImageImport.prepare(image(width: 4000, height: 1000, orientation: 6)))
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 512 && decoded.height == 2048)
        let small = try #require(MacImageImport.prepare(image()))
        let smallSource = try #require(CGImageSourceCreateWithData(small as CFData, nil))
        let smallImage = try #require(CGImageSourceCreateImageAtIndex(smallSource, 0, nil))
        #expect(smallImage.width == 64 && smallImage.height == 32)
    }

    @Test func attachmentsPersistInOrderWithoutReplacingTheLiveTask() throws {
        let schema = Schema([TaskItem.self, TaskPhoto.self, Workspace.self])
        let container = try ModelContainer(for: schema, configurations:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let task = TaskItem()
        task.title = "Photo task"; task.workspaceID = Workspace.workID
        task.isLiveNote = true; task.isPinned = true; task.sortOrder = 500
        let id = task.id
        context.insert(task)
        let bytes = try #require(MacImageImport.prepare(image()))
        try MacPhotoAttachments.append([bytes, bytes], to: task, context: context)
        try MacPhotoAttachments.append([bytes], to: task, context: context)
        #expect(task.orderedPhotos.map(\.order) == [0, 1, 2])
        #expect(task.id == id && task.isLiveNote && task.isPinned && task.sortOrder == 500)
        #expect(task.workspaceID == Workspace.workID)
        let fresh = ModelContext(container)
        let restored = try #require(fresh.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(restored.allPhotos == [bytes, bytes, bytes])
        #expect(restored.orderedPhotos.allSatisfy { $0.task?.id == id })
        fresh.delete(restored.orderedPhotos[1]); try fresh.save()
        #expect(restored.orderedPhotos.map(\.order) == [0, 2])
        #expect(try fresh.fetchCount(FetchDescriptor<TaskItem>()) == 1)
    }
}
