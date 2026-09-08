# Hinge iOS — Security, Integrity, and Gating Architecture

Reference notes for the Hinge tweak. Describes every client-side check, attestation,
fingerprint, and gate observed in **Hinge 9.134.0** (`co.hinge.mobile.ios`,
bundle build target iOS 16.0+), reverse-engineered from the decrypted IPA at
`packages_source/co.hinge.mobile.ios.ipa`.

Method for each claim: `ipsw class-dump` of `Payload/Hinge.app/Hinge`, `otool -l`
for load commands and encryption status, and `strings` over the main binary and the
bundled frameworks. Items are marked **confirmed** (a symbol, selector, string, or
endpoint is present in the binary) or **inferred** (behavior deduced from those
symbols plus how the SDK is known to work). Nothing here was observed at runtime;
runtime logging hooks are described in the last section.

---

## 0. Layer map

Hinge stacks several independent trust and gating layers. They are independent on
purpose: defeating one does not defeat the others.

| # | Layer | Purpose | Keyed to | Survives reinstall? |
|---|-------|---------|----------|---------------------|
| 1 | App-version gate | Force upgrade of stale builds | App version vs server min | n/a |
| 2 | Code signing / entitlements | Prove the binary is genuine Hinge | Apple cert + App ID | no (re-sign breaks it) |
| 3 | Firebase App Check | Gate API traffic to attested apps | App Attest / DeviceCheck token | token cached, TTL |
| 4 | Apple DeviceCheck (`DCDevice`) | Per-device 2-bit server flag | **Physical device** | **yes** |
| 5 | Apple App Attest (`DCAppAttestService`) | Prove genuine app + device | App key + device | key in Secure Enclave |
| 6 | Hinge attestation (`AppAttestationCore`) | Hinge's own challenge/attest/assert | App Attest key | as App Attest |
| 7 | Incognia | Device + behavioral fraud fingerprint | **Device + sensors + location** | **yes** |
| 8 | Persistent identifiers | Re-identify the install/device | Keychain / IDFV / FID | **keychain: yes** |
| 9 | FaceTec liveness | Prove a real, unique human | Face biometric | yes (biometric) |
| 10 | Ban gate + appeal | Enforce and surface a decided ban | account + device signals | yes |

Layers 4, 7, 8, and 9 are the ones that tie enforcement to the **physical device or
person**, not the account. Those are why a device ban outlives a fresh install and a
new account.

---

## 1. App-version gate ("It's time to update")

**Confirmed symbols:** `min_app_version`, `minAppVersion`, `androidMinimumVersion`,
`AppUpdateRequiredScreenViewedMetric`, `X-App-Version`, `bundleShortVersionString`,
`CFBundleShortVersionString`, `co.hinge.app_version_override`. Copy string:
`"This version of Hinge is no longer supported. Update to the newest version for the
best experience."`

**Flow (inferred):**
1. The app reads its own version from `CFBundleShortVersionString` and sends it on
   every request as the `X-App-Version` header.
2. Server config returns a `min_app_version`. The client compares its own version to
   that minimum.
3. If the app is older, `Hinge.RootOnboardingInteractor` routes to a
   `Hinge.AlertViewController` presented over `Hinge.RootOnboardingViewController`,
   inside a `UINavigationController`. The metric `AppUpdateRequiredScreenViewedMetric`
   fires when it appears.

The decision logic lives in Swift (`RootOnboardingPresenter` / `RootOnboardingInteractor`)
and exposes no Objective-C selector, so it cannot be hooked directly with Logos.

**Debug override:** the binary contains a developer feature "App version override"
backed by the user-defaults key `co.hinge.app_version_override`
(symbols `appVersionOverrideTextField`, `handleAppVersionOverrideClearButton`,
`SettingsAppVersionLabelCell`). Setting that key changes the version the app believes
it is.

**This is the only gate that is not tied to hardware.** It is a soft gate: the server
still serves the app, it only nags. That is why suppressing the alert client-side is
sufficient and why login worked without any attestation call.

---

## 2. Code signing and entitlements

A store build is signed by Apple with Hinge's App ID and entitlements (App Attest,
keychain access groups, associated domains). Re-signing for sideload replaces the
signing identity and, unless the exact App ID and entitlements are reproduced, changes
the App-ID-scoped context that App Attest and keychain access groups depend on.

**Consequence:** App Attest (layers 5/6) is bound to the original App ID's Secure
Enclave key. A re-signed sideload cannot produce an attestation that validates against
Apple for the genuine Hinge App ID, so those calls **hard-fail** if attempted. This is
the reason the tweak forces `isSupported → NO` (section 11): it makes the app skip an
attestation it could never pass, rather than failing it.

