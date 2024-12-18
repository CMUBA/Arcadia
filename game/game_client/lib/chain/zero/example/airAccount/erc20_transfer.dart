import 'dart:convert';
import 'package:bonfire_multiplayer/chain/extensions/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../../../../main.dart';
import '../../../config/tx_configs.dart';
import '../../../utils/validate_util.dart';
import '../../userop/src/preset/builder/air_account.dart';
import '../../userop/userop.dart';
import 'package:flutter/services.dart' show rootBundle;

Future<String?> getBalance(String rpcUrl, String contractAddress, String tokenAbiPath, String aaAddress, {bool decimals = true}) async{
  final contractName = tokenAbiPath.substring(tokenAbiPath.lastIndexOf("/") + 1, tokenAbiPath.lastIndexOf("."));
  String abiStr = await rootBundle.loadString(tokenAbiPath);
  final abiObj = jsonDecode(abiStr);
  final web3Client = Web3Client.custom(BundlerJsonRpcProvider(rpcUrl, http.Client()));
  final response = await ContractsHelper.readFromContract(web3Client, contractName, contractAddress, "balanceOf", [EthereumAddress.fromHex(aaAddress)], jsonInterface: jsonEncode(abiObj['abi']));
  return decimals ? formatUnits(response.first as BigInt, 6) : "${response.first as BigInt}";
}

Future<String?> mint(String contractAddress, String bundlerUrl, String rpcUrl, String paymasterUrl, Map<String, dynamic> paymasterParams, String aaAddress, String functionName, String tokenAbiPath, String initCode, String origin, String network, {num? amount, String? receiver, bool decimals = true, String? networkAlias}) async {
  final contractName = tokenAbiPath.substring(tokenAbiPath.lastIndexOf("/") + 1, tokenAbiPath.lastIndexOf("."));
  final tokenAddress = EthereumAddress.fromHex(contractAddress);
  final targetAddress = EthereumAddress.fromHex(receiver ?? aaAddress);
  final etherAmount = decimals ? parseUnits("${amount ?? 0}", 6) : BigInt.from(amount ?? 0);

  logger.i("amount : ${etherAmount}");

  final paymasterMiddleware = verifyingPaymaster(
     paymasterUrl,
     paymasterParams,
  );

  final IPresetBuilderOpts opts = IPresetBuilderOpts()
  //..nonceKey = BigInt.from(hexToDartInt(UuidV4().generate().replaceAll("-", "").substring(0, 6)))
  ..paymasterMiddleware = paymasterMiddleware;
  //..overrideBundlerRpc = bundlerRPC;

  final airAccount = await AirAccount.init(
    aaAddress,
    initCode,
    rpcUrl,
    network,
    origin,
    opts: opts,
    networkAlias: networkAlias
  );

  final client = await Client.init(bundlerUrl);

  final sendOpts = ISendUserOperationOpts()
    ..dryRun = false
    ..onBuild = (IUserOperation ctx) async {
      logger.i("Signed UserOperation：" + ctx.toJson().toString());
    };

  String abiStr = await rootBundle.loadString(tokenAbiPath);
  final abiObj = jsonDecode(abiStr);

  final call = Call(
    to: tokenAddress,
    value: BigInt.zero,
    data: ContractsHelper.encodedDataForContractCall(
      contractName,
      tokenAddress.toString(),
      functionName,//_mint, mint
      [
        targetAddress,
        etherAmount,
      ],
      include0x: true,
      jsonInterface: jsonEncode(abiObj['abi'])
    ),
  );
  final userOp = await airAccount.execute(call);

  final res = await client.sendUserOperation(
    userOp,
    opts: sendOpts,
  );
  debugPrint('UserOpHash: ${res.userOpHash}');

  debugPrint('Waiting for transaction...');
  final ev = await res.wait();
  debugPrint('Transaction hash: ${ev?.transactionHash}');
  if(isNotNull(ev?.transactionHash))Get.find<SharedPreferences>().saveTransactionHash(res.userOpHash, ev?.transactionHash);
  return await getBalance(rpcUrl, contractAddress, tokenAbiPath, aaAddress, decimals: decimals);
}

