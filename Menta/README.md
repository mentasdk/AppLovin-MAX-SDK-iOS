# Menta MAX custom adapter

`MaxMentaAdapter` maps Menta Global formats to MAX:

| MAX format | Menta class |
| --- | --- |
| Banner | `MentaMediationBanner` |
| MREC | `MentaMediationNativeExpress` |
| Banner with `native_express = true` | `MentaMediationNativeExpress` |
| Interstitial | `MentaMediationInterstitial` |
| Rewarded | `MentaMediationRewardVideo` |
| App Open | `MentaMediationSplash` |
| Native | `MentaMediationNativeSelfRender` |

## MAX custom-network configuration

- Adapter class: `MaxMentaAdapter`
- Initialization parameters: `app_id`, `app_key`
- Placement ID: the Menta placement ID for the corresponding format
- Optional custom/server parameter `native_express = true` for a Menta
  NativeExpress placement exposed to MAX as an ad-view format.
- MAX Leader format is rejected because Menta does not expose a matching
  leader-board format.

The adapter forwards load, render/display, click, close and reward callbacks to
MAX. It also calls Menta's winner notification immediately before fullscreen
display and after a native ad is selected for rendering.