---

## 3. Firebase App Check (the umbrella over DeviceCheck + App Attest)

**Confirmed symbols:** `GACAppCheck`, `GACAppCheckToken`, `GACAppCheckProvider`,
`com.google.GACAppAttestProvider`, `GACDeviceCheckProvider`,
`GACDeviceCheckTokenGenerator`, `GACAppCheckStorageProtocol`,
`GACAppCheckTokenRefresherProtocol`, `isTokenAutoRefreshEnabled`, `X-Firebase-AppCheck`,
`exchangeDeviceCheckToken`, `appCheckUsingAppAttestProvider`.

App Check is Google's wrapper that turns an Apple attestation into a short-lived token
attached to backend requests as `X-Firebase-AppCheck`.

**Two providers, chosen at runtime (inferred):**
- **`GACAppAttestProvider`** → wraps `DCAppAttestService` (layer 5). Preferred on
  iOS 14+.
- **`GACDeviceCheckProvider`** → wraps `DCDevice` (layer 4). Fallback.

**Token caching (confirmed via storage/refresher protocols + TTL symbols):** App Check
persists the token and auto-refreshes on a timer. A fresh Apple attestation only
happens on a **cache miss or scheduled refresh**, not on every launch or login. This
is why runtime logs showed no DeviceCheck/App Attest calls during a normal login: a
cached token was served.

**Enforcement:** App Check can run "enforced" (backend rejects requests without a valid
token) or "unenforced" (backend logs but allows). Login succeeding on a re-signed build
with no fresh attestation implies the relevant endpoints are **unenforced or served a
cached/soft token**. Enforcement is a server-side decision and can change.

---

## 4. Apple DeviceCheck — `DCDevice` (the per-device ban bits)

**Confirmed:** `DCDevice`, `currentDevice`, `isSupported`,
`generateTokenWithCompletionHandler:`, `exchangeDeviceCheckToken`,
`GACDeviceCheckTokenGenerator`.

`DCDevice.generateToken` yields an opaque token that Apple binds to the **physical
device**. The app's backend exchanges it with Apple's DeviceCheck servers, where two
bits of state can be **set and read per (device, developer account)**. Those two bits
persist across:
- app deletion and reinstall,
- signing out / new account,
- iCloud account change.

**This is the classic device-ban primitive.** A platform sets a bit when it bans a
device; a later install on the same hardware reads the bit back and knows the device
was banned, regardless of the new account. It is keyed to the Apple device identity,
not to anything the app stores.

**Scope of the two bits:** limited to two boolean values plus a last-update timestamp,
per device per developer. Coarse, but durable and Apple-backed.

---

## 5. Apple App Attest — `DCAppAttestService`

**Confirmed:** `DCAppAttestService`, `sharedService`, `isSupported`,
`generateKeyWithCompletionHandler:`, `attestKey:clientDataHash:completionHandler:`,
`generateAssertion:clientDataHash:completionHandler:`,
`com.google.GACAppAttestProvider`.

App Attest proves two things cryptographically: the running binary is a genuine,
unmodified build of *this* App ID, and it is on a real Apple device. Flow (inferred
from the standard API):
1. `generateKey` creates a key in the Secure Enclave, bound to the App ID.
2. `attestKey:clientDataHash:` asks Apple to certify that key; the certificate goes to
   the backend once.
3. `generateAssertion:clientDataHash:` signs later requests with that key to prove
   continuity.

**Sideload impact:** the Secure Enclave key is bound to the genuine App ID. A re-signed
build gets a different signing context, so attestation for Hinge's real App ID cannot
be produced. Attempting it returns errors; skipping it (forcing `isSupported → NO`)
avoids the failure path.

---

## 6. Hinge's own attestation — `AppAttestationCore`

**Confirmed:** `_TtC18AppAttestationCore24AppAttestationRepository`,
`AppAttestationCore/AppAttestationRepository.swift`, endpoints
`attestation/v1/challenge`, `attestation/v1/ios/attest`, `attestation/v1/ios/assert`,
plus error symbols `appAttestGenerateKeyFailedWithError:`,
`appAttestAttestKeyFailedWithError:keyId:clientDataHash:`,
`appAttestGenerateAssertionFailedWithError:keyId:clientDataHash:`, and defaults keys
`co.hinge.app_attest_keyID.%@`, `app_check_app_attest_artifact.%@`.

