//
//  MaxMentaAdapter.m
//  MaxMentaAdapter
//

#import "MaxMentaAdapter.h"
#import <MentaBaseGlobal/MentaBaseGlobal-umbrella.h>
#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

#define ADAPTER_VERSION @"1.0.33"

@class MaxMentaAdapter;

@interface ALMentaNativeAd : MANativeAd

@property(nonatomic, weak) MaxMentaAdapter *parentAdapter;
@property(nonatomic, strong) MentaMediationNativeSelfRenderModel *mentaAd;

- (instancetype)initWithParentAdapter:(MaxMentaAdapter *)parentAdapter
                              mentaAd:(MentaMediationNativeSelfRenderModel *)mentaAd
                         builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock;

@end

@interface MaxMentaAdapter () <MentaMediationBannerDelegate,
                               MentaMediationInterstitialDelegate,
                               MentaMediationRewardVideoDelegate,
                               MentaMediationSplashDelegate,
                               MentaMediationNativeExpressDelegate,
                               MentaNativeSelfRenderDelegate>

@property(nonatomic, strong) MentaMediationBanner *bannerAd;
@property(nonatomic, strong) MentaMediationNativeExpress *nativeExpressAd;
@property(nonatomic, strong) id<MAAdViewAdapterDelegate> adViewDelegate;

@property(nonatomic, strong) MentaMediationInterstitial *interstitialAd;
@property(nonatomic, strong) id<MAInterstitialAdapterDelegate> interstitialDelegate;

@property(nonatomic, strong) MentaMediationRewardVideo *rewardedAd;
@property(nonatomic, strong) id<MARewardedAdapterDelegate> rewardedDelegate;
@property(nonatomic, assign) BOOL rewardedUser;

@property(nonatomic, strong) MentaMediationSplash *appOpenAd;
@property(nonatomic, strong) id<MAAppOpenAdapterDelegate> appOpenDelegate;

@property(nonatomic, strong) MentaMediationNativeSelfRender *nativeAd;
@property(nonatomic, strong) id<MANativeAdAdapterDelegate> nativeDelegate;

@end

@implementation MaxMentaAdapter

static ALAtomicBoolean *ALMentaInitialized;
static MAAdapterInitializationStatus ALMentaInitializationStatus = MAAdapterInitializationStatusAdapterNotInitialized;

+ (void)initialize {
    [super initialize];
    
    ALMentaInitialized = [[ALAtomicBoolean alloc] init];
}

#pragma mark - MAAdapter

- (NSString *)SDKVersion {
    return MentaAdSDK.shared.sdkVersion ?: @"unknown";
}

- (NSString *)adapterVersion {
    return ADAPTER_VERSION;
}

- (NSNumber *)shouldInitializeOnMainThread {
    return @YES;
}

- (NSNumber *)shouldLoadAdsOnMainThreadForAdFormat:(MAAdFormat *)adFormat {
    return @YES;
}

- (NSNumber *)shouldShowAdsOnMainThreadForAdFormat:(MAAdFormat *)adFormat {
    return @YES;
}

- (NSNumber *)shouldDestroyOnMainThread {
    return @YES;
}

- (void)initializeWithParameters:(id<MAAdapterInitializationParameters>)parameters
               completionHandler:(void (^)(MAAdapterInitializationStatus, NSString *_Nullable))completionHandler {
    if (MentaAdSDK.shared.isInitialized) {
        ALMentaInitializationStatus = MAAdapterInitializationStatusInitializedSuccess;
        [self updateConsentWithParameters:parameters];
        completionHandler(ALMentaInitializationStatus, nil);
        return;
    }

    if (![ALMentaInitialized compareAndSet:NO update:YES]) {
        completionHandler(ALMentaInitializationStatus, nil);
        return;
    }

    ALMentaInitializationStatus = MAAdapterInitializationStatusInitializing;
    NSString *appIdAndAppKey = [self stringForKeys:@[@"app_id", @"appId"] inDictionary:parameters.serverParameters];
    
    NSString *appId = nil;
    NSString *appKey = nil;
    if (appIdAndAppKey.length && [appIdAndAppKey containsString:@"|"]) {
        NSArray *args = [appIdAndAppKey componentsSeparatedByString:@"|"];
        appId = args[0];
        appKey = args[1];
    }
    
    if (appId.length == 0 || appKey.length == 0) {
        ALMentaInitializationStatus = MAAdapterInitializationStatusInitializedFailure;
        completionHandler(ALMentaInitializationStatus, @"Menta app_id and app_key are required");
        return;
    }

    if (parameters.isTesting) {
        [MentaAdSDK.shared setLogLevel:kMentaLogLevelInfo];
    }
    [self updateConsentWithParameters:parameters];

    [self d:@"Initializing Menta SDK with app ID: %@", appId];
    [MentaAdSDK.shared startWithAppID:appId
                               appKey:appKey
                          finishBlock:^(BOOL success, NSError *error) {
                              ALMentaInitializationStatus = success ? MAAdapterInitializationStatusInitializedSuccess
                                                                    : MAAdapterInitializationStatusInitializedFailure;
                              completionHandler(ALMentaInitializationStatus, error.localizedDescription);
                          }];
}

