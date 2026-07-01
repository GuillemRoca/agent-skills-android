---
name: security-and-hardening
description: >-
  Use when handling sensitive data, authentication, network communication,
  or before shipping to the Play Store. Three-tier framework (Always Do,
  Ask First, Never Do) with Android-specific security patterns.
---

# Security and Hardening

## Overview

Security is a development constraint, not an afterthought. This skill provides a three-tier framework — Always Do, Ask First, Never Do — covering the OWASP Mobile Top 10, Android-specific attack vectors, and hardening patterns for production apps.

## When to Use

- Handling user credentials, tokens, or personal data
- Implementing network communication
- Before shipping any release to the Play Store
- Reviewing code that touches authentication or authorization
- Setting up ProGuard/R8 rules
- Implementing WebView features

**Skip when:** Changes are purely cosmetic with no data or network impact.

## Core Process: Three-Tier Framework

### Always Do

1. **Secure data storage.** Jetpack Security Crypto (`EncryptedSharedPreferences`/`MasterKey`) is deprecated and unmaintained — do not add it to new code. Encrypt with a key held in the Android Keystore and persist the ciphertext (DataStore or a file):

```kotlin
// Key lives in the Android Keystore — never leaves secure hardware
val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
keyGenerator.init(
    KeyGenParameterSpec.Builder("auth_token_key", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .build()
)
val secretKey = keyGenerator.generateKey()

// Encrypt, then persist iv + ciphertext (e.g. in Proto DataStore)
val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, secretKey) }
val encrypted = cipher.iv + cipher.doFinal(token.toByteArray())
```

Existing apps already on `EncryptedSharedPreferences` can keep it (the format is stable), but plan a migration and never store new categories of secrets with it.

2. **Network Security Config:**

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <!-- Enforce HTTPS for all connections -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Certificate pinning for your API -->
    <domain-config>
        <domain includeSubdomains="true">api.example.com</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">base64EncodedPin=</pin>
            <!-- Backup pin -->
            <pin digest="SHA-256">base64EncodedBackupPin=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

```xml
<!-- AndroidManifest.xml -->
<application android:networkSecurityConfig="@xml/network_security_config">
```

Targeting API 37 (Android 17) also changes the network/auth surface: LAN access requires
the `ACCESS_LOCAL_NETWORK` permission, standard SMS OTPs are delayed 3 hours (use the SMS
Retriever API or SMS User Consent instead of reading raw SMS), and Encrypted Client Hello +
Certificate Transparency are on by default for TLS — verify pinning still works.

3. **Input validation:**

```kotlin
// Validate all external input
fun processDeepLink(uri: Uri): DeepLinkResult {
    val taskId = uri.getQueryParameter("taskId")
        ?: return DeepLinkResult.Invalid("Missing taskId")

    // Validate format
    if (!taskId.matches(Regex("^[a-zA-Z0-9-]{1,36}$"))) {
        return DeepLinkResult.Invalid("Invalid taskId format")
    }

    return DeepLinkResult.Valid(taskId)
}
```

4. **Intent validation for exported components:**

```kotlin
// Validate intents for exported Activities/Receivers
class TaskDeepLinkActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = intent ?: run { finish(); return }

        // Validate the source and data
        val taskId = intent.data?.getQueryParameter("taskId")
        if (taskId == null || !isValidTaskId(taskId)) {
            finish()
            return
        }
        // Process valid deep link
    }
}
```

5. **Secrets management:**

```properties
# local.properties (NEVER committed to git)
API_KEY=your_secret_key_here
```

```kotlin
// build.gradle.kts
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) load(file.inputStream())
}

android {
    defaultConfig {
        buildConfigField("String", "API_KEY",
            "\"${localProperties.getProperty("API_KEY", "")}\"")
    }
}
```

```gitignore
# .gitignore
local.properties
*.jks
*.keystore
```

6. **Remove debug code for release:**

```kotlin
// build.gradle.kts — strip Log calls in release
buildTypes {
    release {
        isMinifyEnabled = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}

// proguard-rules.pro
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}
```

### Ask First

