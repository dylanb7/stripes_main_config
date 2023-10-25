import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stripes_backend_helper/repo_package.dart';
import 'package:stripes_main_config/platform_helper.dart';

import 'package:stripes_main_config/repos/mobile_repos/configure_amplify.dart';
import 'package:stripes_main_config/repos/mobile_repos/repo_package.dart';
import 'package:stripes_main_config/repos/web_repos/configure_amplify.dart';
import 'package:stripes_main_config/repos/web_repos/repo_package.dart';
import 'package:stripes_ui/entry.dart';

import 'package:amplify_authenticator/amplify_authenticator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || !PlatformInfo().isAppOS()) {
    await configureAmplifyWeb();
  } else {
    await configureAmplifyMobile();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final StripesRepoPackage package = kIsWeb || !PlatformInfo().isAppOS()
        ? WebRepoPackage()
        : MobileRepoPackage();
    return Authenticator(
        initialStep: AuthenticatorStep.onboarding,
        child: StripesApp(
          hasGraphing: false,
          builder: Authenticator.builder(),
          strat: AuthStrat.accessCodeEmail,
          repos: package,
        ));
  }
}
