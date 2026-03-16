package com.example.prayer_analyzer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.gpu.CompatibilityList
import org.tensorflow.lite.gpu.GpuDelegate
import org.tensorflow.lite.nnapi.NnApiDelegate
import org.tensorflow.lite.support.common.FileUtil
import org.tensorflow.lite.support.image.ImageProcessor
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.support.image.ops.ResizeOp
import org.tensorflow.lite.support.image.ops.Rot90Op
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

data class PostureResult(
    val label: String,
    val confidence: Float,
    val inferenceTime: Long
)

class PrayerAnalyzer(private val context: Context) {

    private var interpreter: Interpreter? = null
    private var inputImageBuffer: TensorImage? = null
    // Flutter assets are stored in this path within the Android assets
    private val modelPath = "flutter_assets/assets/models/best_int8.tflite"
    private val labels = PrayerConfig.CLASSES

    fun init() {
        if (interpreter != null) return

        val options = Interpreter.Options()

        // Simplify delegate selection to avoid CompatibilityList/Options issues
        try {
            options.addDelegate(GpuDelegate())
            Log.d("PrayerAnalyzer", "Using GPU Delegate")
        } catch (e: Throwable) {
            Log.w("PrayerAnalyzer", "GPU Delegate failed, falling back to CPU", e)
            // Skip NNAPI as it can be unstable on some devices. 
            // Default CPU (XNNPack) is safer.
        }
        
        options.setNumThreads(4)

        try {
            // Load model from assets
            val modelFile = FileUtil.loadMappedFile(context, modelPath)
            interpreter = Interpreter(modelFile, options)
            Log.d("PrayerAnalyzer", "Interpreter initialized")
            
            val imageDataType = interpreter!!.getInputTensor(0).dataType()
            inputImageBuffer = TensorImage(imageDataType)
            
        } catch (e: Throwable) {
            Log.e("PrayerAnalyzer", "Error initializing TFLite Interpreter", e)
            interpreter = null
        }
    }

    fun analyze(bitmap: Bitmap, rotation: Int): PostureResult? {
        if (interpreter == null) init()
        if (interpreter == null || inputImageBuffer == null) return null

        val startTime = SystemClock.uptimeMillis()

        val inputTensor = interpreter!!.getInputTensor(0)
        val inputShape = inputTensor.shape() // [1, 640, 640, 3] usually
        val height = inputShape[1]
        val width = inputShape[2]
        val dataType = inputTensor.dataType()

        // 1. Preprocess
        val imageProcessorBuilder = ImageProcessor.Builder()
            .add(ResizeOp(height, width, ResizeOp.ResizeMethod.BILINEAR))
            // .add(Rot90Op(-rotation / 90)) // Handled by caller or ignored if Bitmap is already upright
            
        // If model expects Float between 0 and 1, we must normalize.
        // TensorImage loads Bitmap (0-255).
        if (dataType == org.tensorflow.lite.DataType.FLOAT32) {
             imageProcessorBuilder.add(org.tensorflow.lite.support.common.ops.NormalizeOp(0f, 255f))
        }

        val imageProcessor = imageProcessorBuilder.build()
            
        inputImageBuffer!!.load(bitmap)
        val processedImage = imageProcessor.process(inputImageBuffer)

        // 2. Run Inference
        val outputTensor = interpreter!!.getOutputTensor(0)
        val outputShape = outputTensor.shape() // Expected: [1, 8, 8400]
        
        // Check standard YOLOv8 output shape [1, 84, 8400] or [1, 8, 8400]
        // 4 coords + 4 classes = 8 channels
        // Anchors = 8400
        
        // Allocate buffer
        val outputBuffer = ByteBuffer.allocateDirect(outputTensor.numBytes())
        outputBuffer.order(ByteOrder.nativeOrder())
        
        interpreter!!.run(processedImage.buffer, outputBuffer)

        // 3. Post-process (YOLOv8 parsing)
        outputBuffer.rewind()
        
        // Read as FloatBuffer for easier access
        val floatBuffer = outputBuffer.asFloatBuffer()
        
        // Shape [1, 8, 8400]
        // Flattened: [row0..row7] where each row has 8400 elements.
        // We care about rows 4, 5, 6, 7 (class scores for the 4 classes).
        // Index mapping: value at [0, c, i] -> floatBuffer[c * 8400 + i]
        
        val numClasses = 4
        val numAnchors = 8400
        val channels = 4 + numClasses // 8
        
        // Verify shape matches assumptions roughly
        if (outputShape[1] != channels || outputShape[2] != numAnchors) {
             // If transposed [1, 8400, 8], adjust logic.
             // But Dart code says [8, 8400].
             // Safety check:
             val totalElements = floatBuffer.remaining()
             if (totalElements < channels * numAnchors) {
                  return PostureResult("Error: Shape mismatch", 0f, 0)
             }
        }

        var maxScore = 0.0f
        var bestClassIndex = -1
        
        // Loop through all anchors
        for (i in 0 until numAnchors) {
            // Check confidence for each class
            for (c in 0 until numClasses) {
                // Class scores start at channel 4
                val channelIndex = 4 + c
                val score = floatBuffer.get(channelIndex * numAnchors + i)
                
                if (score > maxScore) {
                    maxScore = score
                    bestClassIndex = c
                }
            }
        }

        val inferenceTime = SystemClock.uptimeMillis() - startTime
        
        val label = if (bestClassIndex != -1 && maxScore > 0.5f) {
            labels.getOrElse(bestClassIndex) { "Unknown" }
        } else {
            "Unknown"
        }

        return PostureResult(label, maxScore, inferenceTime)
    }

    fun analyzeImage(path: String): PostureResult? {
        if (interpreter == null) init() // Ensure initialized
        
        val bitmap = BitmapFactory.decodeFile(path) ?: return null
        
        // Handle rotation if needed (exif), but for now assume upright or handle in analyze
        // Ideally we read EXIF, but for simplicity assuming correct orientation or letting model handle it
        
        return analyze(bitmap, 0)
    }

    fun close() {
        interpreter?.close()
        interpreter = null
    }
}
