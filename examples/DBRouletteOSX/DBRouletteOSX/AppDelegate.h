//
//  AppDelegate.h
//  DBRouletteOSX
//
//  Created by Brian Smith on 1/22/12.
//  Copyright (c) 2012 Dropbox, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <DropboxOSX/DropboxOSX.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
	DBRestClient *restClient;
}

- (IBAction)didPressLinkDropbox:(id)sender;
- (IBAction)didPressRandomPhoto:(id)sender;

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *linkButton;
@property (assign) IBOutlet NSButton *randomPhotoButton;
@property (assign) IBOutlet NSImageView *imageView;

@end
