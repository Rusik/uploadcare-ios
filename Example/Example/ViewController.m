//
//  ViewController.m
//  ExampleProject
//
//  Created by Yury Nechaev on 05.04.16.
//  Copyright © 2016 Uploadcare. All rights reserved.
//

#import "ViewController.h"
#import "DetailViewController.h"
#import "SVProgressHUD.h"
#import "Uploadcare.h"

#define RLog(fmt, ...)  { [self presentLogMessage:[NSString stringWithFormat:fmt, ##__VA_ARGS__]];}

static NSString * const testRemoteImagePath  = @"https://breezometer.com/wordpress/wp-content/uploads/2016/01/nature_big_tree_hd.jpg";
static NSString * const testRemoteDataPath  = @"http://download.thinkbroadband.com/100MB.zip";
static NSString * const testRemoteBigDataPath  = @"http://download.thinkbroadband.com/200MB.zip";


typedef NS_ENUM(NSUInteger, kCellType) {
    kCellTypeUploadData,
    kCellTypeUploadRemote,
    kCellTypeUploadBigRemote,
    kCellTypeUploadVeryBigRemote,
    kCellTypeGetFileInfo,
    kCellTypeCreateGroup,
    kCellTypeGetGroupInfo,
};

typedef NS_ENUM(NSUInteger, kSectionType) {
    kSectionTypeCore,
    kSectionTypeWidget
};

#define ROWS_COUNT 7
#define SECTIONS_COUNT 2

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) UCMenuViewController *menu;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.delegate = self;
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"detailSegue"]) {
        UITableViewCell *cell = sender;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        DetailViewController *dvc = [segue destinationViewController];
        self.delegate = dvc;
        [self performRequestForCellType:indexPath.row];
    }
}

#pragma mark - <UITableViewDelegate> <UITableViewDataSource>

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSectionTypeCore) {
        return @"Core";
    } else if (section == kSectionTypeWidget) {
        return @"Widget";
    } else {
        return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSectionTypeCore) {
        [self performSegueWithIdentifier:@"detailSegue" sender:[tableView cellForRowAtIndexPath:indexPath]];
    } else if (indexPath.section == kSectionTypeWidget) {
        [self showWidget:[tableView cellForRowAtIndexPath:indexPath]];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case kSectionTypeCore:
            return ROWS_COUNT;
            break;
            
        default:
            return 1;
            break;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SECTIONS_COUNT;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (indexPath.section == 0) {
        [cell.textLabel setText:cellTitleForType(indexPath.row)];
    } else {
        [cell.textLabel setText:@"Show widget"];
    }
    return cell;
}

#pragma mark - Uploadcare widget calls

- (void)showWidget:(UITableViewCell *)sender {

    self.menu = [[UCMenuViewController alloc] initWithProgress:^(NSUInteger bytesSent, NSUInteger bytesExpectedToSend) {
        float progress = (float)bytesSent / (float)bytesExpectedToSend;
        [SVProgressHUD showProgress:progress];
        NSLog(@"Widget progress: %f", progress);
    } completion:^(NSString *fileId, NSError *error) {
        [SVProgressHUD dismiss];
        [self.menu dismissViewControllerAnimated:YES completion:nil];
        if (!error) {
            NSLog(@"Successfully uploaded media with id: %@", fileId);
        } else {
            [self handleError:error];
        }
    }];
    
    [self.menu presentFrom:self];
}

#pragma mark - Uploadcare requests

- (void)performRequestForCellType:(kCellType)cellType {
    switch (cellType) {
        case kCellTypeUploadData: {
            [self testDataUpload:[self localFileData] completion:nil];
            break;
        }
        case kCellTypeUploadRemote: {
            [self testRemoteURL:[NSURL URLWithString:testRemoteImagePath] completion:nil];
            break;
        }
        case kCellTypeGetFileInfo: {
            [self testDataUpload:[self localFileData] completion:^(NSString *fileID) {
                [self testFileInfo:fileID];
            }];
            break;
        }
        case kCellTypeUploadBigRemote: {
            [self testRemoteURL:[NSURL URLWithString:testRemoteDataPath] completion:nil];
            break;
        }
        case kCellTypeUploadVeryBigRemote: {
            [self testRemoteURL:[NSURL URLWithString:testRemoteBigDataPath] completion:nil];
            break;
        }
        case kCellTypeCreateGroup: {
            [self testDataUpload:[self localFileData] completion:^(NSString *fileID) {
                [self testGroupCreate:@[fileID] completion:nil];
            }];
            break;
        }
        case kCellTypeGetGroupInfo: {
            [self testDataUpload:[self localFileData] completion:^(NSString *fileID) {
                [self testGroupCreate:@[fileID] completion:^(NSString *groupID) {
                    [self testGroupInfo:groupID];
                }];
            }];
            break;
        }
    }
}