Independently of Firebase, Hinge runs a first-party attestation handshake against its
own backend: fetch a `challenge`, `attest` a key, then `assert` on subsequent calls.
It consumes the same `DCAppAttestService` primitive, so it funnels through the same
`isSupported` chokepoint. Also references Incognia's own attestation completion state
(`com.incognia.common.core.appattestation.complete`, `.key_id`, `.ts`).

---

## 7. Incognia — device + behavioral + location fingerprint

**Confirmed:** frameworks `Incognia.framework`, `IncogniaCore.framework`,
`IncogniaTrial.framework` (all present, `cryptid=0` i.e. decrypted but symbol-stripped),
`_TtC5Hinge15IncogniaService`, and the Objective-C surface Hinge drives:

```
ICGIncognia setEnabled            ICGIncognia setAccountId
ICGIncognia clearAccountId        ICGIncognia registerCheckIn
ICGIncognia trackEvent            ICGIncognia trackLocalizedEvent
ICGIncognia fetchLocation         ICGIncognia refreshLocation
ICGIncognia setUserAddress        ICGIncognia clearUserAddress
ICGIncognia reportBusinessUnitId  ICGIncognia checkPrivacyConsentMissing
```

**What it is.** Incognia is a third-party fraud/identity SDK. Unlike DeviceCheck, it
does **not** use any Apple attestation API — it builds its own persistent device
identity from hardware, network, and location signals, and correlates it with
behavioral patterns. Its internal collection is stripped/obfuscated in the binary, so
the exact signal set is not directly readable, but the integration tells the story:

- `setAccountId` / `clearAccountId`: Incognia links the current Hinge account to its
  device identity. This is the join that lets Incognia tell Hinge "this new account is
  on a device previously associated with banned account X."
- `registerCheckIn`, `fetchLocation`, `refreshLocation`, `setUserAddress`: location is a
  first-class signal. Incognia is known for location-behavior fingerprinting (where the
  device sleeps at night, commute patterns), which is far harder to spoof than an ID.
- `trackEvent` / `trackLocalizedEvent`: behavioral events feed the risk model.
- `reportBusinessUnitId`: ties activity to a Hinge-specific tenant.

**Why it is the real device-ban enforcer.** It is independent of Apple's APIs, so
neutralizing DeviceCheck/App Attest does nothing to it. Its identity is derived from the
physical device and its environment, and it persists across reinstall and new accounts
by design. This is the layer that most directly realizes "device banned even though the
account is new."

---

## 8. Persistent identifiers (cross-install linkage)

**Confirmed constants:**
- `co.hinge.deviceIdentifier` — Hinge's own device ID. Named like a **keychain** item;
  keychain entries survive app deletion/reinstall (and can be shared via access group),
  so this re-identifies the device on a clean install unless the keychain item is
  removed.
- `co.hinge.installIdentifier` — per-install ID (resets on reinstall if stored in
  defaults, persists if in keychain).
- `_identifierForVendor` / `_identifierForVendorString` (IDFV) — stable per vendor while
  any app from that vendor is installed; resets only when all of a vendor's apps are
  removed.
- `_resettableDeviceID` / `hashedResettableDeviceID` — advertising-identity-derived
  (IDFA), user-resettable, gated by ATT permission. Referenced through AppsFlyer.
- `_firebaseInstallationID` / `FIRInstallationsItem` / `_installId` — Firebase
  Installations FID, used by App Check and analytics.

**Confirmed adjacent SDKs that also fingerprint/attribute:** AppsFlyer
(`AppsFlyerLib.framework`, install attribution, `hashedResettableDeviceID`),
Firebase Crashlytics (`FIRCLSInstallIdentifierModel`), Google/GA
(`GoogleAppMeasurement`), Sendbird (chat).

**Keychain is the quiet one.** Defaults-based IDs reset on reinstall; keychain-based
IDs do not. `co.hinge.deviceIdentifier` being keychain-named makes it a durable
cross-install anchor even without Incognia.

---

## 9. FaceTec — liveness / biometric identity

**Confirmed:** `FaceTecSDK.framework`, `_TtC5Hinge14FaceTecService`,
`OnboardingLiveness*` view controllers/presenters (`OnboardingLivenessViewController`,
`OnboardingLivenessDisclaimerView`, `OnboardingLivenessRemoteCopyPresenter`, etc.).