- (void)destroy {
    self.bannerAd.delegate = nil;
    self.bannerAd = nil;
    self.nativeExpressAd.delegate = nil;
    self.nativeExpressAd = nil;
    self.adViewDelegate = nil;

    self.interstitialAd.delegate = nil;
    self.interstitialAd = nil;
    self.interstitialDelegate = nil;

    self.rewardedAd.delegate = nil;
    self.rewardedAd = nil;
    self.rewardedDelegate = nil;

    self.appOpenAd.delegate = nil;
    self.appOpenAd = nil;
    self.appOpenDelegate = nil;

    self.nativeAd.delegate = nil;
    self.nativeAd = nil;
    self.nativeDelegate = nil;
}

#pragma mark - MAAdViewAdapter

- (void)loadAdViewAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         adFormat:(MAAdFormat *)adFormat
                        andNotify:(id<MAAdViewAdapterDelegate>)delegate {
    if (adFormat != MAAdFormat.banner && adFormat != MAAdFormat.mrec) {
        [delegate didFailToLoadAdViewAdWithError:MAAdapterError.invalidConfiguration];
        return;
    }

    NSString *placementID = parameters.thirdPartyAdPlacementIdentifier;
    if (![self validatePlacementID:placementID
                           failure:^(MAAdapterError *error) {
                               [delegate didFailToLoadAdViewAdWithError:error];
                           }])
        return;

    self.adViewDelegate = delegate;
    [self updateConsentWithParameters:parameters];
    BOOL useNativeExpress = adFormat == MAAdFormat.mrec || [self boolForKey:@"native_express" parameters:parameters];
    [self d:@"Loading Menta %@ ad view for placement: %@",
            useNativeExpress ? @"native express" : adFormat.label,
            placementID];

    if (useNativeExpress) {
        self.nativeExpressAd = [[MentaMediationNativeExpress alloc] initWithPlacementID:placementID];
        self.nativeExpressAd.delegate = self;
        [self.nativeExpressAd loadAd];
    } else {
        self.bannerAd = [[MentaMediationBanner alloc] initWithPlacementID:placementID];
        self.bannerAd.delegate = self;
        [self.bannerAd loadAd];
    }
}

#pragma mark - MAInterstitialAdapter

- (void)loadInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters
                              andNotify:(id<MAInterstitialAdapterDelegate>)delegate {
    NSString *placementID = parameters.thirdPartyAdPlacementIdentifier;
    if (![self validatePlacementID:placementID
                           failure:^(MAAdapterError *error) {
                               [delegate didFailToLoadInterstitialAdWithError:error];
                           }])
        return;

    self.interstitialDelegate = delegate;
    [self updateConsentWithParameters:parameters];
    self.interstitialAd = [[MentaMediationInterstitial alloc] initWithPlacementID:placementID];
    self.interstitialAd.delegate = self;
    [self.interstitialAd loadAd];
}

- (void)showInterstitialAdForParameters:(id<MAAdapterResponseParameters>)parameters
                              andNotify:(id<MAInterstitialAdapterDelegate>)delegate {
    if (!self.interstitialAd.isAdReady) {
        [delegate didFailToDisplayInterstitialAdWithError:MAAdapterError.adNotReady];
        return;
    }

    UIViewController *viewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
    if (!viewController) {
        [delegate didFailToDisplayInterstitialAdWithError:MAAdapterError.missingViewController];
        return;
    }

    [self.interstitialAd sendWinnerNotificationWith:nil];
    [self.interstitialAd showAdFromRootViewController:viewController];
}

