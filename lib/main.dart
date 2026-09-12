import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_links/app_links.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme/app_theme.dart';
import 'core/ui/app_progress.dart';
import 'core/theme/theme_providers.dart';
import 'core/version/app_config_repository.dart';
import 'core/version/in_app_updater.dart';
import 'core/version/update_decision.dart';
import 'core/version/version_prefs.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/billing/application/entitlements_providers.dart';
import 'features/billing/application/paywall_controller.dart';
import 'features/billing/data/purchase_repository.dart';
import 'features/billing/domain/entitlements.dart';
import 'features/billing/presentation/paywall_screen.dart';
import 'features/billing/presentation/premium_intro_screen.dart';
import 'core/widgets/app_shell.dart';
import 'features/household/presentation/join_household_screen.dart';
import 'features/notification/application/notification_providers.dart';
import 'features/notification/data/push_service.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/presentation/intro_screen.dart';
import 'features/receipt/application/receipt_providers.dart';
import 'features/receipt/presentation/receipt_review_screen.dart';
import 'firebase_options.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(ref.watch(apiClientProvider));
});

final inAppUpdaterProvider = Provider<InAppUpdater>((ref) {
  return const PlayInAppUpdater();
});

// Crash reporting servisi (Sentry/Crashlytics) yok — bunlar olmadan
// production'da hiçbir hata görünürlüğü sıfırdı. Şimdilik en azından
// konsola/logcat'e düşsün diye framework ve zone hatalarını yakalıyoruz;
// bu bir crash reporting servisinin yerini tutmaz.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Android 15+ edge-to-edge'i zorunlu kılıyor (opt-out Android 16'da
      // tamamen kalkıyor); Flutter 3.27'den beri targetSdk 35 olduğunda
      // zaten opt-in oluyor ama açıkça istemek sürüm farkına bağımlı
      // kalmamayı sağlıyor. Durum çubuğu/nav bar ikon parlaklığı
      // AppBarTheme.systemOverlayStyle üzerinden temaya bağlanıyor
      // (app_theme.dart) — burada yalnız mod açılıyor.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught error: $error\n$stack');
        return true;
      };

      await dotenv.load(fileName: '.env');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      // RevenueCat platform başına AYRI API anahtarı ister: iOS = App Store
      // anahtarı (appl_...), Android = Google Play anahtarı (goog_...).
      // Anahtar boşsa (o platform için henüz kurulmadı) configure() sessizce
      // no-op yapar — boot asla çökmez, paywall kapanır.
      final revenueCatApiKey = !kIsWeb && Platform.isIOS
          ? (dotenv.env['REVENUECAT_API_KEY_IOS'] ?? '')
          : (dotenv.env['REVENUECAT_API_KEY'] ?? '');
      await PurchaseRepository.configure(apiKey: revenueCatApiKey);
      runApp(const ProviderScope(child: FridgeApp()));
    },
    (error, stack) {
      debugPrint('Zone error: $error\n$stack');
    },
  );
}

/// Bildirimden gelen yönlendirmelerin hedefi olan Navigator — push tıklaması
/// widget ağacının dışından (FCM callback'i) tetiklendiği için context yerine
/// bu global key kullanılıyor.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class FridgeApp extends ConsumerWidget {
  const FridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Elde',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // locale null: cihaz dilini takip eder, desteklenmeyen dilde tr'ye düşer
      // (supportedLocales sırası). İleride Ayarlar'dan manuel geçiş bir
      // localeProvider ile buraya bağlanabilir.
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        for (final s in supported) {
          if (s.languageCode == locale?.languageCode) return s;
        }
        return const Locale('tr');
      },
      // Boş bir yere dokununca klavyeyi kapatır — Navigator'ın üstünü
      // sardığı için tüm ekranları VE dialog/bottom sheet'leri tek noktadan
      // kapsar (her ekrana ayrı ayrı GestureDetector eklemeye gerek yok).
      // translucent + en dıştaki algılayıcı olduğu için buton/liste
      // dokunuşlarını yutmaz (gesture arena içteki algılayıcıyı önceliklendirir).
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      home: const _AuthGate(),
    );
  }
}

