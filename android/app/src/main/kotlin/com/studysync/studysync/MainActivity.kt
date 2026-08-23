package com.studysync.studysync

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Extends FlutterFragmentActivity rather than FlutterActivity because
 * local_auth shows BiometricPrompt, which requires a FragmentActivity host.
 */
class MainActivity : FlutterFragmentActivity()
