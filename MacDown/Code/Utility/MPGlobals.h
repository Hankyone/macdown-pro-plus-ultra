//
//  MPGlobals.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "version.h"

// These should match the main bundle's values.
static NSString * const kMPApplicationName = @"MacDown Pro Plus Ultra";

#ifdef DEBUG
static NSString * const kMPApplicationBundleIdentifier = @"com.hankyone.macdown-pro-plus-ultra-debug";
#else
static NSString * const kMPApplicationBundleIdentifier = @"com.hankyone.macdown-pro-plus-ultra";
#endif

static NSString * const kMPApplicationSuiteName = @"com.hankyone.macdown-pro-plus-ultra";

static NSString * const MPCommandInstallationPath = @"/usr/local/bin/macdown-pppu";
static NSString * const kMPCommandName = @"macdown-pppu";

static NSString * const kMPHelpKey = @"help";
static NSString * const kMPVersionKey = @"version";

static NSString * const kMPFilesToOpenKey = @"filesToOpenOnNextLaunch";
static NSString * const kMPPipedContentFileToOpen = @"pipedContentFileToOpenOnNextLaunch";
