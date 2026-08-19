import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play Store'a yüklenecek release build debug keystore ile imzalanamaz.
// key.properties yoksa (henüz keystore üretilmediyse) debug'a düşer, böylece
// `flutter run --release` kırılmadan çalışmaya devam eder — key.properties
// oluşturulunca otomatik olarak release keystore'a geçer.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.fridge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fridge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // key.properties henüz yok — Play'e yüklenecek bir AAB bu
                // haliyle asla üretilmemeli, sadece yerel `flutter run
                // --release` için debug'a düşer.
                signingConfigs.getByName("debug")
            }
            // ML Kit'in çok dilli text recognizer sınıfları (Çince/Japonca/
            // Korece/Devanagari) R8 ile "missing class" hatası veriyordu —
            // uygulama sadece Latin/varsayılan recognizer'ı kullanıyor,
            // bu diğer dil paketleri hiç bundle edilmemiş. minify kapalı
            // kalınca R8 bu sınıfları analiz etmeye çalışmıyor, sorun ortadan
            // kalkıyor. Bedel: AAB biraz daha büyük ve obfuscate değil —
            // ilk yayın için kabul edilebilir bir takas.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
