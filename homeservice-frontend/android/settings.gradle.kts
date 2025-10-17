pluginManagement {
    val flutterSdkPath =
        run {
            val propsFile = file("local.properties")
            val fromLocal =
                if (propsFile.exists()) {
                    val p = java.util.Properties().apply {
                        propsFile.inputStream().use { load(it) }
                    }
                    p.getProperty("flutter.sdk")
                } else null

            // ลำดับ fallback: local.properties -> ENV -> ค่าว่าง
            fromLocal ?: System.getenv("FLUTTER_ROOT")
            ?: System.getenv("FLUTTER_SDK")
            ?: ""
        }

    require(flutterSdkPath.isNotBlank()) {
        "Set FLUTTER_ROOT/FLUTTER_SDK env var หรือสร้าง android/local.properties ใส่ flutter.sdk=/path/to/flutter"
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
