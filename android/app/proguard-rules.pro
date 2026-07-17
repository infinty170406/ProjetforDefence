# Proguard/R8 rules for suppression of TensorFlow Lite missing class warnings
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
