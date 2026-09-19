import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
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
    namespace = "com.fridge.fridge_mobil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications core library desugaring gerektiriyor,
        // yoksa checkDebugAarMetadata "requires core library desugaring to
        // be enabled" hatasıyla patlar (bkz. .wolf/cerebrum.md 2026-08-20).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fridge.fridge_mobil"
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
                // --release` için debug'a düşer (bkz. aşağıdaki
                // taskGraph.whenReady — bundle/assemble görevlerinde bu
                // sessiz düşüşü engelliyor).
                signingConfigs.getByName("debug")
            }
            // R8/ProGuard açık — ML Kit'in çok dilli text recognizer
            // sınıfları (Çince/Japonca/Korece/Devanagari) daha önce "missing
            // class" hatası veriyordu (uygulama yalnızca Latin/varsayılan
            // recognizer kullanıyor, diğer dil paketleri hiç bundle
            // edilmemiş) — proguard-rules.pro'daki -dontwarn kuralları bu
            // sınıfları görmezden gelir. minify kapalıyken AAB tamamen
            // okunabilir sınıf/metot adlarıyla çıkıyordu (tersine mühendisliği
            // kolaylaştırıyordu); artık açık.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Play'e yüklenecek AAB'nin debug anahtarıyla imzalanmış olarak sessizce
// üretilmesini engeller — key.properties yoksa signingConfig yukarıda
// debug'a düşüyordu, bu da CI/yeni bir makinede `flutter build appbundle
// --release`'in görünürde başarıyla ama dağıtılamaz (ya da daha kötü,
// güvensiz) bir çıktı üretmesine izin veriyordu.
//
// Yalnızca bundleRelease (Play'e yüklenen .aab'yi üreten GERÇEK görev)
// hedeflenir — assembleRelease KASITLI OLARAK dışarıda bırakıldı: onu hem
// APK üretimi hem de `flutter run --release`'in kullandığı installRelease
// task'ı da tetikliyor (installRelease -> assembleRelease bağımlılığı),
// o yüzden assembleRelease'i de engellersek yerel `flutter run --release`
// ile test etmek key.properties olmadan kırılırdı — bu istenmiyor,
// yalnızca Play'e giden gerçek dağıtım artefaktı korunuyor.
gradle.taskGraph.whenReady {
    val requestedReleaseBundle = allTasks.any { task -> task.name == "bundleRelease" }
    if (requestedReleaseBundle && !hasReleaseSigning) {
        throw GradleException(
            "key.properties bulunamadı — Play'e yüklenecek bir release AAB " +
            "debug anahtarıyla imzalanamaz. android/key.properties.example'ı " +
            "kopyalayıp gerçek keystore bilgilerini gir.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
