import 'package:bonfire_multiplayer/chain/api/air_account_api_ext.dart';
import 'package:uuid/v4.dart';
import 'package:web3dart/credentials.dart';
import 'package:web3dart/crypto.dart';
import '../../../../../api/api.dart';
import '../../../../../api/requests/tx_sign_request.dart';
import '../../types.dart';

@Deprecated('eOASignature is deprecated. Replace with signUserOpHash.')
UserOperationMiddlewareFn eOASignature(EthPrivateKey credentials) {
  return (ctx) async {
    ctx.op.signature = bytesToHex(
      credentials.signPersonalMessageToUint8List(
        ctx.getUserOpHash(),
      ),
      include0x: true,
    );
  };
}

UserOperationMiddlewareFn signUserOpHash(EthPrivateKey credentials) {
  return (ctx) async {
    ctx.op.signature = bytesToHex(
      credentials.signPersonalMessageToUint8List(
        ctx.getUserOpHash(),
      ),
      include0x: true,
    );
  };
}

UserOperationMiddlewareFn signUserOpHashUseSignature(String origin, String network, {String? networkAlias}) {
  return (ctx) async {
    String unsignedOpHash = bytesToHex(ctx.getUserOpHash());
    String ticket = UuidV4().generate().replaceAll("-", "").substring(0, 6);
    final api = Api();
    final resp = await api.txSign(TxSignRequest(networkAlias: networkAlias, network: network, ticket: ticket, origin: origin, txdata: unsignedOpHash));
    if(resp.success) {
      final body = await api.createAssertionFromPublic(resp.data!.toJson(), origin);
      final res = await Api().txSignVerify(ticket, network, origin, networkAlias, body);
      if(res.success) {
        ctx.op.signature = res.data!.sign!;
      }
    }
  };
}