#pragma mark - MARewardedAdapter

- (void)loadRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters
                          andNotify:(id<MARewardedAdapterDelegate>)delegate {
    NSString *placementID = parameters.thirdPartyAdPlacementIdentifier;
    if (![self validatePlacementID:placementID
                           failure:^(MAAdapterError *error) {
                               [delegate didFailToLoadRewardedAdWithError:error];
                           }])
        return;

    self.rewardedUser = NO;
    self.rewardedDelegate = delegate;
    [self updateConsentWithParameters:parameters];
    self.rewardedAd = [[MentaMediationRewardVideo alloc] initWithPlacementID:placementID];
    self.rewardedAd.delegate = self;
    [self.rewardedAd loadAd];
}

- (void)showRewardedAdForParameters:(id<MAAdapterResponseParameters>)parameters
                          andNotify:(id<MARewardedAdapterDelegate>)delegate {
    if (!self.rewardedAd.isAdReady) {
        [delegate didFailToDisplayRewardedAdWithError:MAAdapterError.adNotReady];
        return;
    }

    UIViewController *viewController = parameters.presentingViewController ?: [ALUtils topViewControllerFromKeyWindow];
    if (!viewController) {
        [delegate didFailToDisplayRewardedAdWithError:MAAdapterError.missingViewController];
        return;
    }

    [self configureRewardForParameters:parameters];
    [self.rewardedAd sendWinnerNotificationWith:nil];
    [self.rewardedAd showAdFromRootViewController:viewController];
}

#pragma mark - MAAppOpenAdapter

- (void)loadAppOpenAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         andNotify:(id<MAAppOpenAdapterDelegate>)delegate {
    NSString *placementID = parameters.thirdPartyAdPlacementIdentifier;
    if (![self validatePlacementID:placementID
                           failure:^(MAAdapterError *error) {
                               [delegate didFailToLoadAppOpenAdWithError:error];
                           }])
        return;

    self.appOpenDelegate = delegate;
    [self updateConsentWithParameters:parameters];
    self.appOpenAd = [[MentaMediationSplash alloc] initWithPlacementID:placementID];
    self.appOpenAd.delegate = self;
    [self.appOpenAd loadSplashAd];
}

- (void)showAppOpenAdForParameters:(id<MAAdapterResponseParameters>)parameters
                         andNotify:(id<MAAppOpenAdapterDelegate>)delegate {
    if (!self.appOpenAd.isAdReady) {
        [delegate didFailToDisplayAppOpenAdWithError:MAAdapterError.adNotReady];
        return;
    }

    UIWindow *window = parameters.presentingViewController.view.window ?: UIApplication.sharedApplication.keyWindow;
    if (!window) {
        [delegate didFailToDisplayAppOpenAdWithError:MAAdapterError.adDisplayFailedError];
        return;
    }

    [self.appOpenAd sendWinnerNotificationWith:nil];
    [self.appOpenAd showAdInWindow:window];
}

#pragma mark - MANativeAdAdapter

- (void)loadNativeAdForParameters:(id<MAAdapterResponseParameters>)parameters
                        andNotify:(id<MANativeAdAdapterDelegate>)delegate {
    NSString *placementID = parameters.thirdPartyAdPlacementIdentifier;
    if (![self validatePlacementID:placementID
                           failure:^(MAAdapterError *error) {
                               [delegate didFailToLoadNativeAdWithError:error];
                           }])
        return;

    self.nativeDelegate = delegate;
    [self updateConsentWithParameters:parameters];
    self.nativeAd = [[MentaMediationNativeSelfRender alloc] initWithPlacementID:placementID];
    self.nativeAd.delegate = self;
    [self.nativeAd loadAd];
}

#pragma mark - Menta Banner / NativeExpress delegates

- (void)menta_bannerAdRenderSuccess:(MentaMediationBanner *)banner bannerAdView:(UIView *)bannerAdView {
    [banner sendWinnerNotificationWith:nil];
    [self.adViewDelegate didLoadAdForAdView:bannerAdView withExtraInfo:[self extraInfoForECPM:banner.eCPM]];
}

