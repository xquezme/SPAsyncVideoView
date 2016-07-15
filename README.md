# SPAsyncVideoView

[![CI Status](http://img.shields.io/travis/Pimenov Sergey/SPAsyncVideoView.svg?style=flat)](https://travis-ci.org/Pimenov Sergey/SPAsyncVideoView)
[![Version](https://img.shields.io/cocoapods/v/SPAsyncVideoView.svg?style=flat)](http://cocoapods.org/pods/SPAsyncVideoView)
[![License](https://img.shields.io/cocoapods/l/SPAsyncVideoView.svg?style=flat)](http://cocoapods.org/pods/SPAsyncVideoView)
[![Platform](https://img.shields.io/cocoapods/p/SPAsyncVideoView.svg?style=flat)](http://cocoapods.org/pods/SPAsyncVideoView)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Demo

![Demo](https://raw.githubusercontent.com/xquezme/SPAsyncVideoView/gh-pages/preview.gif)

## Requirements

* iOS 8.0 or higher

## Installation

SPAsyncVideoView is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "SPAsyncVideoView"
```

## Usage Example

``` objective-c
NSURL *url = [[NSBundle mainBundle] URLForResource:@"example" withExtension:@"mp4"];
SPAsyncVideoAsset *asset = [[SPAsyncVideoAsset alloc] initWithURL:url];
SPAsyncVideoView *view = [SPAsyncVideoView new];
view.asset = asset;
```

## Current limitations

* No audio.
* No controls.
* Working only with local videos.


## Author

Pimenov Sergey, pimenov.sergei@gmail.com

## License

SPAsyncVideoView is available under the MIT license. See the LICENSE file for more info.