7. **Changes that require review:**
   - Modifying authentication or authorization logic
   - Adding new exported components (Activities, Receivers, Providers)
   - Changing certificate pinning configuration
   - Adding new permissions to AndroidManifest
   - Integrating new third-party SDKs
   - Implementing WebView with JavaScript enabled
   - Modifying ProGuard/R8 rules
   - Changing data encryption or storage approach

### Never Do

8. **Absolute prohibitions:**

| Never | Why |
|-------|-----|
| Commit secrets to git | Secrets in git history are permanent, even after removal |
| Log sensitive data (`Log.d` with tokens) | Logcat is accessible to other apps on rooted devices |
| Trust client-side validation alone | All client validation can be bypassed |
| Use `MODE_WORLD_READABLE` | Any app can read your files |
| Enable `cleartext` traffic in production | Data interceptable on network |
| Store passwords in plain text | Use EncryptedSharedPreferences or Android Keystore |
| Use `WebView.setJavaScriptEnabled(true)` without sanitizing | XSS attacks via injected content |
| Export components without `android:permission` | Any app can invoke them |
| Disable certificate verification | Man-in-the-middle attacks |
| Use `FLAG_SECURE` to prevent screenshots AND log sensitive data | Inconsistent security posture |

### WebView Security

9. **If you must use WebView:**

```kotlin
webView.settings.apply {
    javaScriptEnabled = true // Only if necessary
    allowFileAccess = false
    allowContentAccess = false
    domStorageEnabled = true

    // Restrict to your domain
    setSupportMultipleWindows(false)
}

webView.webViewClient = object : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        val url = request.url
        // Only allow your trusted domains
        return url.host != "trusted.example.com"
    }
}

// Never add JavaScript interfaces that expose sensitive operations
// webView.addJavascriptInterface(dangerousObject, "Android") // DON'T
```

### OWASP Mobile Top 10 Quick Reference

| # | Risk | Android Mitigation |
|---|------|-------------------|
| M1 | Improper Credential Usage | Android Keystore, EncryptedSharedPreferences |
| M2 | Inadequate Supply Chain Security | Dependency verification, version pinning |
| M3 | Insecure Authentication | BiometricPrompt, OAuth2 with PKCE |
| M4 | Insufficient Input/Output Validation | Validate deep links, intents, API responses |
| M5 | Insecure Communication | Network Security Config, cert pinning |
| M6 | Inadequate Privacy Controls | Minimize data collection, respect permissions |
| M7 | Insufficient Binary Protections | R8/ProGuard, tamper detection |
| M8 | Security Misconfiguration | Review manifest, disable debuggable in release |
| M9 | Insecure Data Storage | EncryptedSharedPreferences, Room with encryption |
| M10 | Insufficient Cryptography | Android Keystore for key management |

## Common Rationalizations

| Shortcut | Why It Fails |
|----------|-------------|
| "It's just a debug key, I'll change it later" | Debug keys committed to git stay in history forever. |
| "Our API already validates input" | Client validation improves UX; server validation prevents exploits. Both needed. |
| "We don't need cert pinning for v1" | v1 is when MITM attacks are most damaging — no monitoring to detect them. |
| "ProGuard breaks too many things" | Configure it properly with `@Keep` annotations. The security cost of skipping is higher. |

## Red Flags

- Secrets (API keys, tokens) in source code
- `android:debuggable="true"` in release manifest
- `clearTextTrafficPermitted="true"` in production
- No Network Security Config
- `Log.d` with user data or tokens
- `MODE_WORLD_READABLE` or `MODE_WORLD_WRITEABLE`
- Exported components without permission checks
- WebView with unrestricted JavaScript
- No ProGuard/R8 in release builds
- Disabled certificate verification

## Verification

- [ ] No secrets in source code (grep for API keys, tokens, passwords)
- [ ] Network Security Config present and enforces HTTPS
- [ ] Certificate pinning for production API
- [ ] EncryptedSharedPreferences for sensitive data
- [ ] Input validated at all system boundaries
- [ ] Exported components have permission checks
- [ ] ProGuard/R8 enabled for release builds
- [ ] Debug logging stripped in release (ProGuard rules)
- [ ] `local.properties` in `.gitignore`
- [ ] `android:debuggable` not set (defaults to false for release)
- [ ] WebView (if used) restricts domains and JavaScript exposure
