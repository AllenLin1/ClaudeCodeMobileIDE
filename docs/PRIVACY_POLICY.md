# Privacy Policy for CodePilot

Last updated: April 2026

## Overview

CodePilot is a mobile client for remotely controlling Claude Code on your computer. We are committed to protecting your privacy.

## Data Collection

**We do not collect any personal data.**

CodePilot uses end-to-end encryption for all communication between your iPhone and your computer. The relay server only processes encrypted blobs and cannot read your code, conversations, or any other content.

## What Data Stays on Your Device

- Encryption keys (stored in iOS Keychain)
- Session history (stored in SwiftData, local only)
- Pairing information (stored locally)
- App preferences (stored in UserDefaults)

## What Data Passes Through Our Servers

- Encrypted message blobs (unreadable by the server)
- Subscription status (managed by RevenueCat)
- JWT authentication tokens (contain only a hashed user ID and subscription tier)

## Third-Party Services

- **RevenueCat**: Manages App Store subscriptions. See their privacy policy at https://www.revenuecat.com/privacy
- **Cloudflare**: Hosts our relay infrastructure. See their privacy policy at https://www.cloudflare.com/privacypolicy/
- **Apple**: App Store, StoreKit, APNs. See Apple's privacy policy.

## Data Retention

We do not retain any user data on our servers beyond what is necessary for the relay to function (temporary message buffering for offline delivery, automatically deleted after delivery).

Subscription records in our licensing server contain only:
- A hashed user identifier
- Subscription tier (free/pro)
- Free tier usage count

## Your Rights

Since we don't collect personal data, there is nothing to delete. You can uninstall the app at any time to remove all local data.

## Contact

For privacy questions, contact: privacy@codepilot.dev
