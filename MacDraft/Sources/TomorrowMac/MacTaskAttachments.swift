import SwiftUI
import SwiftData
import PhotosUI
import ImageIO
import UniformTypeIdentifiers
import Shove95Kit

enum MacImageImport {
    /// Match iPhone's 2048px / 80% JPEG budget, baking EXIF orientation into pixels.
    nonisolated static func prepare(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let canvas = CGContext(data: nil, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        canvas.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let output = NSMutableData()
        guard let flattened = canvas.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, flattened,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

@MainActor enum MacPhotoAttachments {
    static func append(_ images: [Data], to task: TaskItem, context: ModelContext) throws {
        let order = task.nextPhotoOrder
        var inserted: [TaskPhoto] = []
        for (offset, data) in images.enumerated() {
            let photo = TaskPhoto()
            photo.order = order + offset; photo.data = data; photo.task = task
            context.insert(photo); inserted.append(photo)
        }
        do { try context.save() }
        catch { for photo in inserted { context.delete(photo) }; throw error }
    }
}

/// Occupies the grip's slot only while editing; system pickers never request
/// broad Photos-library access. Files are read only within their scoped grant.
struct MacAttachmentButton: View {
    let task: TaskItem
    let keepEditing: () -> Void
    @Binding var presenting: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.skeu) private var skeu
    @State private var sources = false
    @State private var files = false
    @State private var library = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var failure: String?

    var body: some View {
        Button {
            try? context.save()
            presenting = true; sources = true
        } label: {
            Image(systemName: "paperclip").font(.system(size: 18.5))
                .foregroundStyle(skeu.inkMuted)
                .frame(width: 28, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(MacSkeuTapStyle())
        .help("Attach photo").accessibilityLabel("Attach photo to \(task.title)")
        .disabled(importing)
        .popover(isPresented: $sources) {
            VStack(alignment: .leading, spacing: 8) {
                Button { library = true; sources = false } label: {
                    Label("Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, alignment: .leading)
                }
                Button { files = true; sources = false } label: {
                    Label("Files…", systemImage: "folder").frame(maxWidth: .infinity, alignment: .leading)
                }
            }.buttonStyle(.plain).font(SkeuFont.at(14)).foregroundStyle(skeu.ink)
                .padding(16).frame(width: 170).background(skeu.canvas)
        }
        .photosPicker(isPresented: $library, selection: $picked, matching: .images)
        .fileImporter(isPresented: $files, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                load {
                    try urls.map { url in
                        let granted = url.startAccessingSecurityScopedResource()
                        defer { if granted { url.stopAccessingSecurityScopedResource() } }
                        return try Data(contentsOf: url)
                    }
                }
            case .failure(let error): failure = error.localizedDescription
            }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            importing = true; presenting = true
            Task { @MainActor in
                do {
                    var images: [Data] = []
                    for item in items {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let prepared = await Task.detached(priority: .userInitiated, operation: { MacImageImport.prepare(data) }).value else {
                            throw CocoaError(.fileReadCorruptFile)
                        }
                        images.append(prepared)
                    }
                    try MacPhotoAttachments.append(images, to: task, context: context)
                } catch { failure = error.localizedDescription }
                picked = []; importing = false; finishIfClosed()
            }
        }
        .onChange(of: sources) { finishIfClosed() }
        .onChange(of: library) { finishIfClosed() }
        .onChange(of: files) { finishIfClosed() }
        .alert("Couldn’t attach photo", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK") { failure = nil }
        } message: { Text(failure ?? "") }
    }

    private func load(_ read: @escaping @Sendable () throws -> [Data]) {
        importing = true; presenting = true
        Task { @MainActor in
            do {
                let images = try await Task.detached(priority: .userInitiated) {
                    try read().map { data in
                        guard let image = MacImageImport.prepare(data) else { throw CocoaError(.fileReadCorruptFile) }
                        return image
                    }
                }.value
                try MacPhotoAttachments.append(images, to: task, context: context)
            } catch { failure = error.localizedDescription }
            importing = false; finishIfClosed()
        }
    }
    private func finishIfClosed() {
        guard !sources, !files, !library, !importing else { return }
        keepEditing(); presenting = false
    }
}

struct MacTaskPhotoStrip: View {
    @Bindable var task: TaskItem
    @Environment(\.skeu) private var skeu
    @Environment(\.modelContext) private var context
    @Environment(MacPhotoPreview.self) private var preview
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: SkeuSpace.sm) {
                ForEach(task.orderedPhotos) { photo in
                    if let data = photo.data, let image = NSImage(data: data) {
                        Button { preview.photo = photo } label: {
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: 64 * MacTaskMetrics.scale, height: 64 * MacTaskMetrics.scale)
                                .clipped().clipShape(RoundedRectangle(cornerRadius: SkeuRadius.sm))
                                .overlay {
                                    RoundedRectangle(cornerRadius: SkeuRadius.sm).strokeBorder(
                                        LinearGradient(colors: [skeu.outline, skeu.outlineLit], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                                }
                        }.buttonStyle(MacSkeuTapStyle()).accessibilityLabel("Open attached photo")
                    }
                }
            }.padding(.vertical, 8).background(MacScrollIndicators())
        }.scrollIndicators(.hidden)

    }
}

@MainActor @Observable final class MacPhotoPreview {
    var photo: TaskPhoto?
}

struct MacPhotoViewer: View {
    let photo: TaskPhoto
    let close: () -> Void
    @Environment(\.skeu) private var skeu
    @Environment(\.modelContext) private var context
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pan: CGSize = .zero
    @State private var failure: String?
    private var scale: CGFloat { min(8, max(1, zoom * pinch)) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .contentShape(Rectangle()).onTapGesture(perform: close)
                    .accessibilityLabel("Close photo preview")
                VStack(spacing: 16) {
                    HStack {
                        Button(role: .destructive) {
                            context.delete(photo)
                            do { try context.save(); close() }
                            catch { context.rollback(); failure = error.localizedDescription }
                        } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44).skeuGlass(Circle(), height: 44)
                        }.help("Delete attached photo")
                        Spacer()
                        Button { zoom = 1; offset = .zero } label: {
                            Text("\(Int(scale * 100))%").font(.system(size: 12, design: .monospaced))
                        }.help("Reset zoom")
                        Button(action: close) {
                            SkeuChromeGlyph(kind: .close, face: SkeuFont.face, size: 18, tint: skeu.ink)
                                .frame(width: 44, height: 44).skeuGlass(Circle(), height: 44)
                        }.keyboardShortcut(.cancelAction).help("Close photo")
                    }.buttonStyle(MacSkeuTapStyle())
                    GeometryReader { imageArea in
                        if let data = photo.data, let image = NSImage(data: data) {
                            Image(nsImage: image).resizable().scaledToFit()
                                .frame(width: imageArea.size.width, height: imageArea.size.height)
                                .scaleEffect(scale)
                                .offset(clamped(CGSize(width: offset.width + pan.width, height: offset.height + pan.height), in: imageArea.size, at: scale))
                                .frame(width: imageArea.size.width, height: imageArea.size.height)
                                .contentShape(Rectangle())
                                .gesture(MagnifyGesture()
                                    .updating($pinch) { value, state, _ in state = value.magnification }
                                    .onEnded { value in
                                        zoom = min(8, max(1, zoom * value.magnification))
                                        offset = clamped(offset, in: imageArea.size, at: zoom)
                                    })
                                .simultaneousGesture(DragGesture()
                                    .updating($pan) { value, state, _ in if zoom > 1 { state = value.translation } }
                                    .onEnded { value in
                                        if zoom > 1 { offset = clamped(CGSize(width: offset.width + value.translation.width, height: offset.height + value.translation.height), in: imageArea.size, at: zoom) }
                                    })
                        }
                    }.clipped()
                }.padding(22)
                    .frame(width: min(800, geo.size.width - 80), height: min(680, geo.size.height - 80))
                    .background(skeu.canvas, in: RoundedRectangle(cornerRadius: SkeuRadius.lg))
                    .contentShape(Rectangle()).onTapGesture { }
                    .foregroundStyle(skeu.ink)
                    .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
            }.frame(width: geo.size.width, height: geo.size.height)
        }
        .alert("Couldn’t delete photo", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK") { failure = nil }
        } message: { Text(failure ?? "") }
    }
    private func clamped(_ value: CGSize, in size: CGSize, at scale: CGFloat) -> CGSize {
        let x = size.width * (scale - 1) / 2
        let y = size.height * (scale - 1) / 2
        return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
    }
}
