//
//  MPDocument.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MPPreferences;

typedef NS_ENUM(NSInteger, MPDocumentViewMode) {
    MPDocumentViewModeEditor,
    MPDocumentViewModePreview,
    MPDocumentViewModeSplit,
};


@interface MPDocument : NSDocument

@property (nonatomic, readonly) MPPreferences *preferences;
@property (readonly) BOOL previewVisible;
@property (readonly) BOOL editorVisible;
@property (nonatomic) MPDocumentViewMode documentViewMode;

@property (nonatomic, readwrite) NSString *markdown;
@property (nonatomic, readonly) NSString *html;

- (IBAction)showEditorMode:(id)sender;
- (IBAction)showPreviewMode:(id)sender;
- (IBAction)showSplitMode:(id)sender;

@end
