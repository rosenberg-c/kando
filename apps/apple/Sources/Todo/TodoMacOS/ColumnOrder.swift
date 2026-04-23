func reorderedColumns(_ columns: [KanbanColumn], from sourceIndex: Int, to destinationIndex: Int) -> [KanbanColumn]? {
    guard columns.indices.contains(sourceIndex), columns.indices.contains(destinationIndex) else {
        return nil
    }
    if sourceIndex == destinationIndex {
        return reindexedColumns(columns)
    }

    var reordered = columns
    let moving = reordered.remove(at: sourceIndex)
    reordered.insert(moving, at: destinationIndex)
    return reindexedColumns(reordered)
}

func reorderedColumns(_ columns: [KanbanColumn], orderedIDs: [String]) -> [KanbanColumn]? {
    guard columns.count == orderedIDs.count else {
        return nil
    }
    var byID: [String: KanbanColumn] = [:]
    for column in columns {
        byID[column.id] = column
    }

    var seen = Set<String>()
    var reordered: [KanbanColumn] = []
    reordered.reserveCapacity(orderedIDs.count)

    for id in orderedIDs {
        guard let column = byID[id], seen.insert(id).inserted else {
            return nil
        }
        reordered.append(column)
    }

    return reindexedColumns(reordered)
}

private func reindexedColumns(_ columns: [KanbanColumn]) -> [KanbanColumn] {
    columns.enumerated().map { index, column in
        KanbanColumn(id: column.id, title: column.title, position: index)
    }
}
