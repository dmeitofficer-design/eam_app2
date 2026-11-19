# ML Kit text recognition (OCR scan) references the optional Chinese,
# Devanagari, Japanese and Korean models. The app only bundles Latin, so
# let R8 ignore the missing classes instead of failing the release build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