- (void)menta_bannerAdDidLoad:(MentaMediationBanner *)banner {
}

- (void)menta_bannerAdLoadFailedWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    [self.adViewDelegate didFailToLoadAdViewAdWithError:[self.class toMaxError:error]];
}

- (void)menta_bannerAdRenderFailureWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    [self.adViewDelegate didFailToLoadAdViewAdWithError:[self.class toMaxError:error]];
}

- (void)menta_bannerAdExposed:(MentaMediationBanner *)banner {
    [self.adViewDelegate didDisplayAdViewAd];
}

- (void)menta_bannerAdClicked:(MentaMediationBanner *)banner {
    [self.adViewDelegate didClickAdViewAd];
}

- (void)menta_bannerAdClosed:(MentaMediationBanner *)banner {
    [self.adViewDelegate didHideAdViewAd];
}

- (void)menta_nativeExpressAdRenderSuccess:(MentaMediationNativeExpress *)nativeExpress
                         nativeExpressView:(UIView *)nativeExpressView {
    [nativeExpress sendWinnerNotificationWith:nil];
    [self.adViewDelegate didLoadAdForAdView:nativeExpressView withExtraInfo:[self extraInfoForECPM:nativeExpress.eCPM]];
}

- (void)menta_nativeExpressAdDidLoad:(MentaMediationNativeExpress *)nativeExpress {
}

- (void)menta_nativeExpressAdLoadFailedWithError:(NSError *)error
                                   nativeExpress:(MentaMediationNativeExpress *)nativeExpress {
    [self.adViewDelegate didFailToLoadAdViewAdWithError:[self.class toMaxError:error]];
}

- (void)menta_nativeExpressAdRenderFailureWithError:(NSError *)error
                                      nativeExpress:(MentaMediationNativeExpress *)nativeExpress {
    [self.adViewDelegate didFailToLoadAdViewAdWithError:[self.class toMaxError:error]];
}

- (void)menta_nativeExpressAdExposed:(MentaMediationNativeExpress *)nativeExpress {
    [self.adViewDelegate didDisplayAdViewAd];
}

- (void)menta_nativeExpressrAdClicked:(MentaMediationNativeExpress *)nativeExpress {
    [self.adViewDelegate didClickAdViewAd];
}

- (void)menta_nativeExpressAdClosed:(MentaMediationNativeExpress *)nativeExpress {
    [self.adViewDelegate didHideAdViewAd];
}

#pragma mark - Menta Interstitial delegate

- (void)menta_interstitialDidLoad:(MentaMediationInterstitial *)interstitial {
}

- (void)menta_interstitialWillPresent:(MentaMediationInterstitial *)interstitial {
}

- (void)menta_interstitialPlayCompleted:(MentaMediationInterstitial *)interstitial {
}

- (void)menta_interstitialRenderSuccess:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didLoadInterstitialAdWithExtraInfo:[self extraInfoForECPM:interstitial.eCPM]];
}

- (void)menta_interstitialLoadFailedWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didFailToLoadInterstitialAdWithError:[self.class toMaxError:error]];
}

- (void)menta_interstitialRenderFailureWithError:(NSError *)error
                                    interstitial:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didFailToLoadInterstitialAdWithError:[self.class toMaxError:error]];
}

- (void)menta_interstitialShowFailWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didFailToDisplayInterstitialAdWithError:[self.class toMaxError:error]];
}

- (void)menta_interstitialExposed:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didDisplayInterstitialAd];
}

- (void)menta_interstitialClicked:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didClickInterstitialAd];
}

- (void)menta_interstitialClosed:(MentaMediationInterstitial *)interstitial {
    [self.interstitialDelegate didHideInterstitialAd];
}

#pragma mark - Menta Rewarded delegate

- (void)menta_rewardVideoDidLoad:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoWillPresent:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoSkiped:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoPlayCompleted:(MentaMediationRewardVideo *)rewardVideo {
}

- (void)menta_rewardVideoRenderSuccess:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didLoadRewardedAdWithExtraInfo:[self extraInfoForECPM:rewardVideo.eCPM]];
}

- (void)menta_rewardVideoLoadFailedWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didFailToLoadRewardedAdWithError:[self.class toMaxError:error]];
}

- (void)menta_rewardVideoRenderFailureWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didFailToLoadRewardedAdWithError:[self.class toMaxError:error]];
}

