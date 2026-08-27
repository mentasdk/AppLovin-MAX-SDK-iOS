//
//  ALMAXAutoLayoutBannerAdViewController.m
//  DemoApp-ObjC
//
//  Created by Thomas So on 9/4/19.
//  Copyright © 2019 AppLovin Corporation. All rights reserved.
//

#import "ALMAXAutoLayoutBannerAdViewController.h"
#import <Adjust/Adjust.h>
#import <AppLovinSDK/AppLovinSDK.h>

@interface ALMAXAutoLayoutBannerAdViewController()<MAAdViewAdDelegate, MAAdRevenueDelegate>
@property (nonatomic, strong) MAAdView *adView;
@end

@implementation ALMAXAutoLayoutBannerAdViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.adView = [[MAAdView alloc] initWithAdUnitIdentifier: @"5e47825a7c5b5a5e"];
    
    self.adView.delegate = self;
    self.adView.revenueDelegate = self;
    
    self.adView.translatesAutoresizingMaskIntoConstraints = NO;

    // Set background or background color for banners to be fully functional
    self.adView.backgroundColor = UIColor.blackColor;

    [self.view addSubview: self.adView];

    // Anchor the banner to the left, right, and top of the screen.
    [[self.adView.leadingAnchor constraintEqualToAnchor: self.view.leadingAnchor] setActive: YES];
    [[self.adView.trailingAnchor constraintEqualToAnchor: self.view.trailingAnchor] setActive: YES];
    [[self.adView.topAnchor constraintEqualToAnchor: self.view.topAnchor] setActive: YES];
    
    [[self.adView.widthAnchor constraintEqualToAnchor: self.view.widthAnchor] setActive: YES];
    [[self.adView.heightAnchor constraintEqualToConstant: UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 90 : 50 ] setActive: YES];
    
    // Load the first ad
    [self.adView loadAd];
    [self logCallback: "start load Ad..."];
}

#pragma mark - MAAdDelegate Protocol

- (void)didLoadAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error
{
    [self logCallback: __PRETTY_FUNCTION__];
}

- (void)didDisplayAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didHideAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didClickAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

#pragma mark - MAAdViewAdDelegate Protocol

- (void)didExpandAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didCollapseAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

#pragma mark - MAAdRevenueDelegate Protocol

- (void)didPayRevenueForAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
    
    ADJAdRevenue *adjustAdRevenue = [[ADJAdRevenue alloc] initWithSource: @"applovin_max_sdk"];
    [adjustAdRevenue setRevenue: ad.revenue currency: @"USD"];
    [adjustAdRevenue setAdRevenueNetwork: ad.networkName];
    [adjustAdRevenue setAdRevenueUnit: ad.adUnitIdentifier];
    [adjustAdRevenue setAdRevenuePlacement: ad.placement];

    [Adjust trackAdRevenue: adjustAdRevenue];
}

@end