FaceTec performs a 3D liveness selfie during onboarding/verification. This binds the
account to a **biometric** of a real, unique person. It is the strongest anti-recidivism
signal Hinge has: a banned person can change device and network, but the face match can
still catch a re-registration. (Detailed separately in prior FaceTec analysis; here it
is one layer among many.) The heavy lifting is server-side; the client captures and
uploads.

---

## 10. Ban system

**Confirmed:** `_TtC5Hinge17BanGateInteractor`, `_TtC5Hinge18BanGatePresenterV2`,
`_TtC5Hinge16BanGateWireframe`, `_TtC5Hinge17BanGateButtonCell`,
`_TtC10PlayerCore22BannedPlayerRepository`, `_TtC13BanReasonCore19BanReasonRepository`,
`_TtC13BanAppealCore19BanAppealRepository`, `_TtC5Hinge20BanAppealV2Wireframe`,
endpoint `BanAppealEndpoint`, and Zendesk articles
`.../360038037334-Why-was-my-account-banned-` and `.../360061998734-How-can-I-appeal-my-ban-`.

This is the surfacing layer, not the detection layer. The server decides a ban using the
signals above (account behavior + device/DeviceCheck + Incognia + FaceTec), and the
client's `BanGate` shows the wall and the appeal flow. `BannedPlayerRepository` caches
ban state; `BanReasonRepository` and `BanAppealRepository` back the reason display and
appeal submission.

---

## 11. How the current tweak interacts with each layer

State of `Hinge/` in this repo:

| Layer | Tweak action | Effect |
|-------|-------------|--------|
| 1 version gate | `SkipUpdatePrompt.x` dismisses the "no longer supported" `AlertViewController` by copy match; pyzule stamps version 10.0.0 | Nag suppressed, version-independent |
| 2 code signing | (sideload re-sign) | Breaks native App Attest for Hinge's App ID |
| 3 App Check | none directly | Relies on cached/unenforced token |
| 4 DeviceCheck | `DeviceCheckLogging.x` forces `DCDevice.isSupported → NO`, logs `generateToken` | App skips DeviceCheck token generation; a re-sign already couldn't pass |
| 5 App Attest | forces `DCAppAttestService.isSupported → NO`, logs key/attest/assert | App skips attestation instead of hard-failing |
| 6 Hinge attestation | covered by the same `isSupported` chokepoint | Skipped |
| 7 Incognia | **none** | **Unaffected — still fingerprints the device** |
| 8 persistent IDs | **none** | **Unaffected — keychain device ID persists** |
| 9 FaceTec | none | Unaffected |
| 10 ban gate | none | Unaffected |
| FLEX | `Tweak.x` shows FLEX explorer on the real `Hinge.AppDelegate` | Runtime inspection |

**Load-time confirmation:** `DeviceCheckLogging.x` logs
`[DeviceCheck] hooks installed: DCAppAttestService=YES DCDevice=YES` in its `%ctor`, so
absence of later `[DeviceCheck]` lines means "not called this session" (cached token),
not "hook failed to install."

**Honest scope.** Forcing DeviceCheck/App Attest to unsupported is a **sideload-compat**
measure: a re-signed build cannot attest, so this avoids the failure path and stops the
app volunteering a DeviceCheck token. It is **not** device-ban immunity. Layers 7
(Incognia), 8 (keychain device ID), and 9 (FaceTec) independently re-identify the device
or person and are untouched by anything in this tweak. Any of them alone is sufficient
for Hinge to recognize a previously-banned device or user.

---

## 12. Quick reference — where to look

```
Main binary:      Payload/Hinge.app/Hinge  (cryptid 0, decrypted)
Frameworks:       Payload/Hinge.app/Frameworks/{Incognia,IncogniaCore,IncogniaTrial,
                  FaceTecSDK,AppsFlyerLib,FirebaseAnalytics,GoogleAppMeasurement}.framework
Attestation eps:  attestation/v1/challenge | /ios/attest | /ios/assert
App Check header: X-Firebase-AppCheck        Version header: X-App-Version
Keychain IDs:     co.hinge.deviceIdentifier | co.hinge.installIdentifier
Defaults keys:    co.hinge.app_version_override | co.hinge.app_attest_keyID.<x>
Ban endpoints:    BanAppealEndpoint (+ Zendesk 360038037334, 360061998734)
Dump command:     ipsw class-dump --headers -o out Payload/Hinge.app/Hinge
```

*Generated from static analysis of Hinge 9.134.0. Layer behavior for DeviceCheck,
App Attest, App Check, and Incognia reflects how those SDKs work plus the symbols
present; treat "inferred" rows as analysis, not observed runtime behavior.*
