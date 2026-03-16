package com.example.prayer_analyzer

import android.content.Context
import androidx.camera.core.Preview
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeViewFactory(private val onSurfaceProviderAvailable: (Preview.SurfaceProvider) -> Unit) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeCameraView(context, viewId, args, onSurfaceProviderAvailable)
    }
}
