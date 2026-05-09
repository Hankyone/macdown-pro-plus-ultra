//
//  MPTerminalPreferencesViewController.m
//  MacDown
//
//  Created by Niklas Berglund on 2017-01-11.
//  Copyright © 2017 Tzu-ping Chung . All rights reserved.
//

#import "MPGlobals.h"
#import "MPHomebrewSubprocessController.h"
#import "MPPreferences.h"
#import "MPTerminalPreferencesViewController.h"
#import "MPUtilities.h"


NS_INLINE NSColor *MPGetInstallationIndicatorColor(BOOL installed)
{
    static NSColor *installedColor = nil;
    static NSColor *uninstalledColor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        installedColor = [NSColor colorWithDeviceRed:0.357 green:0.659
                                                blue:0.192 alpha:1.000];
        uninstalledColor = [NSColor colorWithDeviceRed:0.897 green:0.231
                                                  blue:0.21 alpha:1.000];
    });
    if (installed)
        return installedColor;
    else
        return uninstalledColor;
}


@interface MPTerminalPreferencesViewController ()

@property (weak) IBOutlet NSTextField *supportIndicator;
@property (weak) IBOutlet NSTextField *supportTextField;
@property (weak) IBOutlet NSTextField *infoTextField;
@property (weak) IBOutlet NSTextField *locationTextField;
@property (weak) IBOutlet NSButton *installUninstallButton;

@property (nonatomic) NSURL *shellUtilityURL;
@property (copy, nonatomic) NSString *preferredCommandInstallationPath;

@end

@implementation MPTerminalPreferencesViewController


#pragma mark - Accessors.

- (void)setShellUtilityURL:(NSURL *)url
{
    _shellUtilityURL = url;
    if (url)
    {
        self.supportIndicator.textColor = MPGetInstallationIndicatorColor(YES);
        self.supportTextField.stringValue = NSLocalizedString(
            @"Shell utility installed",
            @"Label stating that shell utility has been installed");
        self.locationTextField.stringValue = url.path;
        self.locationTextField.font =
            [NSFont fontWithName:@"Menlo"
                            size:self.locationTextField.font.pointSize];
        self.installUninstallButton.title = NSLocalizedString(
            @"Uninstall", @"Uninstall shell utility button");
        self.installUninstallButton.action = @selector(uninstallShellUtility);
    }
    else
    {
        self.supportIndicator.textColor = MPGetInstallationIndicatorColor(NO);
        self.supportTextField.stringValue = NSLocalizedString(
            @"Shell utility not installed",
            @"Label stating that shell utility has not been installed");
        self.locationTextField.stringValue = NSLocalizedString(
            @"<Not installed>",
            @"Displayed when shell utility is not installed");

        NSFont *font =
            [NSFont systemFontOfSize:self.locationTextField.font.pointSize];
        self.locationTextField.font =
            [[NSFontManager sharedFontManager] convertFont:font
                                               toHaveTrait:NSFontItalicTrait];
        self.installUninstallButton.title = NSLocalizedString(
            @"Install", @"Install shell utility button");
        self.installUninstallButton.action = @selector(installShellUtility);
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self highlightMacdownInInfo];
    
    self.installUninstallButton.target = self;
    self.shellUtilityURL = nil;
}

- (void)viewWillAppear
{
    [self lookForShellUtility];
}

#pragma mark - MASPreferencesViewController

- (NSString *)viewIdentifier
{
    return @"TerminalPreferences";
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesTerminal"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedString(@"Terminal", @"Preference pane title.");
}

#pragma mark - Private methods

/**
 * Searches for the shell utility and invokes foundShellUtilityAtURL: if found.
 */
- (void)lookForShellUtility
{
    __weak MPTerminalPreferencesViewController *weakSelf = self;
    MPDetectHomebrewPrefixWithCompletionhandler(^(NSString *output) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *macdownPath = MPCommandInstallationPath;
            if (output)
            {
                NSCharacterSet *padding =
                    [NSCharacterSet whitespaceAndNewlineCharacterSet];
                NSString *prefix =
                    [output stringByTrimmingCharactersInSet:padding];
                if (prefix.length)
                    macdownPath =
                        [prefix stringByAppendingPathComponent:
                            [NSString stringWithFormat:@"bin/%@", kMPCommandName]];
            }
            weakSelf.preferredCommandInstallationPath = macdownPath;

            if ([[NSFileManager defaultManager] fileExistsAtPath:macdownPath])
                weakSelf.shellUtilityURL = [NSURL fileURLWithPath:macdownPath];
            else
                weakSelf.shellUtilityURL = nil;
        });
    });
}

- (void)installShellUtility
{
    // URL for shell utility in .app bundle.
    NSURL *sharedSupportURL = [NSBundle mainBundle].sharedSupportURL;
    NSString *utilityBundlePath =
        [sharedSupportURL URLByAppendingPathComponent:
            [NSString stringWithFormat:@"bin/%@", kMPCommandName]].path;

    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:utilityBundlePath])
    {
        NSString *installPath =
            self.preferredCommandInstallationPath ?: MPCommandInstallationPath;
        NSError *error = nil;
        BOOL ok = [fm createSymbolicLinkAtPath:installPath
                           withDestinationPath:utilityBundlePath error:&error];
        if (ok)
            [self lookForShellUtility];
        else
            [self presentShellUtilityError:error installing:YES];
    }
}

- (void)uninstallShellUtility
{
    NSURL *url = self.shellUtilityURL;
    if (!url)
        return;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    if (ok)
        self.shellUtilityURL = nil;
    else
        [self presentShellUtilityError:nil installing:NO];
}

- (void)presentShellUtilityError:(NSError *)error installing:(BOOL)installing
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = installing ?
        NSLocalizedString(@"Could not install shell utility", nil) :
        NSLocalizedString(@"Could not uninstall shell utility", nil);
    alert.informativeText = error.localizedDescription ?:
        NSLocalizedString(@"macOS did not provide a detailed error.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

/**
 * Highlights all occurrences of the shell command name in the info-text.
 */
- (void)highlightMacdownInInfo
{
    NSString *infoString = self.infoTextField.stringValue;
    NSMutableAttributedString *attributedInfoString =
        [[NSMutableAttributedString alloc] initWithString:infoString];
    
    NSRange searchRange = NSMakeRange(0, infoString.length);
    CGFloat infoFontSize = self.infoTextField.font.pointSize;
    NSFont *highlightFont = [NSFont fontWithName:@"Menlo" size:infoFontSize];
    
    while (searchRange.location < infoString.length)
    {
        searchRange.length = infoString.length - searchRange.location;
        NSRange foundRange =
            [infoString rangeOfString:kMPCommandName
                              options:NSLiteralSearch range:searchRange];
        
        if (foundRange.location != NSNotFound)
        {
            [attributedInfoString addAttribute:NSFontAttributeName value:highlightFont range:foundRange];
            
            searchRange.location = foundRange.location + foundRange.length;
        }
        else // Found all occurences
        {
            break;
        }
    }

    self.infoTextField.attributedStringValue = attributedInfoString;
}

@end
