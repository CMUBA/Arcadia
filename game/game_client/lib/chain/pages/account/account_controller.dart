import 'dart:async';
import 'package:bonfire_multiplayer/chain/api/air_account_api_ext.dart';
import 'package:bonfire_multiplayer/chain/extensions/extensions.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webauthn/webauthn.dart';
import '../../../main.dart';
import '../../api/api.dart';
import '../../api/generic_response.dart';
import '../../api/requests/chain_request.dart';
import '../../api/requests/prepare_request.dart';
import '../../api/requests/reg_request.dart';
import '../../api/requests/sign_request.dart';
import '../../api/response/reg_response.dart';
import '../../config/tx_configs.dart';
import '../../utils/validate_util.dart';
import '../../zero/example/airAccount/erc20_transfer.dart';
import 'models/account_info.dart';

const _ORIGIN_DOMAIN = "https://airaccount.aastar.io";
const _network = "optimism-sepolia";

const ORIGIN_DOMAIN = _ORIGIN_DOMAIN;

class AccountController extends GetxController with StateMixin<AccountInfo> {

  final _usdtTokenAbiPath = "assets/contracts/TetherToken.json";
  final _nftTokenAbiPath = "assets/contracts/AAStarDemoNFT.json";

  Future<AccountInfo?> getAccountInfo() async {
    final resp = await Api().getAccountInfo(_network);
    if (resp.success) {
      final account = AccountInfo.fromJson(resp.data!.toJson());
      change(account, status: RxStatus.success());
      update();
      Get.find<SharedPreferences>().localAccounts = account?.email ?? '';
      await runZonedGuarded(() async{
        final rpcUrl = op_sepolia.rpc;
        final usdtContractAddress = op_sepolia.contracts.usdt;
        final nftContractAddress = op_sepolia.contracts.nft;
        final usdtBalance = await getBalance(rpcUrl, usdtContractAddress, _usdtTokenAbiPath, account.aa!);
        final nftBalance = await getBalance(rpcUrl, nftContractAddress, _nftTokenAbiPath, account.aa!, decimals: false);
        account.usdtBalance = usdtBalance;
        account.nftBalance = nftBalance;
        change(account, status: RxStatus.success());
        update();
      }, (e, s) {
        logger.e("getAccountInfo", error: e, stackTrace: s);
      });
    } else if(resp.code == 404) {
      var res = await this.createWallet(ChainRequest(network: _network));
      if(res.success) {
        await getAccountInfo();
      }
    }
    return null;
  }

  mintUsdtAndMintNft() async{
    final balances = await mintUsdtAndNFT(state!.aa!,
        "_mint", _usdtTokenAbiPath,
        "mint", _nftTokenAbiPath, state!.initCode!, ORIGIN_DOMAIN, _network, amount: 5);
    if(balances.isNotEmpty){
      change(state?..usdtBalance = balances.first..nftBalance = balances.last, status: RxStatus.success());
    }
  }

  mintNft() async{
    final contractAddress = op_sepolia.contracts.nft;
    final bundlerUrl = op_sepolia.bundler.first.url;
    final rpcUrl = op_sepolia.rpc;
    final paymasterUrl = op_sepolia.paymaster.first.url;
    final paymasterParams = op_sepolia.paymaster.first.option?.toJson();

    final balance = await mint(contractAddress, bundlerUrl, rpcUrl, paymasterUrl, paymasterParams ?? {}, state!.aa!, "mint", _nftTokenAbiPath, state!.initCode!, ORIGIN_DOMAIN, _network, amount: 5, decimals: false);
    change(state?..nftBalance = balance, status: RxStatus.success());
  }

  Future<String?> mintUsdt() async{
   final contractAddress = op_sepolia.contracts.usdt;
   final bundlerUrl = op_sepolia.bundler.first.url;
   final rpcUrl = op_sepolia.rpc;
   final paymasterUrl = op_sepolia.paymaster.first.url;
   final paymasterParams = op_sepolia.paymaster.first.option?.toJson();

   final balance = await mint(contractAddress, bundlerUrl, rpcUrl, paymasterUrl, paymasterParams ?? {}, state!.aa!, "_mint", _usdtTokenAbiPath, state!.initCode!, ORIGIN_DOMAIN, _network, amount: 5);
   change(state?..usdtBalance = balance, status: RxStatus.success());
   return balance;
  }

  Future<String?> sendUsdt({String? receiver, num? amount}) async{
    final rcv0 = "0xdC581f4b51a3EC314712F0fBa93Ee3081B57e1Db";
    final rev1 = "0x046Bd46B76c6Bd648719C988Fa2a839126a68a0F";

    final contractAddress = op_sepolia.contracts.usdt;
    final bundlerUrl = op_sepolia.bundler.first.url;
    final rpcUrl = op_sepolia.rpc;
    final paymasterUrl = op_sepolia.paymaster.first.url;
    final paymasterParams = op_sepolia.paymaster.first.option?.toJson();

    final balance = await mint(contractAddress, bundlerUrl, rpcUrl, paymasterUrl, paymasterParams ?? {}, state!.aa!, "transfer", _usdtTokenAbiPath, state!.initCode!, ORIGIN_DOMAIN, _network, amount: amount ?? 1, receiver: receiver ?? rcv0);
    change(state?..usdtBalance = balance, status: RxStatus.success());
    return balance;
  }

  Future<GenericResponse> register(String email,
      {String? captcha, String? network = _network}) async {
    final api = Api();
    GenericResponse<RegResponse> res = await api.reg(
        RegRequest(captcha: captcha!, email: email, origin: _ORIGIN_DOMAIN));
    if (res.success) {
      final body = await api.createAttestationFromPublicKey(
          res.data!.toJson(),
          res.data?.authenticatorSelection?.authenticatorAttachment,
          _ORIGIN_DOMAIN);
      final resp = await api.regVerify(email, _ORIGIN_DOMAIN, network, body);
      if (isNotNull(resp.token)) {
        return GenericResponse.success("ok");
      }
    }
    return res;
  }

  Future<GenericResponse> prepare(String email) async {
    var res = await Api().prepare(PrepareRequest(email: email));
    return res;
  }

  Future<GenericResponse> login({CredentialDialogFactory? factory}) async {
    try {
      final api = Api();
      var res = await api.sign(SignRequest(origin: _ORIGIN_DOMAIN));
      if (res.success) {
        final body = await api.createAssertionFromPublic(res.data!.toJson(), _ORIGIN_DOMAIN, factory: factory);
        final resp = await api.signVerify(_ORIGIN_DOMAIN, body);
        if (isNotNull(resp.token)) {
          return GenericResponse.success("ok");
        }
      }
      return res;
    } catch(e, s) {
      if(e is GetAssertionException) {
        return GenericResponse<GetAssertionException>(data: e);
      }
      return GenericResponse.errorWithDioException(e as DioException);
    }
  }

  Future<GenericResponse> createWallet(ChainRequest req) async{
    try {
      final api = Api();
      final res = await api.createWallet(req);
      if(res.success) {
        return GenericResponse.success("ok");
      }
      return res;
    } catch (e, s) {
      return GenericResponse.errorWithDioException(e as DioException);
    }
  }

  @override
  void onClose() {
    super.onClose();
  }

  Future<GenericResponse> logout() async {
    Get.find<SharedPreferences>().token = null;
    await Future.delayed(const Duration(seconds: 3));
    final res = GenericResponse.success("ok");
    return res;
  }
}
