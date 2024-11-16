import 'dart:async';
import 'package:bonfire_multiplayer/pages/home/home_page.dart';
import 'package:bonfire_multiplayer/pages/home/home_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webauthn/webauthn.dart';
import '../../extensions/extensions.dart';
import '../../utils/ui/show_toast.dart';
import '../../utils/validate_util.dart';
import '../../utils/ui/autocomplete.dart' as ac;
import 'account_controller.dart';
import 'credential_dialog.dart';


class LoginPage extends StatefulWidget {
  static const String routeName = "/login";

  @override
  State<StatefulWidget> createState() {
    return _LoginPageState();
  }

}

class _LoginPageState extends State<LoginPage> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _emailFormKey = GlobalKey<FormState>();
  final _pinCodeFormKey = GlobalKey<FormState>();

  TextEditingController _emailCtrl = TextEditingController(text: "");
  StreamController<ErrorAnimationType> _errorCtrl = StreamController<ErrorAnimationType>();
  TextEditingController _pinCodeCtrl = TextEditingController(text: !kDebugMode ? "111111" : "");

  bool _pinCodeVisible = !kDebugMode;

  String? _validatePinCode(String? v) {
    if (v == null || v.length < 6) {
      return "complete_pin_code".tr;
    } else {
      return null;
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'mailHintError'.tr;
    }
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    RegExp regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      return 'mailHintError'.tr;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() {
      if(mounted && !isNotNull(_emailCtrl.text)) setState(() {
        _pinCodeVisible = false;
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    // _pinCodeCtrl.dispose();
    _errorCtrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final List<String> _kOptions = <String>[
      ...Get.find<SharedPreferences>().getAccounts ,
      //'apsolutelyfree@casemails.com',
    ];

    // if(_emailCtrl.text.isEmpty) {
    //   _emailCtrl.text = _kOptions.first;
    // }

    final decoration = InputDecoration(
      hintText: "mailHint".tr,
      hintStyle: TextStyle(color: Colors.white.withOpacity(.5)),
      border: OutlineInputBorder()
    );

    final textStyle = TextStyle(color: Colors.white);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      key: _scaffoldKey,
      // appBar: AppBar(title: Text("login".tr, style: Theme.of(context).textTheme.titleMedium)),
      body: Container(
          width: Size.infinite.width,
          height: Size.infinite.height,
          decoration: BoxDecoration(image: DecorationImage(opacity: .2, filterQuality: FilterQuality.low, image: AssetImage("assets/images/background.png"), fit: BoxFit.cover)),
          child: Column(children: [
          Row(children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: "Welcome",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white,fontSize: 44)),
              TextSpan(text: "\nto Zu.Coffee",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 24))
            ]), textAlign: TextAlign.start)
          ]).marginOnly(top: kToolbarHeight, bottom: 24),
          Form(key: _emailFormKey, child: ac.Autocomplete<String>(
            optionsMaxWidth: MediaQuery.of(context).size.width - 48,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return _kOptions.where((String option) {
                return option.contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              setState(() {
                _emailCtrl.text = selection;
              });

            },
            initialValue: TextEditingValue(text: _kOptions.isNotEmpty ? _kOptions.first : ""),
            fieldViewBuilder: (BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted) {
              if(_emailCtrl.text.isEmpty) {
                _emailCtrl.text = fieldTextEditingController.text;
              }
              return TextFormField(
                focusNode: fieldFocusNode,
                onFieldSubmitted: (v) {
                  onFieldSubmitted.call();
                },
                onChanged: (v) {
                  _emailCtrl.text = v;
                },
                controller: fieldTextEditingController,
                style: textStyle, decoration: decoration,
                validator: _validateEmail,
                onSaved: (value) {
                  _emailCtrl.text = value ?? '';
                },
              );
            },
          )),
          if(_pinCodeVisible)Form(key: _pinCodeFormKey, child: TextFormField(controller: _pinCodeCtrl, style: textStyle, decoration: decoration.copyWith(hintText: "captureHint".tr)).marginOnly(top: 24)),
          CupertinoButton.filled(onPressed: () {
            FocusScope.of(context).requestFocus(FocusNode());
            _register();
          }, child: Text("register".tr)).marginOnly(top: 50),
          CupertinoButton(child: Text("haveExistsAccount".tr), onPressed: () {
            FocusScope.of(context).requestFocus(FocusNode());
            _login();
          }),
          Spacer(),
          Text("Fall in Love with Coffee in Blissful Delight!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 30)).marginOnly(bottom: 20),
          SizedBox(height: context.width * .1)
          // TextButton(onPressed: (){}, child: Center(child: Text("还有没有账号，去注册")))
        ]).marginSymmetric(horizontal: 24)),
    );
  }

  Future<Credential?> showDialog(List<Credential> credentials){
    return Get.dialog<Credential>(CredentialDialog(credentials: credentials));
  }

  _register() async{
    try {
      showLoading();
      final controller = Get.find<AccountController>();
      if(_pinCodeVisible) {
        if(_pinCodeFormKey.currentState!.validate() && _emailFormKey.currentState!.validate()) {
          final res = await controller.register(_emailCtrl.text, captcha: _pinCodeCtrl.text);
          if(res.success) {
            Get.offAllNamed(HomePage.routeName);
          } else {
            _snackMessage(res.msg);
          }
        }
      } else {
        if (_emailFormKey.currentState!.validate()) {

          final res = await controller.prepare(_emailCtrl.text);
          if(res.success) {
            toast("codeSent".tr);
            if(mounted) {
              setState(() {
                _pinCodeVisible = true;
              });
            }
            // ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
            //   SnackBar(
            //     content: Text('Login successfully!'),
            //     duration: Duration(seconds: 2),
            //   ),
            // );
            // Get.find<SharedPreferences>().token = "token_${_emailCtrl.text}";
            // Get.offAllNamed(MainPage.routeName);
          } else {
            _snackMessage(res.msg);
          }
        }
      }
    } catch(e) {
      if(e is GetAssertionException) {

      } else {
        _snackMessage(e.toString());
      }
    } finally {
      closeLoading();
    }
  }

//larisaslonik@kongtoan.com
  _login() async{
    try {
      final controller = Get.find<AccountController>();
      final res = await controller.login(factory: showDialog);
      if(res.success) {
        Get.offAllNamed(HomePage.routeName);
      } else {
        _snackMessage(res.msg);
      }
    } catch(e) {
      if(e.toString().contains("cause user canceled")) {
        return;
      }
      _snackMessage(e.toString());
    } finally {
      closeLoading();
    }
  }

  _snackMessage(String message) {
    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text('Error: ${message}'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}