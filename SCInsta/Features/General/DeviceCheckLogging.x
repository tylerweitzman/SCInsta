#import <DeviceCheck/DeviceCheck.h>

%hook DCDevice
- (BOOL)isSupported {
    BOOL result = %orig;
    NSLog(@"[DeviceCheck] isSupported = %@", result ? @"YES" : @"NO");
    return result;
}

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *token, NSError *error))completion {
    NSLog(@"[DeviceCheck] generateToken called");

    // ponytail: block kept in a local; pinned Logos can't parse a multi-line block inside %orig(...)
    void (^wrapped)(NSData *, NSError *) = ^(NSData *token, NSError *error) {
        NSLog(@"[DeviceCheck] token present = %@", token != nil ? @"YES" : @"NO");
        NSLog(@"[DeviceCheck] error = %@", error);
        if (completion) completion(token, error);
    };

    %orig(wrapped);
}
%end

// IG 445 uses App Attest, not DCDevice. Referenced selectors: sharedService, isSupported,
// generateKeyWithCompletionHandler:, attestKey:clientDataHash:completionHandler:
%hook DCAppAttestService
- (BOOL)isSupported {
    BOOL result = %orig;
    NSLog(@"[DeviceCheck] AppAttest isSupported = %@", result ? @"YES" : @"NO");
    return result;
}

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest generateKey called");
    NSLog(@"[DeviceCheck] caller:\n%@", [NSThread callStackSymbols]);

    void (^wrapped)(NSString *, NSError *) = ^(NSString *keyId, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest generateKey -> keyId=%@ error=%@", keyId, error);
        if (completion) completion(keyId, error);
    };

    %orig(wrapped);
}

- (void)attestKey:(NSString *)keyId clientDataHash:(NSData *)hash completionHandler:(void (^)(NSData *attestation, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest attestKey called keyId=%@ hashLen=%lu", keyId, (unsigned long)hash.length);
    NSLog(@"[DeviceCheck] caller:\n%@", [NSThread callStackSymbols]);

    void (^wrapped)(NSData *, NSError *) = ^(NSData *attestation, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest attestKey -> attestationLen=%lu error=%@", (unsigned long)attestation.length, error);
        if (completion) completion(attestation, error);
    };

    %orig(keyId, hash, wrapped);
}

- (void)generateAssertion:(NSString *)keyId clientDataHash:(NSData *)hash completionHandler:(void (^)(NSData *assertion, NSError *error))completion {
    NSLog(@"[DeviceCheck] AppAttest generateAssertion called keyId=%@", keyId);
    NSLog(@"[DeviceCheck] caller:\n%@", [NSThread callStackSymbols]);

    void (^wrapped)(NSData *, NSError *) = ^(NSData *assertion, NSError *error) {
        NSLog(@"[DeviceCheck] AppAttest generateAssertion -> assertionLen=%lu error=%@", (unsigned long)assertion.length, error);
        if (completion) completion(assertion, error);
    };

    %orig(keyId, hash, wrapped);
}
%end