- (void)menta_rewardVideoShowFailWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didFailToDisplayRewardedAdWithError:[self.class toMaxError:error]];
}

- (void)menta_rewardVideoExposed:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didDisplayRewardedAd];
}

- (void)menta_rewardVideoClicked:(MentaMediationRewardVideo *)rewardVideo {
    [self.rewardedDelegate didClickRewardedAd];
}

- (void)menta_rewardVideoDidEarnReward:(MentaMediationRewardVideo *)rewardVideo {
    self.rewardedUser = YES;
}

- (void)menta_rewardVideoClosed:(MentaMediationRewardVideo *)rewardVideo {
    if (self.rewardedUser || self.shouldAlwaysRewardUser) {
        [self.rewardedDelegate didRewardUserWithReward:self.reward];
    }
    [self.rewardedDelegate didHideRewardedAd];
}

#pragma mark - Menta Splash delegate

- (void)menta_splashAdDidLoad:(MentaMediationSplash *)splash {
}

- (void)menta_splashAdWillPresent:(MentaMediationSplash *)splash {
}

- (void)menta_splashAdRenderSuccess:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didLoadAppOpenAdWithExtraInfo:[self extraInfoForECPM:splash.eCPM]];
}

- (void)menta_splashAdLoadFailedWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didFailToLoadAppOpenAdWithError:[self.class toMaxError:error]];
}

- (void)menta_splashAdRenderFailureWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didFailToLoadAppOpenAdWithError:[self.class toMaxError:error]];
}

- (void)menta_splashAdShowFailWithError:(NSError *)error splash:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didFailToDisplayAppOpenAdWithError:[self.class toMaxError:error]];
}

- (void)menta_splashAdExposed:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didDisplayAppOpenAd];
}

- (void)menta_splashAdClicked:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didClickAppOpenAd];
}

- (void)menta_splashAdClosed:(MentaMediationSplash *)splash {
    [self.appOpenDelegate didHideAppOpenAd];
}

#pragma mark - Menta NativeSelfRender delegate

- (void)menta_nativeSelfRenderLoadSuccess:(NSArray<MentaMediationNativeSelfRenderModel *> *)nativeSelfRenderAds
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    MentaMediationNativeSelfRenderModel *ad = nativeSelfRenderAds.firstObject;
    if (!ad) {
        [self.nativeDelegate didFailToLoadNativeAdWithError:MAAdapterError.noFill];
        return;
    }

    MANativeAdImage *icon =
        ad.iconURL.length > 0 ? [[MANativeAdImage alloc] initWithURL:[NSURL URLWithString:ad.iconURL]] : nil;
    MANativeAdImage *mainImage =
        ad.materialURL.length > 0 ? [[MANativeAdImage alloc] initWithURL:[NSURL URLWithString:ad.materialURL]] : nil;
    UIView<MentaMediationNativeSelfRenderViewProtocol> *mediaContainer = ad.selfRenderView;
    if (ad.isVideo && mediaContainer.mediaView) {
        UIView *videoView = mediaContainer.mediaView;
        videoView.frame = mediaContainer.bounds;
        videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [mediaContainer addSubview:videoView];
    } else if (ad.materialURL.length > 0) {
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:mediaContainer.bounds];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [imageView setImageWithURL:[NSURL URLWithString:ad.materialURL]];
        [mediaContainer addSubview:imageView];
    }

    ALMentaNativeAd *maxNativeAd =
        [[ALMentaNativeAd alloc] initWithParentAdapter:self
                                               mentaAd:ad
                                          builderBlock:^(MANativeAdBuilder *builder) {
                                              builder.title = ad.title;
                                              builder.advertiser = ad.platformName;
                                              builder.body = ad.des;
                                              builder.callToAction = @"Learn More";
                                              builder.icon = icon;
                                              builder.mainImage = mainImage;
                                              builder.mediaView = mediaContainer;
                                              builder.optionsView = ad.adLogo;
                                              CGFloat width = ad.isVideo ? ad.videoCoverWidth : ad.materialWidth;
                                              CGFloat height = ad.isVideo ? ad.videoCoverHeight : ad.materialHeight;
                                              builder.mediaContentAspectRatio = height > 0 ? width / height : 0;
                                          }];

    [nativeSelfRender sendWinnerNotificationWith:nil];
    [self.nativeDelegate didLoadAdForNativeAd:maxNativeAd withExtraInfo:[self extraInfoForECPM:nativeSelfRender.eCPM]];
}

