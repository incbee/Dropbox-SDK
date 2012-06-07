//
//  AppDelegate.m
//  DBDesktopRoulette
//
//  Created by Brian Smith on 1/22/12.
//  Copyright (c) 2012 Dropbox. All rights reserved.
//

#import "AppDelegate.h"

#import <DropboxOSX/DropboxOSX.h>
#import <stdlib.h>
#import <time.h>


@interface AppDelegate () <DBRestClientDelegate>

- (void)updateLinkButton;
- (NSString*)photoPath;
- (void)loadRandomPhoto;
- (DBRestClient *)restClient;

@property (nonatomic, retain) NSString *requestToken;
@property (nonatomic, retain) NSArray *photosPaths;
@property (nonatomic, retain) NSString *currentPhotoPath;
@property (nonatomic, retain) NSString *photosHash;

@end


@implementation AppDelegate

@synthesize window = _window;
@synthesize linkButton = _linkButton;
@synthesize randomPhotoButton;
@synthesize imageView;
@synthesize requestToken;
@synthesize photosPaths;
@synthesize currentPhotoPath;
@synthesize photosHash;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString *appKey = @"APP_KEY";
    NSString *appSecret = @"APP_SECRET";
    NSString *root = nil; // Should be either kDBRootDropbox or kDBRootAppFolder
    DBSession *session = [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:root];
    [DBSession setSharedSession:session];

    NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
    NSString *actualScheme = [[[[plist objectForKey:@"CFBundleURLTypes"] objectAtIndex:0] objectForKey:@"CFBundleURLSchemes"] objectAtIndex:0];
    NSString *desiredScheme = [NSString stringWithFormat:@"db-%@", appKey];
    NSString *alertText = nil;
    if ([appKey isEqual:@"APP_KEY"] || [appSecret isEqual:@"APP_SECRET"] || root == nil) {
        alertText = @"Fill in appKey, appSecret, and root in AppDelegate.m to use this app";
    } else if (![actualScheme isEqual:desiredScheme]) {
        alertText = [NSString stringWithFormat:@"Set the url scheme to %@ for the OAuth authorize page to work correctly", desiredScheme];
    }

    if (alertText) {
        NSAlert *alert = [NSAlert alertWithMessageText:nil defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:alertText];
        [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authHelperStateChangedNotification:) name:DBAuthHelperOSXStateChangedNotification object:[DBAuthHelperOSX sharedHelper]];
    [self updateLinkButton];

    NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
    [em setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:)
        forEventClass:kInternetEventClass andEventID:kAEGetURL];

    if ([[DBSession sharedSession] isLinked]) {
        [self didPressRandomPhoto:nil];
    }
}

- (IBAction)didPressLinkDropbox:(id)sender {
    if ([[DBSession sharedSession] isLinked]) {
        // The link button turns into an unlink button when you're linked
        [[DBSession sharedSession] unlinkAll];
        restClient = nil;
        [self updateLinkButton];
    } else {
        [[DBAuthHelperOSX sharedHelper] authenticate];
    }
}

- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    // This gets called when the user clicks Show "App name". You don't need to do anything for Dropbox here
}


#pragma mark DBRestClientDelegate

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
    self.photosHash = metadata.hash;

    NSArray* validExtensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", nil];
    NSMutableArray* newPhotoPaths = [NSMutableArray new];
    for (DBMetadata* child in metadata.contents) {
        NSString* extension = [[child.path pathExtension] lowercaseString];
        if (!child.isDirectory && [validExtensions indexOfObject:extension] != NSNotFound) {
            [newPhotoPaths addObject:child.path];
        }
    }
    self.photosPaths = newPhotoPaths;
    [self loadRandomPhoto];
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path {
    [self loadRandomPhoto];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
    NSLog(@"restClient:loadMetadataFailedWithError: %@", error);
    self.randomPhotoButton.state = NSOnState;
}

- (void)restClient:(DBRestClient*)client loadedThumbnail:(NSString*)destPath {
    self.randomPhotoButton.state = NSOnState;
    self.imageView.image = [[NSImage alloc] initWithContentsOfFile:destPath];
}

- (void)restClient:(DBRestClient*)client loadThumbnailFailedWithError:(NSError*)error {
    NSLog(@"restClient:loadThumbnailFailedWithError: %@", error);
    self.randomPhotoButton.state = NSOnState;
}


#pragma mark private methods

- (void)authHelperStateChangedNotification:(NSNotification *)notification {
    [self updateLinkButton];
    if ([[DBSession sharedSession] isLinked]) {
        // You can now start using the API!
        [self didPressRandomPhoto:nil];
    }
}

- (void)didPressRandomPhoto:(id)sender {
    self.randomPhotoButton.state = NSOffState;

    NSString *photosRoot = nil;
    if ([DBSession sharedSession].root == kDBRootDropbox) {
        photosRoot = @"/Photos";
    } else {
        photosRoot = @"/";
    }

    [self.restClient loadMetadata:photosRoot withHash:self.photosHash];
}

- (void)loadRandomPhoto {
    if ([self.photosPaths count] == 0) {

        NSString *msg = nil;
        if ([DBSession sharedSession].root == kDBRootDropbox) {
            msg = @"Put .jpg photos in your Photos folder to use DBRoulette!";
        } else {
            msg = @"Put .jpg photos in your app's App folder to use DBRoulette!";
        }

        NSLog(@"Error: %@", msg);

        self.randomPhotoButton.state = NSOnState;
    } else {
        NSString* photoPath;
        if ([self.photosPaths count] == 1) {
            photoPath = [self.photosPaths objectAtIndex:0];
            if ([photoPath isEqual:self.currentPhotoPath]) {
                NSLog(@"You only have one photo to display.");

                self.randomPhotoButton.state = NSOnState;
                return;
            }
        } else {
            // Find a random photo that is not the current photo
            do {
                srandom((int)time(NULL));
                NSInteger index =  random() % [self.photosPaths count];
                photoPath = [self.photosPaths objectAtIndex:index];
            } while ([photoPath isEqual:self.currentPhotoPath]);
        }

        self.currentPhotoPath = photoPath;

        [self.restClient loadThumbnail:self.currentPhotoPath ofSize:@"l" intoPath:[self photoPath]];
    }
}

- (NSString*)photoPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"photo.jpg"];
}

- (void)displayError {
    NSLog(@"There was an error loading your photo.");
}

- (void)updateLinkButton {
    if ([[DBSession sharedSession] isLinked]) {
        self.linkButton.title = @"Unlink Dropbox";
    } else {
        self.linkButton.title = @"Link Dropbox";
        self.linkButton.state = [[DBAuthHelperOSX sharedHelper] isLoading] ? NSOffState : NSOnState;
    }
}

- (DBRestClient *)restClient {
    if (!restClient) {
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        restClient.delegate = self;
    }
    return restClient;
}


@end
