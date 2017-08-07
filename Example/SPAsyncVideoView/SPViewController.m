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

@end

@implementation SPViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mp4Urls = @[[[NSBundle mainBundle] URLForResource:@"small" withExtension:@"mp4"]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Random Scroll"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(rightBarButtonItemPressed:)];

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

    cell.videoView.assetURL = self.mp4Urls[arc4random() % self.mp4Urls.count];;

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 240.f;
}

@end
