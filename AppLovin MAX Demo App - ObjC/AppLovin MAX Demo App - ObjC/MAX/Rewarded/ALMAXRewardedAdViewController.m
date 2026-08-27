//
//  ALMAXRewardedAdViewController.m
//  DemoApp-ObjC
//
//  Created by Thomas So on 9/4/19.
//  Copyright © 2019 AppLovin Corporation. All rights reserved.
//

#import "ALMAXRewardedAdViewController.h"
#import <Adjust/Adjust.h>
#import <AppLovinSDK/AppLovinSDK.h>

@interface ALMAXRewardedAdViewController()<MARewardedAdDelegate, MAAdRevenueDelegate>
@property (nonatomic, strong) MARewardedAd *rewardedAd;
@property (nonatomic, assign) NSInteger retryAttempt;
@end

@implementation ALMAXRewardedAdViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.rewardedAd = [MARewardedAd sharedWithAdUnitIdentifier: @"d6f76c186e3fb450"];
    
    self.rewardedAd.delegate = self;
    self.rewardedAd.revenueDelegate = self;
    
    // Load the first ad
    [self.rewardedAd loadAd];
    [self logCallback: "start load Ad..."];
}

#pragma mark - IB Actions

- (IBAction)showAd
{
    if ( [self.rewardedAd isReady] )
    {
        [self.rewardedAd showAd];
    }
}

#pragma mark - MAAdDelegate Protocol

- (void)didLoadAd:(MAAd *)ad
{
    // Rewarded ad is ready to be shown. '[self.rewardedAd isReady]' will now return 'YES'
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
    
    // Reset retry attempt
    self.retryAttempt = 0;
}

- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error
{
    [self logCallback: __PRETTY_FUNCTION__];
    
    // Rewarded ad failed to load. We recommend retrying with exponentially higher delays up to a maximum delay (in this case 64 seconds).
    
    self.retryAttempt++;
    NSInteger delaySec = pow(2, MIN(6, self.retryAttempt));
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delaySec * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.rewardedAd loadAd];
        [self logCallback: "start load Ad..."];
    });
}

- (void)didDisplayAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didClickAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
}

- (void)didHideAd:(MAAd *)ad
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
    
    // Rewarded ad is hidden. Pre-load the next ad
    [self.rewardedAd loadAd];
    [self logCallback: "start load Ad..."];
}

- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error
{
    [self logCallback: [NSString stringWithFormat:@"%@: %s", ad.networkName, __PRETTY_FUNCTION__].UTF8String];
    
    // Rewarded ad failed to display. We recommend loading the next ad
    [self.rewardedAd loadAd];
    [self logCallback: "start load Ad..."];
}

#pragma mark - MARewardedAdDelegate Protocol

- (void)didRewardUserForAd:(MAAd *)ad withReward:(MAReward *)reward
{
    // Rewarded ad was displayed and user should receive the reward
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