/// RECEIPT_PROCESSED bildirimine tıklanınca (bkz. notification-types.js)
/// doğrudan review ekranına götürür — lineItems verilmiyor, ekran kendi
/// GET /:scanId ile satırları çeker (bkz. receipt_review_screen.dart).
///
/// household_home_screen.dart'taki "Fiş hazır" banner'ının onTap'i gibi
/// dönüş değerini (true = onaylandı) dinleyip pendingReceiptScanProvider'ı
/// temizler — bu olmadan bildirimden açılıp onaylanan bir fiş, ev ekranında
/// "Fiş hazır" banner'ının asılı kalmasına yol açıyordu (regresyon).
void _handleNotificationTap(WidgetRef ref, Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final householdId = data['householdId'] as String?;
  final scanId = data['scanId'] as String?;
  if (type == 'receipt_processed' && householdId != null && scanId != null) {
    rootNavigatorKey.currentState
        ?.push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                ReceiptReviewScreen(householdId: householdId, scanId: scanId),
          ),
        )
        .then((confirmed) {
          if (confirmed == true) {
            ref.read(pendingReceiptScanProvider(householdId).notifier).clear();
          }
        });
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate>
    with WidgetsBindingObserver {
  AuthStatus? _lastStatus;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  // Giriş yapmamış kullanıcı bir davet linkine tıklarsa kod burada saklanır,
  // giriş/kayıt tamamlanınca işlenir.
  String? _pendingInviteCode;

  // Zorunlu güncelleme ekranı gösterilmesi gerekiyorsa true olur — banner
  // (yumuşak) durumu ayrıca WidgetsBinding.addPostFrameCallback ile bir kez
  // gösterilir, ekran state'ine ihtiyaç duymaz.
  bool _forceUpdateRequired = false;
  String _storeUrl = '';

  // Uygulama sadece cold start'ta değil, uzun süre açık kaldıktan sonra
  // foreground'a dönüşte de kontrol edilsin diye (bkz. kusur #1). Backend
  // cache TTL'i (6 saat) ile aynı eşik kullanılır — daha sık kontrol
  // gereksiz istek üretir.
  DateTime? _lastVersionCheck;
  static const _versionCheckInterval = Duration(hours: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    // Bir sonraki frame'e ertelenir — widget test'lerinde initState içinde
    // senkron başlatılan bir network çağrısı, test bittiğinde hâlâ bekleyen
    // bir Dio timer'ı bırakıp "Timer is still pending" hatası veriyordu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppVersion());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final last = _lastVersionCheck;
      if (last == null ||
          DateTime.now().difference(last) >= _versionCheckInterval) {
        _checkAppVersion();
      }
    }
  }

  Future<void> _checkAppVersion() async {
    _lastVersionCheck = DateTime.now();
    try {
      final config = await ref.read(appConfigRepositoryProvider).fetch();
      if (config == null) return;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final dismissed = await dismissedUpdateVersion();

      if (!mounted) return;
      final action = decideUpdate(
        currentVersion: currentVersion,
        config: config,
        dismissedVersion: dismissed,
      );

      switch (action) {
        case UpdateAction.none:
          return;
        case UpdateAction.forced:
          await _handleForcedUpdate(config.storeUrl);
        case UpdateAction.optional:
          await _handleOptionalUpdate(config.storeUrl, config.latestVersion);
      }
    } catch (_) {
      // Sürüm kontrolü best-effort — uygulama açılışını asla engellemez.
    }
  }

  /// Android + Play'den kurulu ise native immediate akışı denenir —
  /// başarısız olursa (emülatör, sideload, Play olmayan cihaz, kullanıcı
  /// reddetti) mevcut tam ekran + storeUrl akışına düşülür.
  Future<void> _handleForcedUpdate(String storeUrl) async {
    final updater = ref.read(inAppUpdaterProvider);
    if (await updater.isAvailable() && await updater.startImmediate()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _forceUpdateRequired = true;
      _storeUrl = storeUrl;
    });
  }

  /// Android + Play'den kurulu ise flexible indirme başlatılır — indirme
  /// başladıysa "Yeniden başlat" banner'ı gösterilir, aksi halde mevcut
  /// kapatılabilir banner + storeUrl akışına düşülür.
  Future<void> _handleOptionalUpdate(
    String storeUrl,
    String latestVersion,
  ) async {
    final updater = ref.read(inAppUpdaterProvider);
    if (await updater.isAvailable() && await updater.startFlexible()) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showUpdateReadyBanner(updater),
      );
      return;
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showUpdateBanner(storeUrl, latestVersion),
    );
  }

  void _showUpdateReadyBanner(InAppUpdater updater) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = AppL10n.of(context);
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(l10n.updateReadyMessage),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              updater.completeFlexible();
            },
            child: Text(l10n.updateRestartAction),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context, String storeUrl) async {
    final l10n = AppL10n.of(context);
    try {
      final launched = await launchUrl(
        Uri.parse(storeUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.storeOpenFailedMessage)));
      }
    } catch (_) {
      // storeUrl boş/bozuk olabilir (ör. iOS App Store id'si henüz
      // ayarlanmamış) — kullanıcı force-update ekranında KİLİTLİ kalmasın
      // diye burada mutlaka yakalanır (bkz. kusur #3).
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.storeOpenFailedMessage)));
      }
    }
  }

  void _showUpdateBanner(String storeUrl, String latestVersion) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = AppL10n.of(context);
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(l10n.updateAvailableMessage),
        actions: [
          TextButton(
            onPressed: () {
              // "Güncelle" artık dismiss KAYDETMİYOR (bkz. kusur #2) —
              // kullanıcı store'a gidip vazgeçerse bir sonraki açılışta
              // yeniden hatırlatılır. Sadece "Kapat" susturur.
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _openStore(context, storeUrl);
            },
            child: Text(l10n.updateAction),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setDismissedUpdateVersion(latestVersion);
            },
            child: Text(l10n.dismissAction),
          ),
        ],
      ),
    );
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleUri(initialUri);
    } catch (_) {
      // Uygulama kapalıyken gelen linki okuyamazsak sessizce devam —
      // kullanıcı yine de kodu elle girebilir.
    }
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  // https://api-fridge.emrullahbozkurt.com/join/KOD — path'in son parçası kod.
  void _handleUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments[segments.length - 2] != 'join') return;
    final code = segments.last;
    if (code.isEmpty) return;

    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.authenticated) {
      _openJoinScreen(code);
    } else {
      _pendingInviteCode = code;
    }
  }

  // Eski `_confirmJoin` tek düğmeli bir AlertDialog'du — alan adını bile
  // göstermiyordu, hatalı kodda kullanıcı en baştan başlamak zorunda
  // kalıyordu. JoinHouseholdScreen aynı akışı (FAB'dan açılanla birlikte)
  // tek ekranda topluyor: kutular dolu gelir ama OTOMATİK GÖNDERİLMEZ,
  // kullanıcı görüp "Katıl"a basar; hata olursa ekranda kalıp inline
  // düzeltebilir.
  void _openJoinScreen(String code) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => JoinHouseholdScreen(initialCode: code)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Kullanıcı ilk kez AppShell'e girdiğinde (guest ya da authenticated,
  /// tanıtım/giriş akışı bittikten sonra) bir kez PremiumIntroScreen'i push
  /// eder — bkz. onboarding_providers.dart premiumIntroSeenProvider.
  /// IntroScreen'den (henüz hesabı olmayan kullanıcı) SONRA, hesap
  /// oluştuktan hemen sonra tetiklenir; her oturum açılışında değil, sadece
  /// bayrak hiç set edilmemişse.
  Future<void> _maybeShowPremiumIntro() async {
    final seen = ref.read(premiumIntroSeenProvider);
    if (seen != false) return; // null (henüz okunmadı) veya true ise atla
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    ref.read(premiumIntroSeenProvider.notifier).markSeen();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PremiumIntroScreen(),
      ),
    );
  }

  /// Deneme bitmiş (free'ye düşmüş) kullanıcıya bir kez tam ekran paywall,
  /// ya da abonelik iptal edilip ≥7 gün geçmişse ölçülü bir win-back
  /// hatırlatması. PremiumIntroScreen'den SONRA kontrol edilir — ikisi aynı
  /// anda push edilmeye çalışılmasın diye (bkz. build() çağrı sırası).
  /// `PaywallTrigger.trialEnded`/`winBack`'in TEK gösterim yeri — enum'da
  /// tanımlıydı ama hiç çağrılmıyordu.
  Future<void> _maybeShowTrialEndedOrWinBack() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    // entitlementsProvider henüz taze veri çekmemiş olabilir (ilk açılış) —
    // Entitlements.empty ile yanlış tetikleme olmasın diye kontrollüce okur.
    final entitlementsAsync = ref.read(entitlementsControllerProvider);
    final entitlements = entitlementsAsync.value;
    if (entitlements == null) return;

    final controllerAsync = ref.read(paywallControllerProvider);
    final controller = controllerAsync.value;
    if (controller == null) return;

    // Deneme bitmiş, ücretsiz kademeye düşmüş: bir kez tam ekran paywall.
    final trialJustEnded =
        entitlements.plan == PlanTier.free &&
        entitlements.trialEndsAt != null &&
        entitlements.trialEndsAt!.isBefore(DateTime.now());
    if (trialJustEnded &&
        !controller.isFrequencyLimited(PaywallTrigger.trialEnded)) {
      controller.recordShown(PaywallTrigger.trialEnded);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const PaywallScreen(),
        ),
      );
      return;
    }

    // İptal edilmiş abonelik, dönem bitiminden ≥7 gün geçmiş: ölçülü
    // win-back banner'ı — tam ekran değil, eski aboneyi modal'la
    // karşılamak agresif olur.
    final periodEndsAt = entitlements.periodEndsAt;
    final canceledLongAgo =
        entitlements.status == 'canceled' &&
        periodEndsAt != null &&
        DateTime.now().difference(periodEndsAt) >= const Duration(days: 7);
    if (canceledLongAgo &&
        !controller.isFrequencyLimited(PaywallTrigger.winBack)) {
      controller.recordShown(PaywallTrigger.winBack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Premium özelliklerini özledin mi?'),
          action: SnackBarAction(
            label: 'Görüntüle',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const PaywallScreen(),
              ),
            ),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forceUpdateRequired) {
      final l10n = AppL10n.of(context);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  l10n.forceUpdateTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _openStore(context, _storeUrl),
                  child: Text(l10n.forceUpdateAction),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authControllerProvider);

    // Push kaydı/temizliği bir yan etki — sadece durum GEÇİŞİNDE tetiklenir
    // (her rebuild'de değil), aksi halde her ekran açılışında gereksiz
    // registerDevice/unregisterDevice çağrısı yapılırdı.
    // Misafir de (guest) bildirim alabilmeli — alan bazlı bildirimler
    // (davet, fiş işlendi) kimlik durumundan bağımsız.
    final isSignedIn =
        authState.status == AuthStatus.authenticated ||
        authState.status == AuthStatus.guest;
    final wasSignedIn =
        _lastStatus == AuthStatus.authenticated ||
        _lastStatus == AuthStatus.guest;
    if (authState.status != _lastStatus) {
      _lastStatus = authState.status;
      // _AuthGate yalnızca MaterialApp.home'u değiştirir; login/register gibi
      // push edilmiş route'lar bundan etkilenmez ve yığında asılı kalır —
      // kullanıcı arka planda giriş yapmış olsa bile login formunu görmeye
      // devam eder (aynı sorun logout'ta Ayarlar route'u için de geçerli).
      // Oturum açıklığı DEĞİŞTİĞİNDE (giriş ya da çıkış) kök navigator'ı
      // köke kadar boşaltıyoruz. guest->authenticated (hesap yükseltme) bu
      // koşula girmez — upgrade_account_screen.dart kendi pop()'unu yapar ve
      // Ayarlar yığını bilerek korunur.
      if (isSignedIn != wasSignedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
      if (isSignedIn) {
        ref
            .read(pushServiceProvider)
            .registerForCurrentUser(
              onTap: (data) => _handleNotificationTap(ref, data),
            );
        final pendingCode = _pendingInviteCode;
        if (pendingCode != null) {
          _pendingInviteCode = null;
          // popUntil ile aynı post-frame turunda çakışmasın diye bir sonraki
          // frame'e ertelenir — davet dialogu temizlenmiş yığının üstünde açılır.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _openJoinScreen(pendingCode),
            );
          });
        } else {
          // Davet dialogu yoksa aynı boş frame turunu premium tanıtımı için
          // kullan — ikisi aynı anda push edilmeye çalışılırsa çakışır, bu
          // yüzden birbirini dışlar (davet önceliklidir).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _maybeShowPremiumIntro();
              // Premium tanıtımı göstermediyse (zaten görülmüş) hemen
              // ardından deneme bitişi/win-back kontrolü yapılır — ikisi
              // aynı anda push edilmeye çalışılmasın diye sıralı.
              await _maybeShowTrialEndedOrWinBack();
            });
          });
        }
      } else if (wasSignedIn) {
        ref.read(pushServiceProvider).unregister();
      }
    }

    return switch (authState.status) {
      AuthStatus.unknown => const Scaffold(body: Center(child: AppProgress())),
      AuthStatus.unauthenticated => _resolveUnauthenticated(),
      AuthStatus.guest => const AppShell(),
      AuthStatus.authenticated => const AppShell(),
    };
  }

  /// İlk açılışta (tanıtım hiç görülmemiş) tam ekran IntroScreen; aksi
  /// halde kompakt WelcomeScreen. `seen == null` henüz SharedPreferences
  /// okunmadı demek — o kısacık an için mevcut spinner gösterilir ki
  /// yanlış ekran bir kare bile parlamasın.
  Widget _resolveUnauthenticated() {
    final seen = ref.watch(onboardingSeenProvider);
    return switch (seen) {
      null => const Scaffold(body: Center(child: AppProgress())),
      false => const IntroScreen(),
      true => const WelcomeScreen(),
    };
  }
}
