import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app_links/app_links.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/error/api_error.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';
import 'core/version/app_config_repository.dart';
import 'core/version/version_prefs.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/billing/data/purchase_repository.dart';
import 'features/billing/presentation/premium_intro_screen.dart';
import 'core/widgets/app_shell.dart';
import 'features/household/application/household_providers.dart';
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

// Crash reporting servisi (Sentry/Crashlytics) yok — bunlar olmadan
// production'da hiçbir hata görünürlüğü sıfırdı. Şimdilik en azından
// konsola/logcat'e düşsün diye framework ve zone hatalarını yakalıyoruz;
// bu bir crash reporting servisinin yerini tutmaz.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

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
      // Anahtar boşsa (henüz RevenueCat hesabı kurulmadı) sessizce no-op —
      // configure() kendi içinde kontrol ediyor, boot asla çökmez.
      await PurchaseRepository.configure(apiKey: dotenv.env['REVENUECAT_API_KEY'] ?? '');
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
      title: 'Fridge',
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

class _AuthGateState extends ConsumerState<_AuthGate> {
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

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    // Bir sonraki frame'e ertelenir — widget test'lerinde initState içinde
    // senkron başlatılan bir network çağrısı, test bittiğinde hâlâ bekleyen
    // bir Dio timer'ı bırakıp "Timer is still pending" hatası veriyordu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAppVersion());
  }

  Future<void> _checkAppVersion() async {
    try {
      final config = await ref.read(appConfigRepositoryProvider).fetch();
      if (config == null) return;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!mounted) return;
      if (compareVersions(currentVersion, config.minSupportedVersion) < 0) {
        setState(() {
          _forceUpdateRequired = true;
          _storeUrl = config.storeUrl;
        });
      } else if (compareVersions(currentVersion, config.latestVersion) < 0) {
        final dismissed = await dismissedUpdateVersion();
        if (dismissed == config.latestVersion) return;
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showUpdateBanner(config.storeUrl, config.latestVersion),
        );
      }
    } catch (_) {
      // Sürüm kontrolü best-effort — uygulama açılışını asla engellemez.
    }
  }

  void _showUpdateBanner(String storeUrl, String latestVersion) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: const Text('Fridge\'in yeni bir sürümü mevcut.'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setDismissedUpdateVersion(latestVersion);
              launchUrl(
                Uri.parse(storeUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Güncelle'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setDismissedUpdateVersion(latestVersion);
            },
            child: const Text('Kapat'),
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
      _confirmJoin(code);
    } else {
      _pendingInviteCode = code;
    }
  }

  Future<void> _confirmJoin(String code) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alana katıl'),
        content: const Text(
          'Bu davet linkiyle bir alana katılmak üzeresin. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ProviderScope.containerOf(
        context,
      ).read(householdRepositoryProvider).acceptInvite(code);
      ProviderScope.containerOf(context).invalidate(householdsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alana katıldın')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  void dispose() {
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
      MaterialPageRoute(builder: (_) => const PremiumIntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_forceUpdateRequired) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_rounded, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Fridge\'i kullanmaya devam etmek için güncellemen gerekiyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(_storeUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Şimdi güncelle'),
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
              (_) => _confirmJoin(pendingCode),
            );
          });
        } else {
          // Davet dialogu yoksa aynı boş frame turunu premium tanıtımı için
          // kullan — ikisi aynı anda push edilmeye çalışılırsa çakışır, bu
          // yüzden birbirini dışlar (davet önceliklidir).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowPremiumIntro());
          });
        }
      } else if (wasSignedIn) {
        ref.read(pushServiceProvider).unregister();
      }
    }

    return switch (authState.status) {
      AuthStatus.unknown => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
      false => const IntroScreen(),
      true => const WelcomeScreen(),
    };
  }
}
