import Foundation

private struct Identifier: Hashable { let rawValue: String }
private enum Item: Hashable { case tab(Identifier), group(Identifier) }
private enum SectionID { case favorites, pinned, tabs }
private struct Section { let groups: [Identifier: [Item]] }
private struct Outline {
    let sections: [SectionID: Section]
    let itemToSection: [Item: SectionID]
}
private struct Attributes { let customTitle: String? }
private struct Channel { let value: Attributes }
private struct Stream { let channel: Channel }
private struct Stored { let _titleAttributes: Stream }
private struct LegacyStored { let _attributes: Stream }
private struct WebContent { let tabStoreAttributesController: Any? }
private enum Controller { case webContent(WebContent), bookmarksPage }
private struct Delegate { let attributesController: Controller? }
private struct Model { let delegate: Delegate? }
private final class Content: NSObject {
    let viewModel: Model
    init(delegate: Delegate) { viewModel = Model(delegate: delegate) }
}
private final class List: NSObject {
    let appliedOutlineModel: Outline
    init(_ outline: Outline) { appliedOutlineModel = outline }
}
private struct StripModel { let outline: Outline }
private struct StripState { let model: StripModel }
private struct StripSubject { let currentValue: StripState }
private struct StripViewModel { let stateSubject: StripSubject }
private final class Strip: NSObject {
    let viewModel: StripViewModel
    init(_ outline: Outline) {
        viewModel = .init(stateSubject: .init(currentValue: .init(model: .init(outline: outline))))
    }
}
private struct DockDelegate { let itemID: Item }
private struct DockModel { let delegate: DockDelegate }
private final class DockTile: NSObject {
    let viewModel: DockModel
    init(_ item: Item) { viewModel = .init(delegate: .init(itemID: item)) }
}

@main
private enum Tests {
    static func main() {
        let loose = Item.tab(.init(rawValue: "loose"))
        let favorite = Item.tab(.init(rawValue: "favorite"))
        let nested = Item.tab(.init(rawValue: "nested"))
        let folder = Identifier(rawValue: "folder")
        let outline = Outline(sections: [.pinned: Section(groups: [folder: [nested]])],
                              itemToSection: [loose: .tabs, nested: .pinned, favorite: .favorites, .group(folder): .pinned])
        let observed = DPTidyTabLocations(List(outline)) as? [String: String]
        precondition(observed == ["loose": "tabs", "favorite": "favorites", "nested": "pinned:folder"])
        precondition(DPTidyTabLocations(Strip(outline)) as? [String: String] == observed)
        precondition(DPTidyTabIdentifier(DockTile(favorite)) as String? == "favorite")
        precondition(DPTidyTabIdentifier(DockTile(.group(folder))) == nil)
        // A menu command or a drop changes the same native outline.
        let afterFavoriteDrop = Outline(sections: outline.sections,
            itemToSection: [loose: .favorites, favorite: .favorites, nested: .pinned, .group(folder): .pinned])
        precondition(DPTidyTabLocations(List(afterFavoriteDrop))?["loose"] as? String == "favorites")
        let unpinnedFolder = Outline(sections: [.tabs: Section(groups: [folder: [nested, loose]])],
            itemToSection: [.group(folder): .tabs])
        let pinnedFolder = Outline(sections: [.pinned: Section(groups: [folder: [nested, loose]])],
            itemToSection: [.group(folder): .pinned])
        for id in ["nested", "loose"] {
            precondition(DPTidyTabLocations(List(unpinnedFolder))?[id] as? String == "tabs:folder")
            precondition(DPTidyTabLocations(List(pinnedFolder))?[id] as? String == "pinned:folder")
        }
        let batch = (0..<10).map { "tab-\($0)" }
        let looseBatch = Dictionary(uniqueKeysWithValues: batch.map { ($0, "tabs") })
        let groupedBatch = Dictionary(uniqueKeysWithValues: batch.map { ($0, "tabs:group") })
        let pinnedBatch = Dictionary(uniqueKeysWithValues: batch.map { ($0, "pinned:group") })
        precondition(DPTidyNewlyPinnedTabs(looseBatch as NSDictionary, groupedBatch as NSDictionary).count == 0)
        precondition(DPTidyNewlyPinnedTabs(groupedBatch as NSDictionary, pinnedBatch as NSDictionary) as? [String] == batch)
        precondition(DPTidyNewlyPinnedTabs(looseBatch as NSDictionary, pinnedBatch as NSDictionary) as? [String] == batch)
        precondition(DPTidyNewlyPinnedTabs(pinnedBatch as NSDictionary, groupedBatch as NSDictionary).count == 0)
        precondition(DPTidyNewlyPinnedTabs([:], pinnedBatch as NSDictionary).count == 0)
        for name in [nil, "My title"] as [String?] {
            let stream = Stream(channel: Channel(value: Attributes(customTitle: name)))
            for stored in [Stored(_titleAttributes: stream) as Any, LegacyStored(_attributes: stream)] {
                let content = Content(delegate: Delegate(attributesController: .webContent(WebContent(tabStoreAttributesController: stored))))
                precondition(DPTidyTabTitleStatus(content) == (name == nil ? 2 : 1))
            }
        }
        precondition(DPTidyTabTitleStatus(Content(delegate: Delegate(attributesController: .bookmarksPage))) == 1)
        precondition(DPTidyTabTitleStatus(Content(delegate: Delegate(attributesController: nil))) == 0)
        print("PASS: stable outline membership, collapsed folder IDs, native custom-title protection")
    }
}
