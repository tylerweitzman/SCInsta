#import <DeviceCheck/DeviceCheck.h>

// Hinge reaches DeviceCheck two ways, both funneling through the framework classes below:
//   1. Firebase App Check providers: GACAppAttestProvider (DCAppAttestService),
//      GACDeviceCheckProvider (DCDevice). Tokens are cached with a TTL, so a call
//      only happens on a cache miss / refresh, NOT on every login.
//   2. Hinge's own AppAttestationCore -> attestation/v1/{challenge,attest,assert}.
//
// isSupported is the single chokepoint: when it returns NO, both Firebase and
// Hinge skip attestation entirely instead of trying and hard-failing on a
// re-signed (sideloaded) binary. We force NO so a sideload never attests.

%hook DCAppAttestService
- (BOOL)isSupported {
    NSLog(@"[DeviceCheck] AppAttest isSupported -> forcing NO (orig=%d)", %orig);
    return NO;
}
- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest generateKey called\n%@", [NSThread callStackSymbols]);
    void (^wrapped)(NSString *, NSError *) = ^(NSString *keyId, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest generateKey -> keyId=%@ error=%@", keyId, error);
        if (completion) completion(keyId, error);
    };
    %orig(wrapped);
}
- (void)attestKey:(NSString *)keyId clientDataHash:(NSData *)hash completionHandler:(void (^)(NSData *attestation, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest attestKey called keyId=%@ hashLen=%lu\n%@", keyId, (unsigned long)hash.length, [NSThread callStackSymbols]);
    void (^wrapped)(NSData *, NSError *) = ^(NSData *attestation, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest attestKey -> attestationLen=%lu error=%@", (unsigned long)attestation.length, error);
        if (completion) completion(attestation, error);
    };
    %orig(keyId, hash, wrapped);
}
- (void)generateAssertion:(NSString *)keyId clientDataHash:(NSData *)hash completionHandler:(void (^)(NSData *assertion, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest generateAssertion called keyId=%@\n%@", keyId, [NSThread callStackSymbols]);
    void (^wrapped)(NSData *, NSError *) = ^(NSData *assertion, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest generateAssertion -> assertionLen=%lu error=%@", (unsigned long)assertion.length, error);
        if (completion) completion(assertion, error);
    };
    %orig(keyId, hash, wrapped);
}
%end

%hook DCDevice
- (BOOL)isSupported {
    NSLog(@"[DeviceCheck] DCDevice isSupported -> forcing NO (orig=%d)", %orig);
    return NO;
}
- (void)generateTokenWithCompletionHandler:(void (^)(NSData *token, NSError *error))completion {
    NSLog(@"[DeviceCheck] DCDevice generateToken called\n%@", [NSThread callStackSymbols]);
    void (^wrapped)(NSData *, NSError *) = ^(NSData *token, NSError *error) {
        NSLog(@"[DeviceCheck] DCDevice generateToken -> tokenLen=%lu error=%@", (unsigned long)token.length, error);
        if (completion) completion(token, error);
    };
    %orig(wrapped);
}
%end

// Confirms at load time that the framework classes were present and hooked, so a
// silent "no logs" means "not called this session", not "hook never installed".
%ctor {
    NSLog(@"[DeviceCheck] hooks installed: DCAppAttestService=%@ DCDevice=%@",
          %c(DCAppAttestService) ? @"YES" : @"NO",
          %c(DCDevice) ? @"YES" : @"NO");
}
