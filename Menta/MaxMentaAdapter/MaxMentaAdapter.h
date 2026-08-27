//
//  MaxMentaAdapter.h
//  MaxMentaAdapter
//

#import <AppLovinSDK/AppLovinSDK.h>

NS_ASSUME_NONNULL_BEGIN

/// MAX custom adapter for the Menta Global SDK.
///
/// Supported MAX formats:
/// - Banner (Menta Banner; set `native_express` to true to use NativeExpress)
/// - MREC (Menta NativeExpress)
/// - Interstitial
/// - Rewarded
/// - App Open (Menta Splash)
/// - Native (Menta NativeSelfRender)
@interface MaxMentaAdapter : ALMediationAdapter <MAAdViewAdapter,
                                                 MAInterstitialAdapter,
                                                 MARewardedAdapter,
                                                 MAAppOpenAdapter,
                                                 MANativeAdAdapter>

@end

NS_ASSUME_NONNULL_END
