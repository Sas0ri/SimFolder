//
//  AppDelegate.m
//  SimFolder
//
//  Created by sasori on 2019/5/29.
//  Copyright © 2019 sasori. All rights reserved.
//

#import "AppDelegate.h"
#import <AppKit/AppKit.h>

@interface SFApp : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *containerPath;
@end

@interface SFDevice : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSArray<SFApp *> *apps;
@end

@interface AppDelegate () <NSMenuDelegate>

@property (strong, nonatomic) NSStatusItem *item;

@property (strong, nonatomic) NSMenu *menu;

@property (nonatomic, copy) NSArray<SFDevice *> *bootedDevices;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.item.button setImage:[NSImage imageNamed:@"StatusBar"]];
    
    self.menu = [NSMenu new];
    self.item.menu = self.menu;
    self.menu.delegate = self;
    
    [self loadData];
    [self reloadData];
}

- (void)menuWillOpen:(NSMenu *)menu {

}

- (void)reloadData {
    [self.menu removeAllItems];
    for (SFDevice *device in self.bootedDevices) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:device.name action:nil keyEquivalent:device.identifier];
        NSMenu *subMenu = nil;
        if (device.apps.count > 0) {
            subMenu = [NSMenu new];
            item.submenu = subMenu;
        }
        for (SFApp *app in device.apps) {
            NSMenuItem *subItem = [[NSMenuItem alloc] initWithTitle:app.name action:@selector(menuAction:) keyEquivalent:@""];
            [subMenu addItem:subItem];
        }
        [self.menu addItem:item];
    }
    
    NSMenuItem *separator = [NSMenuItem separatorItem];
    [self.menu addItem:separator];
    
    [self.menu addItemWithTitle:@"Refresh" action:@selector(refreshAction:) keyEquivalent:@"r"];

    [self.menu addItemWithTitle:@"Quit" action:@selector(quitAction:) keyEquivalent:@""];
}

- (void)menuAction:(NSMenuItem *)sender {
    NSInteger superIndex = [self.menu indexOfItem:sender.parentItem];
    NSInteger index = [sender.menu indexOfItem:sender];
    NSString *containerPath = self.bootedDevices[superIndex].apps[index].containerPath;
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[containerPath];
    [task launch];
}

- (void)quitAction:(NSMenuItem *)sender {
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)refreshAction:(NSMenuItem *)sender {
    [self loadData];
    [self reloadData];
}

- (void)loadData {
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/xcrun";
    task.arguments = @[@"simctl", @"list", @"-j"];
    NSPipe *pipe = [NSPipe new];
    task.standardOutput = pipe;
    [task launch];
 
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

    NSMutableArray *bootedDevices = [NSMutableArray array];
    NSDictionary *deviceTypes = dic[@"devices"];
    for (NSString *deviceType in deviceTypes.allKeys) {
        NSArray *devices = deviceTypes[deviceType];
        for (NSDictionary *device in devices) {
            if ([device[@"state"] isEqualToString:@"Booted"]) {
                SFDevice *d = [SFDevice new];
                d.name = device[@"name"];
                d.identifier = device[@"udid"];
                [self getInstalledAppsOfDevice:d];
                [bootedDevices addObject:d];
            }
        }
        
    }
    self.bootedDevices = bootedDevices;
}

- (void)getInstalledAppsOfDevice:(SFDevice *)device {
    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/bin/xcrun";
    task.arguments = @[@"simctl", @"listapps", device.identifier, @"plutil -convert json - -o -"];
    NSPipe *pipe = [NSPipe new];
    task.standardOutput = pipe;
    
    NSTask *task1 = [NSTask new];
    task1.launchPath = @"/usr/bin/plutil";
    task1.arguments = @[@"-convert", @"json", @"-", @"-o", @"-"];
    task1.standardInput = pipe;
    
    NSPipe *pipeToMe = [NSPipe new];
    task1.standardOutput = pipeToMe;
    [task launch];
    [task1 launch];
    
    NSData *data = [pipeToMe.fileHandleForReading readDataToEndOfFile];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    NSMutableArray *apps = [NSMutableArray array];
    for (NSString *key in dic.allKeys) {
        SFApp *app = [SFApp new];
        app.identifier = key;
        app.name = dic[key][@"CFBundleDisplayName"];
        app.containerPath = dic[key][@"DataContainer"];
        if (!app.containerPath) {
            app.containerPath = @"";
        }
        [apps addObject:app];
    }
    device.apps = [apps copy];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end

@implementation SFApp

@end

@implementation SFDevice

@end
