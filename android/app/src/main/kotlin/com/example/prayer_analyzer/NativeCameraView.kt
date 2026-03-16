package com.example.prayer_analyzer

import android.content.Context
import android.view.View
import androidx.camera.core.Preview
import androidx.camera.view.PreviewView
import io.flutter.plugin.platform.PlatformView

class NativeCameraView(
    context: Context,
    id: Int,
    creationParams: Any?,
    onSurfaceProviderAvailable: (Preview.SurfaceProvider) -> Unit
) : PlatformView {
    private val previewView: PreviewView = PreviewView(context)

    init {
        // Use TextureView (COMPATIBLE) to ensure Flutter UI can overlay correctly
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        
        // Pass the surface provider back to MainActivity/CameraService
        onSurfaceProviderAvailable(previewView.surfaceProvider)
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {}
}