- (void)testDataUpload:(NSData *)data completion:(void(^)(NSString *fileID))completion {
    UCFileUploadRequest *request = [UCFileUploadRequest requestWithFileData:[self localFileData] fileName:@"file" mimeType:@"image/jpeg"];
    if (request) RLog(@"Local file upload request created: %@", request);
    [[UCClient defaultClient] performUCRequest:request progress:^(NSUInteger totalBytesSent, NSUInteger totalBytesExpectedToSend) {
        float progress = (float)totalBytesSent / (float)totalBytesExpectedToSend;
        RLog(@"Progress: %f", progress);
    } completion:^(id response, NSError *error) {
        if (!error) {
            RLog(@"Response: %@", response);
            if (completion) completion(response[@"file" ]);
        } else {
            RLog(@"Error: %@", error.localizedDescription);
        }
    }];
}

- (void)testRemoteURL:(NSURL *)remoteURL completion:(void(^)(NSString *fileID))completion  {
    
    UCRemoteFileUploadRequest *req = [UCRemoteFileUploadRequest requestWithRemoteFileURL:remoteURL.absoluteString];
    if (req) RLog(@"Remote url request created: %@", req);
    [[UCClient defaultClient] performUCRequest:req progress:^(NSUInteger totalBytesSent, NSUInteger totalBytesExpectedToSend) {
        float progress = (float)totalBytesSent / (float)totalBytesExpectedToSend;
        RLog(@"Progress: %f", progress);
    } completion:^(id response, NSError *error) {
        if (!error) {
            RLog(@"Response: %@", response);
        } else {
            RLog(@"Error: %@", error.localizedDescription);
        }
    }];
}

- (void)testFileInfo:(NSString *)fileID {
    UCFileInfoRequest *request = [UCFileInfoRequest requestWithFileID:fileID];
    if (request) RLog(@"File info request created: %@", request);
    [[UCClient defaultClient] performUCRequest:request progress:nil completion:^(id response, NSError *error) {
        if (!error) {
            RLog(@"Response: %@", response);
        } else {
            RLog(@"Error: %@", error);
        }
    }];
}

- (void)testGroupInfo:(NSString *)groupInfo {
    UCGroupInfoRequest *req = [UCGroupInfoRequest requestWithGroupID:groupInfo];
    if (req) RLog(@"Group info request created: %@", req);
    [[UCClient defaultClient] performUCRequest:req progress:nil
                                    completion:^(id response, NSError *error) {
                                        if (!error) {
                                            RLog(@"Response: %@", response);
                                        } else {
                                            RLog(@"Error: %@", error.localizedDescription);
                                        }
                                    }];
}

- (void)testGroupCreate:(NSArray *)ids completion:(void(^)(NSString *groupID))completion {
    UCGroupPostRequest *req = [UCGroupPostRequest requestWithFileIDs:ids];
    if (req) RLog(@"Group post request created: %@", req);
    [[UCClient defaultClient] performUCRequest:req progress:nil
                                    completion:^(id response, NSError *error) {
                                        if (!error) {
                                            RLog(@"Response: %@", response);
                                            NSString *groupID = response[@"id"];
                                            if (completion) completion(groupID);
                                        } else {
                                            RLog(@"Error: %@", error.localizedDescription);
                                        }
    }];
}

- (void)presentLogMessage:(NSString *)logMessage {
    void (^block)(NSString *message) = ^void(NSString *message) {
        NSLog(@"%@", logMessage);
        if ([self.delegate respondsToSelector:@selector(didReceiveLogMessage:)]) {
            [self.delegate didReceiveLogMessage:logMessage];
        }
    };
    if ([[NSThread currentThread] isMainThread]) {
        block(logMessage);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(logMessage);
        });
    }
}

#pragma mark - Utilities

- (void)handleError:(NSError *)error {
    
    void (^block)(NSError *error) = ^void(NSError *error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"Ok"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    };
    if ([[NSThread currentThread] isMainThread]) {
        block(error);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            block(error);
        });
    }
    NSLog(@"Widget error: %@", error.localizedDescription);
}

- (NSData *)localFileData {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"testimage" ofType:@"jpg"];
    NSData *fileData = [[NSData alloc] initWithContentsOfFile:path];
    return fileData;
}

NSString *cellTitleForType(kCellType type) {
    NSString *returnedValue = nil;
    switch (type) {
        case kCellTypeUploadData: {
            returnedValue = @"Upload data";
            break;
        }
        case kCellTypeUploadRemote: {
            returnedValue = @"Upload remote image url";
            break;
        }
        case kCellTypeUploadBigRemote: {
            returnedValue = @"Upload 100mb remote file";
            break;
        }
        case kCellTypeUploadVeryBigRemote: {
            returnedValue = @"Upload 200mb remote file";
            break;
        }
        case kCellTypeGetFileInfo: {
            returnedValue = @"Get file info";
            break;
        }
        case kCellTypeCreateGroup: {
            returnedValue = @"Create group";
            break;
        }
        case kCellTypeGetGroupInfo: {
            returnedValue = @"Get group info";
            break;
        }
    }
    return returnedValue;
}

@end
