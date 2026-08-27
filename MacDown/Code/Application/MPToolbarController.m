//
//  MPToolbarController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-02-12.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPToolbarController.h"

// Because we're creating selectors for methods which aren't in this class
#pragma GCC diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wundeclared-selector"


static CGFloat itemWidth = 37;


@implementation MPToolbarController
{
    NSArray *toolbarItems;
    NSArray *toolbarItemIdentifiers;
    
    /**
     * Map toolbar item identifier to it's NSToolbarItem or NSToolbarItemGroup object
     */
    NSMutableDictionary *toolbarItemIdentifierObjectDictionary;
    NSToolbarItemGroup *viewModeItemGroup;
}

- (id)init
{
    self = [super init];
    
    if (!self)
    {
        return nil;
    }
    
    self->toolbarItemIdentifierObjectDictionary = [NSMutableDictionary new];
    [self setupToolbarItems];
    
    return self;
}


#pragma mark - Private

- (void)setupToolbarItems
{
    self->viewModeItemGroup = [NSToolbarItemGroup
        groupWithItemIdentifier:@"view-mode"
        titles:@[
            NSLocalizedString(@"Editor", @"Editor-only view mode"),
            NSLocalizedString(@"Preview", @"Preview-only view mode"),
            NSLocalizedString(@"Split", @"Editor and preview view mode")
        ]
        selectionMode:NSToolbarItemGroupSelectionModeSelectOne
        labels:@[
            NSLocalizedString(@"Editor", @"Editor-only view mode"),
            NSLocalizedString(@"Preview", @"Preview-only view mode"),
            NSLocalizedString(@"Split", @"Editor and preview view mode")
        ]
        target:self
        action:@selector(selectedViewMode:)];
    self->viewModeItemGroup.label = NSLocalizedString(@"View", @"View mode toolbar group");
    self->viewModeItemGroup.paletteLabel = self->viewModeItemGroup.label;
    self->viewModeItemGroup.visibilityPriority = NSToolbarItemVisibilityPriorityUser;
    
    // Set up all available toolbar items
    self->toolbarItems = @[
        [self toolbarItemGroupWithIdentifier:@"indent-group" separated:YES label:NSLocalizedString(@"Shift Left/Right", @"") items:@[
            [self toolbarItemWithIdentifier:@"shift-left" label:NSLocalizedString(@"Shift Left", @"Shift text to the left toolbar button") icon:@"ToolbarIconShiftLeft" action:@selector(unindent:)],
            [self toolbarItemWithIdentifier:@"shift-right" label:NSLocalizedString(@"Shift Right", @"Shift text to the right toolbar button") icon:@"ToolbarIconShiftRight" action:@selector(indent:)]
            ]
        ],
        [self toolbarItemGroupWithIdentifier:@"text-formatting-group" separated:NO label:NSLocalizedString(@"Text Styles", @"") items:@[
            [self toolbarItemWithIdentifier:@"bold" label:NSLocalizedString(@"Strong", @"Strong toolbar button") icon:@"ToolbarIconBold" action:@selector(toggleStrong:)],
            [self toolbarItemWithIdentifier:@"italic" label:NSLocalizedString(@"Emphasize", @"Emphasize toolbar button") icon:@"ToolbarIconItalic" action:@selector(toggleEmphasis:)],
            [self toolbarItemWithIdentifier:@"underline" label:NSLocalizedString(@"Underline", @"Underline toolbar button") icon:@"ToolbarIconUnderlined" action:@selector(toggleUnderline:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"heading-group" separated:NO label:NSLocalizedString(@"Headings", @"") items:@[
            [self toolbarItemWithIdentifier:@"heading1" label:NSLocalizedString(@"Heading 1", @"Heading 1 toolbar button") icon:@"ToolbarIconHeading1" action:@selector(convertToH1:)],
            [self toolbarItemWithIdentifier:@"heading2" label:NSLocalizedString(@"Heading 2", @"Heading 2 toolbar button") icon:@"ToolbarIconHeading2" action:@selector(convertToH2:)],
            [self toolbarItemWithIdentifier:@"heading3" label:NSLocalizedString(@"Heading 3", @"Heading 3 toolbar button") icon:@"ToolbarIconHeading3" action:@selector(convertToH3:)]
            ]
         ],
        [self toolbarItemGroupWithIdentifier:@"list-group" separated:YES label:NSLocalizedString(@"Ordered/Unordered List", @"") items:@[
            [self toolbarItemWithIdentifier:@"unordered-list" label:NSLocalizedString(@"Unordered List", @"Unordered list toolbar button") icon:@"ToolbarIconUnorderedList" action:@selector(toggleUnorderedList:)],
            [self toolbarItemWithIdentifier:@"ordered-list" label:NSLocalizedString(@"Ordered List", @"Ordered list toolbar button") icon:@"ToolbarIconOrderedList" action:@selector(toggleOrderedList:)]
            ]
         ],
        [self toolbarItemWithIdentifier:@"blockquote" label:NSLocalizedString(@"Blockquote", @"Blockquote toolbar button") icon:@"ToolbarIconBlockquote" action:@selector(toggleBlockquote:)],
        [self toolbarItemWithIdentifier:@"code" label:NSLocalizedString(@"Inline Code", @"Inline code toolbar button") icon:@"ToolbarIconInlineCode" action:@selector(toggleInlineCode:)],
        [self toolbarItemWithIdentifier:@"link" label:NSLocalizedString(@"Link", @"Link toolbar button") icon:@"ToolbarIconLink" action:@selector(toggleLink:)],
        [self toolbarItemWithIdentifier:@"image" label:NSLocalizedString(@"Image", @"Image toolbar button") icon:@"ToolbarIconImage" action:@selector(toggleImage:)],
        [self toolbarItemWithIdentifier:@"copy-html" label:NSLocalizedString(@"Copy HTML", @"Copy HTML toolbar button") icon:@"ToolbarIconCopyHTML" action:@selector(copyHtml:)],
        [self toolbarItemWithIdentifier:@"comment" label:NSLocalizedString(@"Comment", @"Comment toolbar button") icon:@"ToolbarIconComment" action:@selector(toggleComment:)],
        [self toolbarItemWithIdentifier:@"highlight" label:NSLocalizedString(@"Highlight", @"Highlight toolbar button") icon:@"ToolbarIconHighlight" action:@selector(toggleHighlight:)],
        [self toolbarItemWithIdentifier:@"strikethrough" label:NSLocalizedString(@"Strikethrough", @"Strikethrough toolbar button") icon:@"ToolbarIconStrikethrough" action:@selector(toggleStrikethrough:)],
        self->viewModeItemGroup
    ];
    
    self->toolbarItemIdentifiers = [self toolbarItemIdentifiersFromItemsArray:self->toolbarItems];
}

- (void)selectedViewMode:(NSToolbarItemGroup *)sender
{
    if (sender.selectedIndex < MPDocumentViewModeEditor
        || sender.selectedIndex > MPDocumentViewModeSplit)
        return;

    self.document.documentViewMode = (MPDocumentViewMode)sender.selectedIndex;
}

- (void)syncViewMode
{
    self->viewModeItemGroup.selectedIndex = self.document.documentViewMode;
}

/**
 * Returns an array with all item identifiers for the toolbar items in the passed in _toolbarItemsArray_.
 */
- (NSArray *)toolbarItemIdentifiersFromItemsArray:(NSArray *)toolbarItemsArray {
    NSMutableArray *orderedIdentifiers = [NSMutableArray new];
    
    for (NSToolbarItem *item in toolbarItemsArray) {
        [orderedIdentifiers addObject:item.itemIdentifier];
    }
    
    return [orderedIdentifiers copy];
}

- (void)selectedToolbarItemGroupItem:(NSSegmentedControl *)sender
{
    NSInteger selectedIndex = sender.selectedSegment;
    
    NSToolbarItemGroup *selectedGroup = self->toolbarItemIdentifierObjectDictionary[sender.identifier];
    NSToolbarItem *selectedItem = selectedGroup.subitems[selectedIndex];
    
    // Invoke the toolbar item's action
    // Must convert to IMP to let the compiler know about the method definition
    MPDocument *document = self.document;
    IMP imp = [document methodForSelector:selectedItem.action];
    void (*impFunc)(id) = (void *)imp;
    impFunc(document);
}


#pragma mark - NSToolbarDelegate
- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    NSMutableArray *defaultItemIdentifiers = [NSMutableArray new];
    NSMutableSet *centeredItemIdentifiers = [NSMutableSet new];

    [defaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];

    for (NSString *itemIdentifier in self->toolbarItemIdentifiers)
    {
        if ([itemIdentifier isEqualToString:@"comment"]
            || [itemIdentifier isEqualToString:@"highlight"]
            || [itemIdentifier isEqualToString:@"strikethrough"]
            || [itemIdentifier isEqualToString:@"view-mode"])
            continue;

        [defaultItemIdentifiers addObject:itemIdentifier];
        [centeredItemIdentifiers addObject:itemIdentifier];
    }

    [defaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
    [defaultItemIdentifiers addObject:@"view-mode"];

    if (@available(macOS 13.0, *))
        toolbar.centeredItemIdentifiers = centeredItemIdentifiers;
    
    return [defaultItemIdentifiers copy];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [self->toolbarItemIdentifiers arrayByAddingObjectsFromArray:@[
        NSToolbarSpaceItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier
    ]];
}

- (NSArray<NSString *> *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return @[@"view-mode"];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *item;
    
    for (NSToolbarItem *currentItem in self->toolbarItems) {
        if ([currentItem.itemIdentifier isEqualToString:itemIdentifier]) {
            item = currentItem;
            break;
        }
    }
    
    return item;
}


#pragma mark - Toolbar item factory methods

/**
 * Factory method for creating and configuring a NSToolbarItemGroup object.
 */
- (NSToolbarItemGroup *)toolbarItemGroupWithIdentifier:(NSString *)itemIdentifier separated:(BOOL)separated label:(NSString *)label items:(NSArray <NSToolbarItem *>*)items {
    NSToolbarItemGroup *itemGroup = [[NSToolbarItemGroup alloc] initWithItemIdentifier:itemIdentifier];
    itemGroup.subitems = items;
    itemGroup.label = label;
    itemGroup.paletteLabel = label;
    
    CGFloat itemGroupWidth = itemWidth * items.count;
    
    NSSegmentedControl *segmentedControl = [[NSSegmentedControl alloc] init];
    segmentedControl.identifier = itemIdentifier;
    segmentedControl.segmentStyle = separated ? NSSegmentStyleSeparated : NSSegmentStyleTexturedRounded;
    segmentedControl.trackingMode = NSSegmentSwitchTrackingMomentary;
    segmentedControl.segmentCount = items.count;
    segmentedControl.target = self;
    segmentedControl.action = @selector(selectedToolbarItemGroupItem:);
    
    int segmentIndex = 0;
    
    for (NSToolbarItem *subItem in items)
    {
        [segmentedControl setImage:subItem.image forSegment:segmentIndex];
        [segmentedControl setImageScaling:NSImageScaleProportionallyDown forSegment:segmentIndex];
        [segmentedControl setWidth:itemWidth-4 forSegment:segmentIndex];
        if (@available(macOS 10.13, *)) {
            [segmentedControl setToolTip:subItem.label forSegment:segmentIndex];
        }
        
        segmentIndex++;
    }
    
    itemGroup.maxSize = NSMakeSize(itemGroupWidth, 25);
    itemGroup.view = segmentedControl;
    
    [self->toolbarItemIdentifierObjectDictionary setObject:itemGroup forKey:itemIdentifier];
    
    return itemGroup;
}

/**
 * Factory method for creating and configuring a NSToolbarItem object.
 */
- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)itemIdentifier label:(NSString *)label icon:(NSString *)iconImageName action:(SEL)action {
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    toolbarItem.label = label;
    toolbarItem.paletteLabel = label;
    toolbarItem.toolTip = label;
    
    NSImage *itemImage = [NSImage imageNamed:iconImageName];
    [itemImage setTemplate:YES];
    [itemImage setSize:CGSizeMake(19, 19)];
    NSButton *itemButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, itemWidth, 27)];
    itemButton.image = itemImage;
    itemButton.imageScaling = NSImageScaleProportionallyDown;
    itemButton.bezelStyle = NSBezelStyleTexturedRounded;
    itemButton.focusRingType = NSFocusRingTypeDefault;
    itemButton.target = self.document;
    itemButton.action = action;
    
    toolbarItem.view = itemButton;
    
    [self->toolbarItemIdentifierObjectDictionary setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}

@end
