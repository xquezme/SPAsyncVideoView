//
//  SPViewController.m
//  SPAsyncVideoView
//
//  Created by Pimenov Sergey on 07/14/2016.
//  Copyright (c) 2016 Pimenov Sergey. All rights reserved.
//

#import "SPViewController.h"

@import SPAsyncVideoView;

#import "SPViewCell.h"

@interface SPViewController ()

@property (nonatomic, strong) NSArray<NSURL *> *mp4Urls;
@property (nonatomic, strong) NSArray<NSURL *> *gifUrls;

@end

@implementation SPViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mp4Urls = @[[[NSBundle mainBundle] URLForResource:@"small" withExtension:@"mp4"],
                     [[NSBundle mainBundle] URLForResource:@"medium" withExtension:@"mp4"],
                     [[NSBundle mainBundle] URLForResource:@"big" withExtension:@"mp4"]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Random Scroll"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(rightBarButtonItemPressed:)];

    self.gifUrls = @[[[NSBundle mainBundle] URLForResource:@"200w" withExtension:@"gif"],
                     [[NSBundle mainBundle] URLForResource:@"201w" withExtension:@"gif"]];

	// Do any additional setup after loading the view, typically from a nib.
}

- (void)rightBarButtonItemPressed:(id)sender {
    [self.tableView setContentOffset:CGPointMake(0, arc4random() % (NSInteger)self.tableView.contentSize.height) animated:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1000;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SPViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Default" forIndexPath:indexPath];

    SPAsyncVideoAsset *asset;
    if (arc4random() % 2 == 1) {
        NSURL *url = self.mp4Urls[arc4random() % self.mp4Urls.count];
        asset = [[SPAsyncVideoAsset alloc] initWithURL:url type:SPAsyncVideoAssetTypeVideo];
    } else {
        NSURL *url = self.gifUrls[arc4random() % self.gifUrls.count];
        asset = [[SPAsyncVideoAsset alloc] initWithURL:url type:SPAsyncVideoAssetTypeGIF];
    }

    cell.videoView.asset = asset;

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 240.f;
}

@end
