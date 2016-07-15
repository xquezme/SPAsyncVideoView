//
//  SPViewCell.h
//  SPAsyncVideoView
//
//  Created by Sergey Pimenov on 14/07/16.
//  Copyright © 2016 Pimenov Sergey. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SPAsyncVideoView;

@interface SPViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet SPAsyncVideoView *videoView;

@end