Future<List<String?>> mintUsdtAndNFT(String aaAddress, String usdtFunctionName, String usdtTokenAbiPath, String nftFunctionName, String nftTokenAbiPath, String initCode, String origin, String network, {int? amount, String? receiver, String? networkAlias}) async {

  final targetAddress = EthereumAddress.fromHex(receiver ?? aaAddress);

  final bundlerRPC = op_sepolia.bundler.first.url;
  final rpcUrl = op_sepolia.rpc;

  final paymasterMiddleware = verifyingPaymaster(
    op_sepolia.paymaster.first.url,
    op_sepolia.paymaster.first.option!.toJson(),
  );

  final IPresetBuilderOpts opts = IPresetBuilderOpts()
  //..nonceKey = BigInt.from(hexToDartInt(UuidV4().generate().replaceAll("-", "").substring(0, 6)))
    ..paymasterMiddleware = paymasterMiddleware;
  //..overrideBundlerRpc = bundlerRPC;

  final airAccount = await AirAccount.init(
    aaAddress,
    initCode,
    rpcUrl,
    network,
    origin,
    networkAlias: networkAlias,
    opts: opts,
  );

  final client = await Client.init(bundlerRPC);

  final sendOpts = ISendUserOperationOpts()
    ..dryRun = false
    ..onBuild = (IUserOperation ctx) async {
      logger.i("Signed UserOperation：" + ctx.toJson().toString());
    };

  final usdtTokenAddress = EthereumAddress.fromHex(op_sepolia.contracts.usdt);
  final usdtContractName = usdtTokenAbiPath.substring(usdtTokenAbiPath.lastIndexOf("/") + 1, usdtTokenAbiPath.lastIndexOf("."));
  String usdtAbiStr = await rootBundle.loadString(usdtTokenAbiPath);
  final usdtAbiObj = jsonDecode(usdtAbiStr);

  final callUsdt = Call(
    to: usdtTokenAddress,
    value: BigInt.zero,
    data: ContractsHelper.encodedDataForContractCall(
        usdtContractName,
        usdtTokenAddress.toString(),
        usdtFunctionName,//_mint, mint
        [
          targetAddress,
          parseUnits("${amount ?? 0}", 6),
        ],
        include0x: true,
        jsonInterface: jsonEncode(usdtAbiObj['abi'])
    ),
  );

  final nftTokenAddress = EthereumAddress.fromHex(op_sepolia.contracts.nft);
  final nftContractName = nftTokenAbiPath.substring(nftTokenAbiPath.lastIndexOf("/") + 1, nftTokenAbiPath.lastIndexOf("."));
  String nftAbiStr = await rootBundle.loadString(nftTokenAbiPath);
  final nftAbiObj = jsonDecode(nftAbiStr);

  final callNFT = Call(
    to: nftTokenAddress,
    value: BigInt.zero,
    data: ContractsHelper.encodedDataForContractCall(
        nftContractName,
        nftTokenAddress.toString(),
        nftFunctionName,//_mint, mint
        [
          targetAddress,
          BigInt.from(amount!),
        ],
        include0x: true,
        jsonInterface: jsonEncode(nftAbiObj['abi'])
    ),
  );

  final userOp = await airAccount.executeBatch([callUsdt, callNFT]);

  final res = await client.sendUserOperation(
    userOp,
    opts: sendOpts,
  );
  debugPrint('UserOpHash: ${res.userOpHash}');

  debugPrint('Waiting for transaction...');
  final ev = await res.wait();
  debugPrint('Transaction hash: ${ev?.transactionHash}');
  final usdtBalance = await getBalance(rpcUrl, usdtTokenAddress.toString(), usdtTokenAbiPath, aaAddress);
  final nftBalance = await getBalance(rpcUrl, nftTokenAddress.toString(), nftTokenAbiPath, aaAddress, decimals: false);
  return [usdtBalance, nftBalance];
}

String formatUnits(BigInt value, int decimals) {
  // 将 BigInt 转换为 double 以处理小数
  double base = math.pow(10, decimals).toDouble();
  double formattedValue = value.toDouble() / base;

  // 转换为字符串，并确保显示固定的小数位数
  return formattedValue.toStringAsFixed(decimals);
}

BigInt parseUnits(String value, int decimals) {
  // 将输入值转换为 double，并乘以 10^decimals
  double base = math.pow(10, decimals).toDouble();
  double parsedValue = double.parse(value) * base;

  // 返回 BigInt 表示的最小单位值
  return BigInt.from(parsedValue);
}