- (void)menta_nativeSelfRenderLoadFailure:(NSError *)error
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    [self.nativeDelegate didFailToLoadNativeAdWithError:[self.class toMaxError:error]];
}

- (void)menta_nativeSelfRenderViewExposed {
    [self.nativeDelegate didDisplayNativeAdWithExtraInfo:nil];
}

- (void)menta_nativeSelfRenderViewClicked {
    [self.nativeDelegate didClickNativeAd];
}

- (void)menta_nativeSelfRenderViewClosed {
}

#pragma mark - Helpers

- (BOOL)validatePlacementID:(NSString *)placementID failure:(void (^)(MAAdapterError *error))failure {
    if (ALMentaInitializationStatus != MAAdapterInitializationStatusInitializedSuccess) {
        failure(MAAdapterError.notInitialized);
        return NO;
    }
    if (placementID.length == 0) {
        failure(MAAdapterError.invalidConfiguration);
        return NO;
    }
    return YES;
}

- (NSString *)stringForKeys:(NSArray<NSString *> *)keys inDictionary:(NSDictionary<NSString *, id> *)dictionary {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value isKindOfClass:NSString.class] && [value length] > 0)
            return value;
    }
    return @"";
}

- (BOOL)boolForKey:(NSString *)key parameters:(id<MAAdapterParameters>)parameters {
    id value = parameters.customParameters[key] ?: parameters.serverParameters[key] ?: parameters.localExtraParameters[key];
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

- (void)updateConsentWithParameters:(id<MAAdapterParameters>)parameters {
    if (parameters.hasUserConsent != nil) {
        [MentaAdSDK.shared setGDPRStatus:parameters.hasUserConsent.boolValue ? MentaConsentStatusAuthorized
                                                                             : MentaConsentStatusDeniedOrNotDetermined];
    }
    if (parameters.isDoNotSell != nil) {
        [MentaAdSDK.shared setCCPAStatus:parameters.isDoNotSell.boolValue ? MentaConsentStatusDeniedOrNotDetermined
                                                                          : MentaConsentStatusAuthorized];
    }
}

- (NSDictionary<NSString *, id> *)extraInfoForECPM:(id)eCPM {
    return eCPM ? @{@"menta_ecpm" : eCPM} : @{};
}

+ (MAAdapterError *)toMaxError:(NSError *)error {
    MAAdapterError *maxError = MAAdapterError.unspecified;
    NSString *message = error.localizedDescription.lowercaseString;
    if ([message containsString:@"no fill"] || [message containsString:@"no ad"]) {
        maxError = MAAdapterError.noFill;
    } else if (error.code == NSURLErrorTimedOut) {
        maxError = MAAdapterError.timeout;
    } else if (error.code == NSURLErrorNotConnectedToInternet || error.code == NSURLErrorNetworkConnectionLost) {
        maxError = MAAdapterError.noConnection;
    }

    return [MAAdapterError errorWithAdapterError:maxError
                        mediatedNetworkErrorCode:error.code
                     mediatedNetworkErrorMessage:error.localizedDescription ?: @"Unknown Menta error"];
}

@end

@implementation ALMentaNativeAd

- (instancetype)initWithParentAdapter:(MaxMentaAdapter *)parentAdapter
                              mentaAd:(MentaMediationNativeSelfRenderModel *)mentaAd
                         builderBlock:(NS_NOESCAPE MANativeAdBuilderBlock)builderBlock {
    self = [super initWithFormat:MAAdFormat.native builderBlock:builderBlock];
    if (self) {
        _parentAdapter = parentAdapter;
        _mentaAd = mentaAd;
    }
    return self;
}

- (BOOL)prepareForInteractionClickableViews:(NSArray<UIView *> *)clickableViews withContainer:(UIView *)container {
    UIView<MentaMediationNativeSelfRenderViewProtocol> *mentaView = self.mentaAd.selfRenderView;
    if (!mentaView)
        return NO;
    [mentaView menta_registerClickableViews:clickableViews closeableViews:@[]];
    return YES;
}

- (BOOL)isContainerClickable {
    return YES;
}

@end
