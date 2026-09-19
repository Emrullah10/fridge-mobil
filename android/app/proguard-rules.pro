# R8 daha önce (isMinifyEnabled=false iken) hiç devreye girmiyordu — bkz.
# build.gradle.kts. Uygulama google_mlkit_text_recognition'ın yalnızca
# Latin/varsayılan recognizer'ını kullanıyor; Çince/Japonca/Korece/
# Devanagari recognizer sınıfları hiç bundle edilmemiş (pubspec.yaml'da
# yalnızca temel paket var), bu yüzden R8 onları classpath'te bulamayıp
# "missing class" hatası veriyordu. -dontwarn bu sınıfları görmezden
# gelmesini söyler — kod onlara gerçekten dokunmadığı için güvenli.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Firebase Messaging / Firestore genellikle reflection ile model sınıflarına
# erişir — flutter_local_notifications ve firebase_messaging paketleri
# kendi consumer proguard kurallarını getiriyor (aar içine gömülü), ama
# bazı sürümlerde eksik kalabiliyor. Uygulama crash ederse ilk bakılacak
# yer burası.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
