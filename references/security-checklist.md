# Security Checklist — Android Reference

## Data Storage

- [ ] **Sensitive data** encrypted with Android Keystore-held keys (ciphertext in DataStore or files). Jetpack Security Crypto (`EncryptedSharedPreferences`/`MasterKey`) is deprecated and unmaintained — existing usage may remain with a migration plan; no new usage
- [ ] **No plain-text passwords** — use secure hashing or token-based auth
- [ ] **No `MODE_WORLD_READABLE`** or `MODE_WORLD_WRITEABLE`
- [ ] **Room database** not in external storage (default internal is correct)
- [ ] **Backup rules** configured — exclude sensitive data from auto-backup:

```xml
<!-- res/xml/backup_rules.xml -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="secure_prefs.xml"/>
        <exclude domain="database" path="sensitive.db"/>
    </cloud-backup>
</data-extraction-rules>
```

## Network Security

- [ ] **Network Security Config** present in `res/xml/network_security_config.xml`
- [ ] **Cleartext traffic disabled** (`cleartextTrafficPermitted="false"`)
- [ ] **Certificate pinning** for production API endpoints
- [ ] **Backup pins** configured (in case primary pin rotates)
- [ ] **Pin expiration** set with rotation plan
- [ ] **No disabled certificate verification** (no custom `TrustManager` that accepts all certs)
- [ ] **API 37 network changes handled** — `ACCESS_LOCAL_NETWORK` permission declared if the app reaches LAN devices; cert pinning verified against default-on Encrypted Client Hello + Certificate Transparency
- [ ] **OTP via SMS Retriever / SMS User Consent** (standard SMS OTPs are delayed 3 hours on API 37)

## Authentication & Authorization

- [ ] **OAuth2 with PKCE** for third-party auth (no implicit grant)
- [ ] **BiometricPrompt** for sensitive operations:

```kotlin
val biometricPrompt = BiometricPrompt(activity, executor,
    object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: AuthenticationResult) {
            // Proceed with sensitive operation
        }
    }
)
biometricPrompt.authenticate(promptInfo)
```

- [ ] **Session tokens** refreshed regularly, stored encrypted with a Keystore-held key
- [ ] **Token expiration** handled gracefully (redirect to login)

## Input Validation

- [ ] **Deep links** validated (scheme, host, path, parameters)
- [ ] **Intent extras** validated for exported components
- [ ] **User input** sanitized before Room queries (use parameterized queries)
- [ ] **File paths** validated to prevent path traversal
- [ ] **Content URIs** validated before processing

## Exported Components

- [ ] **Minimize exported components** — only export what's necessary
- [ ] **Permission-protect** exported Activities, Services, Receivers:

```xml
<activity
    android:name=".DeepLinkActivity"
    android:exported="true"
    android:permission="com.example.DEEP_LINK">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="example" android:host="task" />
    </intent-filter>
</activity>
```

- [ ] **Content Providers** restricted with `readPermission` / `writePermission`
- [ ] **No implicit broadcasts** for sensitive data

## Secrets Management

- [ ] **API keys** in `local.properties` (gitignored), accessed via `BuildConfig`
- [ ] **Signing keystore** NOT in repository
- [ ] **CI secrets** in GitHub Secrets or equivalent vault
- [ ] **No hardcoded secrets** in source code (grep for patterns):

```bash
grep -rn "api_key\|apiKey\|secret\|password\|token" \
    --include="*.kt" --include="*.xml" --include="*.properties" \
    | grep -v "local.properties" | grep -v "test" | grep -v "build/"
```

## ProGuard / R8

- [ ] **R8 enabled** for release builds (`isMinifyEnabled = true`)
- [ ] **Resource shrinking** enabled (`isShrinkResources = true`)
- [ ] **Debug logs stripped** in release:

```proguard
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
```

- [ ] **Keep rules** for serialized classes (Room entities, API models):

```proguard
-keep class com.example.data.model.** { *; }
```

- [ ] **Mapping file** uploaded to Play Console for crash deobfuscation

## WebView Security

- [ ] **JavaScript** disabled unless required
- [ ] **File access** disabled (`allowFileAccess = false`)
- [ ] **URL validation** in `shouldOverrideUrlLoading` — whitelist trusted domains
- [ ] **No `addJavascriptInterface`** exposing sensitive operations
- [ ] **Content loaded via HTTPS** only

## Dependency Management

- [ ] **Dependency verification** enabled in `gradle/verification-metadata.xml`
- [ ] **Version pinning** — no dynamic versions (`implementation("lib:+")`)
- [ ] **Vulnerability scanning** in CI (OWASP dependency-check or similar)
- [ ] **Unused dependencies** removed regularly
- [ ] **License compliance** verified for all dependencies

## Release Configuration

- [ ] **`android:debuggable`** not set in release (defaults to false)
- [ ] **`android:allowBackup`** reviewed — sensitive data excluded
- [ ] **StrictMode** disabled in release builds
- [ ] **Test code** not shipped in release (no test dependencies in `implementation`)
