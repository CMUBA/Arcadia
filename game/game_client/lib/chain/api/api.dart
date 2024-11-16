import 'package:dio/dio.dart';
import 'package:retrofit/http.dart';
import 'package:retrofit/retrofit.dart';
import 'generic_response.dart';
import 'local_http_client.dart';
import 'requests/assertion_verify_request_body.dart';
import 'requests/bind_account_request.dart';
import 'requests/chain_request.dart';
import 'requests/prepare_request.dart';
import 'requests/reg_request.dart';
import 'requests/sign_account_request.dart';
import 'requests/sign_request.dart';
import 'requests/tx_sign_request.dart';
import 'requests/verify_request_body.dart';
import 'response/account_info_response.dart';
import 'response/reg_response.dart';
import 'response/reg_verify_response.dart';
import 'response/tx_sign_response.dart';
import 'response/tx_sign_verify_response.dart';

part 'api.g.dart';

@RestApi(baseUrl: 'https://airaccount.aastar.io')
abstract class Api{
  factory Api({Dio? dio, String? baseUrl}) {
    LocalHttpClient().init(baseUrl: baseUrl);
    return _Api(dio ?? LocalHttpClient.dio, baseUrl: baseUrl);
  }

  @POST("/api/passkey/v1/reg/prepare")
  Future<GenericResponse<dynamic>> prepare(@Body() PrepareRequest req);

  @POST('/api/passkey/v1/reg')
  Future<GenericResponse<RegResponse>> reg(@Body() RegRequest req);

  @POST("/api/passkey/v1/reg/verify")
  Future<RegVerifyResponse> regVerify(@Query("email") String email, @Query("origin") String origin, @Query("network") String? network, @Body() AttestationVerifyRequestBody req);

  @POST("/api/passkey/v1/sign")
  Future<GenericResponse<SignResponse>> sign(@Body() SignRequest req);

  @POST("/api/passkey/v1/sign/verify")
  Future<RegVerifyResponse> signVerify(@Query("origin") String origin, @Body() AssertionVerifyRequestBody req);

  @GET("/api/passkey/v1/account/info")
  Future<GenericResponse<AccountInfoResponse>> getAccountInfo(@Query('network') String network);

  @POST("/api/passkey/v1/tx/sign")
  Future<GenericResponse<SignResponse>> txSign(@Body() TxSignRequest req);

  @POST("/api/passkey/v1/tx/sign/verify")
  Future<GenericResponse<SignVerifyResponse>> txSignVerify(@Query("ticket") String ticket, @Query('network') String network, @Query("origin") String origin, @Query('network_alias') String? networkAlias, @Body() AssertionVerifyRequestBody req);

  @POST("/api/account/v1/transfer")
  Future<GenericResponse<dynamic>> transfer(@Query("apiKey") String apiKey);

  @POST("/api/account/v1/bind")
  Future<GenericResponse<dynamic>> bind(@Body() BindAccountRequest req);

  @POST("/api/account/v1/sign")
  Future<GenericResponse<dynamic>> signAccount(@Body() SignAccountRequest req);

  @POST("/api/passkey/v1/account/chain")
  Future<GenericResponse<dynamic>> createWallet(@Body() ChainRequest req);
}