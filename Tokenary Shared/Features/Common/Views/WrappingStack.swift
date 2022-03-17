// Copyright © 2022 Tokenary. All rights reserved.

import Foundation
import SwiftUI

struct TightHeightGeometryReader<Content: View>: View {
    var alignment: Alignment
    @State
    private var height: CGFloat = .zero

    var content: (GeometryProxy) -> Content
    
    init(
        alignment: Alignment = .topLeading,
        @ViewBuilder content: @escaping (GeometryProxy) -> Content
    ) {
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometryProxy in
            self.content(geometryProxy)
                .onSizeChange { size in
                    if self.height != size.height {
                        self.height = size.height
                    }
                }
                .frame(maxWidth: .infinity, alignment: self.alignment)
        }
        .frame(height: self.height)
    }
}

/// An HStack that grows vertically when single line overflows
public struct WrappingStack<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    
    public let data: Data
    public var content: (Data.Element) -> Content
    public var id: KeyPath<Data.Element, ID>
    
    @Environment(\.wrappingStackStyle)
    private var wrappingStackStyle: WrappingStackStyle
    
    @State private var sizes: [ID: CGSize] = [:]
    @State private var calculatesSizesKeys: Set<ID> = []
    
    private let idsForCalculatingSizes: Set<ID>
    private var dataForCalculatingSizes: [Data.Element] {
        var result: [Data.Element] = []
        var idsToProcess: Set<ID> = idsForCalculatingSizes
        idsToProcess.subtract(calculatesSizesKeys)
        
        data.forEach { item in
            let itemId = item[keyPath: id]
            if idsToProcess.contains(itemId) {
                idsToProcess.remove(itemId)
                result.append(item)
            }
        }
        return result
    }
    
    /// Creates a new WrappingHStack
    ///
    /// - Parameters:
    ///   - id: a keypath of element identifier
    ///   - alignment: horizontal and vertical alignment. Vertical alignment is applied to every row
    ///   - horizontalSpacing: horizontal spacing between elements
    ///   - verticalSpacing: vertical spacing between the lines
    ///   - create: a method that creates an array of elements
    public init(
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content create: () -> ForEach<Data, ID, Content>
    ) {
        let forEach = create()
        data = forEach.data
        content = forEach.content
        idsForCalculatingSizes = Set(data.map { $0[keyPath: id] })
        self.id = id
    }
    
    private func splitIntoLines(maxWidth: CGFloat) -> [Range<Data.Index>] {
        var width: CGFloat = 0
        var result: [Range<Data.Index>] = []
        var lineStart = data.startIndex
        var lineLength = 0
        
        for element in data {
            guard let elementWidth = sizes[element[keyPath: id]]?.width else { break }
            let newWidth = width + elementWidth
            if newWidth < maxWidth || lineLength == 0 {
                width = newWidth + self.wrappingStackStyle.hSpacing
                lineLength += 1
            } else {
                width = elementWidth
                let lineEnd = data.index(lineStart, offsetBy: lineLength)
                result.append(lineStart ..< lineEnd)
                lineLength = 0
                lineStart = lineEnd
            }
        }
        
        if lineStart != data.endIndex {
            result.append(lineStart ..< data.endIndex)
        }
        return result
    }
    
    public var body: some View {
        if calculatesSizesKeys.isSuperset(of: idsForCalculatingSizes) {
            TightHeightGeometryReader(alignment: self.wrappingStackStyle.alignment) { geometry in
                let splitted = splitIntoLines(maxWidth: geometry.size.width)
                
                // All sizes are known
                VStack(
                    alignment: self.wrappingStackStyle.alignment.horizontal,
                    spacing: self.wrappingStackStyle.vSpacing
                ) {
                    ForEach(Array(splitted.enumerated()), id: \.offset) { list in
                        HStack(
                            alignment: self.wrappingStackStyle.alignment.vertical,
                            spacing: self.wrappingStackStyle.hSpacing
                        ) {
                            ForEach(data[list.element], id: id) {
                                content($0)
                            }
                        }
                    }
                }
            }
        } else {
            // Calculating sizes
            VStack {
                ForEach(dataForCalculatingSizes, id: id) { d in
                    content(d)
                        .onSizeChange { size in
                            let key = d[keyPath: id]
                            sizes[key] = size
                            calculatesSizesKeys.insert(key)
                        }
                }
            }
        }
    }
}

extension WrappingStack where ID == Data.Element.ID, Data.Element: Identifiable {
    public init(
        @ViewBuilder content create: () -> ForEach<Data, ID, Content>
    ) {
        self.init(id: \Data.Element.id, content: create)
    }
}

struct WrappingStackStyleKey: EnvironmentKey {
    static let defaultValue = WrappingStackStyle(hSpacing: 8, vSpacing: 8, alignment: .leading)
}

struct WrappingStackStyle {
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    let alignment: Alignment
}

extension EnvironmentValues {
    var wrappingStackStyle: WrappingStackStyle {
        get { self[WrappingStackStyleKey.self] }
        set { self[WrappingStackStyleKey.self] = newValue }
    }
}

extension View {
    public func wrappingStackStyle(
        hSpacing: CGFloat = 8,
        vSpacing: CGFloat = 8,
        alignment: Alignment = .leading
    ) -> some View {
        let style = WrappingStackStyle(
            hSpacing: hSpacing, vSpacing: vSpacing, alignment: alignment
        )
        
        return self.environment(\.wrappingStackStyle, style)
    }
}