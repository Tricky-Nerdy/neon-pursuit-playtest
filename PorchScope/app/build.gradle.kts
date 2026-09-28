plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.trickynerdy.porchscope"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.trickynerdy.porchscope"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")

    // UVC webcam preview and hardware camera controls.
    implementation("com.github.jiangdongguo.AndroidUSBCamera:libausbc:3.2.7")
}
