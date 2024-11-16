import 'package:bonfire_multiplayer/data/game_event_manager.dart';
import 'package:bonfire_multiplayer/data/websocket/polo_websocket.dart';
import 'package:bonfire_multiplayer/data/websocket/websocket_provider.dart';
import 'package:bonfire_multiplayer/event/battle_event.dart';
import 'package:bonfire_multiplayer/pages/game/game_route.dart';
import 'package:bonfire_multiplayer/pages/home/bloc/home_bloc.dart';
import 'package:bonfire_multiplayer/pages/home/home_page.dart';
import 'package:bonfire_multiplayer/pages/home/home_route.dart';
import 'package:bonfire_multiplayer/util/my_page_transition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chain/pages/account/account_controller.dart';
import 'chain/routes/routes.dart';
import 'chain/theme/theme_model.dart';
import 'chain/translations/translations.dart';
import 'chain/utils/log/lk_log_output.dart';

// String address = '192.168.0.12';
String address = '192.168.31.247';
// String address = '10.0.2.2';
var logger = Logger(
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    printer: PrettyPrinter(),
    output: LKLogOutPut()
);

var loggerNST = Logger(
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    printer: PrettyPrinter(methodCount: 0),
    output: LKLogOutPut()
);

void main() async{
  await ScreenUtil.ensureScreenSize();
  await Get.putAsync<SharedPreferences>(() async {
    return await SharedPreferences.getInstance();
  }, permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, __) => MultiProvider(
          providers: [
            Provider<WebsocketProvider>(
              create: (context) => PoloWebsocket(address: address),
            ),
            Provider(
              create: (context) => GameEventManager(websocket: context.read()),
            ),
            BlocProvider(create: (context) => HomeBloc(context.read())),
            BlocProvider(create: (context) => BattleLogBloc())
          ],
          child: GetMaterialApp(
            title: 'Arcadia',
            initialBinding: BindingsBuilder(() async{
              Get.put(ThemeController());
              Get.put(AccountController());
            }),
            navigatorKey: Get.key,
            navigatorObservers: [GetObserver()],
            getPages: routes,
            initialRoute: HomePage.routeName,
            themeMode: ThemeMode.system,
            builder: EasyLoading.init(builder: (ctx, child){
              EasyLoading.instance.indicatorType = EasyLoadingIndicatorType.ring;
              return GestureDetector(
                  onTap: () {
                    FocusScopeNode focus = FocusScope.of(context);
                    if (!focus.hasPrimaryFocus &&
                        focus.focusedChild != null) {
                      FocusManager.instance.primaryFocus!.unfocus();
                    }
                  },
                  child: MediaQuery(
                    //Setting font does not change with system font size
                    data: MediaQuery.of(ctx).copyWith(textScaleFactor: 1.0),
                    child: child!,
                  ));
            }),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            translations: AppTranslations(),
            supportedLocales: AppTranslations.supportedLocales,
            locale: AppTranslations.locale ?? Get.deviceLocale,//const Locale('zh', 'CN'),
            fallbackLocale: AppTranslations.fallbackLocale,
          ),
        ));
  }
}
