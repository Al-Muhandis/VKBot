{$mode objfpc}{$H+}{$J-}

unit VKWebhookTests;

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, VKTypes, VKBotFramework, VKWebhook, VKBotFrameworkMocks
  ;

type
  { TWebhookProcessorTests }
  TWebhookProcessorTests = class(TTestCase)
  private
    fBot: TMockVKBot;
    fHandlerCalled: Boolean;
    fProcessor: TVKWebhookProcessor;
    fLogMessages: TStringList;

    procedure FailingHandler(const {%H-}aEvent: TJSONObject);
    procedure OnLog(aLevel: TLogLevel; const aMessage: string);
    procedure MsgHandler(const aMsg: TVKMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { Confirmation handling }
    procedure TestProcessWebhook_ConfirmationRequest;
    procedure TestProcessWebhook_ConfirmationWithCustomCode;

    { Validation tests }
    procedure TestProcessWebhook_ValidRequestWithoutSecret;
    procedure TestProcessWebhook_ValidRequestWithMatchingSecret;
    procedure TestProcessWebhook_RejectWrongSecret;
    procedure TestProcessWebhook_RejectWrongGroupID;

    { Event processing }
    procedure TestProcessWebhook_MessageNewEvent;
    procedure TestProcessWebhook_UnknownEventType;
    procedure TestProcessWebhook_MissingObjectField;

    { Error handling }
    procedure TestProcessWebhook_InvalidJSON;
    procedure TestProcessWebhook_EmptyRequestBody;
    procedure TestProcessWebhook_ExceptionDuringProcessing;

    { Response helpers integration }
    procedure TestCreateWebhookOKResponse;
    procedure TestCreateWebhookConfirmationResponse;
    procedure TestCreateWebhookErrorResponse;
  end;

  { TWebhookIntegrationTests }
  TWebhookIntegrationTests = class(TTestCase)
  private
    fBot: TMockVKBot;
    fEventHandled: Boolean;
    fProcessor: TVKWebhookProcessor;
    fCommandExecuted: Boolean;
    fMessageText: string;

    procedure CustomHandler(const aEvent: TJSONObject);
    procedure OnLog({%H-}aLevel: TLogLevel; const {%H-}aMessage: string);
    procedure HandleTestCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
    procedure HandleAnyMessage(const aMsg: TVKMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWebhookToCommandExecution;
    procedure TestWebhookToMessageHandler;
    procedure TestMultipleWebhookCalls;
  end;

implementation


function MakeWebhookJSON(const aType, aObjectJSON: string; aGroupID: Int64 = 123456;
  const aWebHookSecret: String = 'webhook_secret'): string;
begin
  Result := Format('{"type":"%s","object":%s,"group_id":%d,"secret":"%s"}',
    [aType, aObjectJSON, aGroupID, aWebHookSecret]);
end;

{ TWebhookProcessorTests }

procedure TWebhookProcessorTests.SetUp;
begin
  fLogMessages := TStringList.Create;
  fBot := TMockVKBot.Create('test_token', 123456);
  fBot.OnLog := @OnLog;
  TMockHTTPClient.SetDefaultResponse('{"response":1}');

  fProcessor := TVKWebhookProcessor.Create(fBot, 'confirmation_code_123', 'webhook_secret');
  fProcessor.OnLog := @OnLog;
end;

procedure TWebhookProcessorTests.TearDown;
begin
  fProcessor.Free;
  fBot.Free;
  fLogMessages.Free;
end;

procedure TWebhookProcessorTests.FailingHandler(const aEvent: TJSONObject);
begin
  raise Exception.Create('Simulated processing error');
end;

procedure TWebhookProcessorTests.OnLog(aLevel: TLogLevel; const aMessage: string);
begin
  fLogMessages.Add(Format('[%d]%s', [Ord(aLevel), aMessage]));
end;

procedure TWebhookProcessorTests.MsgHandler(const aMsg: TVKMessage);
begin
  fHandlerCalled := True;
  CheckEquals('Hello from webhook', aMsg.Text);
end;

{ --- Confirmation tests --- }

procedure TWebhookProcessorTests.TestProcessWebhook_ConfirmationRequest;
var
  aResponse: TVKWebhookResponse;
  aRequestBody: string;
begin
  aRequestBody := '{"type":"confirmation","group_id":123456}';

  aResponse := fProcessor.ProcessWebhook(aRequestBody);

  CheckTrue(wrtConfirmation=aResponse.ResponseType, 'Тип ответа должен быть confirmation');
  CheckEquals('confirmation_code_123', aResponse.Content, 'Код подтверждения должен совпадать');
  CheckEquals(VK_HTTP_OK, aResponse.HTTPStatus, 'HTTP статус должен быть 200');
end;

procedure TWebhookProcessorTests.TestProcessWebhook_ConfirmationWithCustomCode;
var
  aResponse: TVKWebhookResponse;
begin
  fProcessor.ConfirmationCode := 'my_custom_code_abc';

  aResponse := fProcessor.ProcessWebhook('{"type":"confirmation"}');

  CheckEquals('my_custom_code_abc', aResponse.Content);
end;

{ --- Validation tests --- }

procedure TWebhookProcessorTests.TestProcessWebhook_ValidRequestWithoutSecret;
var
  aResponse: TVKWebhookResponse;
  aProcessorNoSecret: TVKWebhookProcessor;
begin
  aProcessorNoSecret := TVKWebhookProcessor.Create(fBot, 'code', EmptyStr); // empty secret
  try
    aResponse := aProcessorNoSecret.ProcessWebhook(
      '{"type":"message_new","object":{"message":{"text":"hi","peer_id":1}},"group_id":123456}');

    CheckTrue(wrtOK=aResponse.ResponseType, 'Запрос без секрета должен пройти');
    CheckEquals(VK_WEBHOOK_OK, aResponse.Content);
  finally
    aProcessorNoSecret.Free;
  end;
end;

procedure TWebhookProcessorTests.TestProcessWebhook_ValidRequestWithMatchingSecret;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook(
    MakeWebhookJSON('message_new', '{"message":{"text":"test","peer_id":1}}'));

  CheckTrue(wrtOK=aResponse.ResponseType);
  CheckTrue(fLogMessages.IndexOf('[0]Processing webhook event: message_new') >= 0,
    'Должны быть логи об обработке события');
end;

procedure TWebhookProcessorTests.TestProcessWebhook_RejectWrongSecret;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook(
    '{"type":"message_new","object":{},"group_id":123456,"secret":"wrong_secret"}');

  CheckTrue(wrtError=aResponse.ResponseType, 'Неверный секрет должен вернуть ошибку');
  CheckEquals(VK_HTTP_UNAUTHORIZED, aResponse.HTTPStatus);
  CheckTrue(fLogMessages.IndexOf('[2]Webhook secret mismatch') >= 0,
    'Должен быть лог о несоответствии секрета');
end;

procedure TWebhookProcessorTests.TestProcessWebhook_RejectWrongGroupID;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook(
    '{"type":"message_new","object":{},"group_id":999999,"secret":"webhook_secret"}');

  CheckTrue(wrtError=aResponse.ResponseType);
  CheckEquals(VK_HTTP_UNAUTHORIZED, aResponse.HTTPStatus);
  CheckTrue(fLogMessages.IndexOf('[2]Webhook group_id mismatch: expected 123456, got 999999') >= 0);
end;

{ --- Event processing tests --- }

procedure TWebhookProcessorTests.TestProcessWebhook_MessageNewEvent;
var
  aResponse: TVKWebhookResponse;
begin
  fHandlerCalled := False;
  fBot.AddMessageHandler(@MsgHandler);

  aResponse := fProcessor.ProcessWebhook(
    MakeWebhookJSON('message_new',
      '{"message":{"text":"Hello from webhook","peer_id":777,"from_id":888}}'));

  CheckTrue(wrtOK=aResponse.ResponseType);
  CheckTrue(fHandlerCalled, 'Обработчик сообщения должен быть вызван');
end;

procedure TWebhookProcessorTests.TestProcessWebhook_UnknownEventType;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook(
    MakeWebhookJSON('unknown_event_xyz', '{"data":"test"}'));

  // Unknown type does not raise error - just log
  CheckTrue(wrtOK=aResponse.ResponseType);
  CheckTrue(fLogMessages.IndexOf('[2]Unknown event type: unknown_event_xyz') >= 0);
end;

procedure TWebhookProcessorTests.TestProcessWebhook_MissingObjectField;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook(
    '{"type":"message_new","group_id":123456}'); // no "object" field

  // ProcessUpdate ignores messages without object, but does not fail
  CheckTrue(wrtError=aResponse.ResponseType);
end;

{ --- Error handling tests --- }

procedure TWebhookProcessorTests.TestProcessWebhook_InvalidJSON;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook('{ invalid json }');

  CheckTrue(wrtError=aResponse.ResponseType);
  CheckEquals(VK_HTTP_BAD_REQUEST, aResponse.HTTPStatus);
  CheckTrue(aResponse.Content <> '', 'Сообщение об ошибке не должно быть пустым');
  CheckTrue(fLogMessages.IndexOf('[3]Invalid webhook JSON structure') >= 0);
end;

procedure TWebhookProcessorTests.TestProcessWebhook_EmptyRequestBody;
var
  aResponse: TVKWebhookResponse;
begin
  aResponse := fProcessor.ProcessWebhook('');

  CheckTrue(wrtError=aResponse.ResponseType);
  CheckEquals(VK_HTTP_BAD_REQUEST, aResponse.HTTPStatus);
end;

procedure TWebhookProcessorTests.TestProcessWebhook_ExceptionDuringProcessing;
var
  aResponse: TVKWebhookResponse;
  aBotWithException: TMockVKBot;
  aProcessorWithException: TVKWebhookProcessor;
begin
  aBotWithException := TMockVKBot.Create('token', 123);
  aBotWithException.EventHandlers[etMessageNew]:=@FailingHandler;

  aProcessorWithException := TVKWebhookProcessor.Create(aBotWithException, 'code', '');
  try
    aResponse := aProcessorWithException.ProcessWebhook(
      '{"type":"message_new","object":{"message":{"text":"boom"}},"group_id":123}');

    // Error in handler must not to fail reply
    CheckTrue(wrtOK=aResponse.ResponseType, 'Исключение в обработчике должно быть перехвачено');
  finally
    aProcessorWithException.Free;
    aBotWithException.Free;
  end;
end;

{ --- Response helpers integration --- }

procedure TWebhookProcessorTests.TestCreateWebhookOKResponse;
var
  aResp: TVKWebhookResponse;
begin
  aResp := CreateWebhookOKResponse;
  CheckTrue(wrtOK=aResp.ResponseType);
  CheckEquals(VK_WEBHOOK_OK, aResp.Content);
  CheckEquals(VK_HTTP_OK, aResp.HTTPStatus);
end;

procedure TWebhookProcessorTests.TestCreateWebhookConfirmationResponse;
var
  aResp: TVKWebhookResponse;
begin
  aResp := CreateWebhookConfirmationResponse('abc123');
  CheckTrue(wrtConfirmation=aResp.ResponseType);
  CheckEquals('abc123', aResp.Content);
  CheckEquals(VK_HTTP_OK, aResp.HTTPStatus);
end;

procedure TWebhookProcessorTests.TestCreateWebhookErrorResponse;
var
  aResp: TVKWebhookResponse;
begin
  aResp := CreateWebhookErrorResponse('Something went wrong', 422);
  CheckTrue(wrtError=aResp.ResponseType);
  CheckEquals('Something went wrong', aResp.Content);
  CheckEquals(422, aResp.HTTPStatus);
end;

{ TWebhookIntegrationTests }

procedure TWebhookIntegrationTests.SetUp;
begin
  fBot := TMockVKBot.Create('integration_token', 555666);
  TMockHTTPClient.SetDefaultResponse('{"response":1}');
  fProcessor := TVKWebhookProcessor.Create(fBot, 'conf_123', 'secret_xyz');
  fCommandExecuted := False;
  fMessageText := '';
end;

procedure TWebhookIntegrationTests.TearDown;
begin
  fProcessor.Free;
  fBot.Free;
end;

procedure TWebhookIntegrationTests.CustomHandler(const aEvent: TJSONObject);
begin
  fEventHandled := True;
  CheckEquals(999, aEvent.Get('custom_field', 0));
end;

procedure TWebhookIntegrationTests.OnLog(aLevel: TLogLevel; const aMessage: string);
begin
  // silent for integration tests
end;

procedure TWebhookIntegrationTests.HandleTestCommand(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  fCommandExecuted := True;
  aMsg.Reply('Command response');
end;

procedure TWebhookIntegrationTests.HandleAnyMessage(const aMsg: TVKMessage);
begin
  fMessageText := aMsg.Text;
end;

procedure TWebhookIntegrationTests.TestWebhookToCommandExecution;
var
  aResponse: TVKWebhookResponse;
  aRequestBody: string;
begin
  fBot.CommandHandlers['start']:=@HandleTestCommand;

  aRequestBody := '{"type":"message_new","object":{"message":{"text":"/start","peer_id":111,' +
    '"payload":"{\"command\":\"start\"}","from_id":222}},"group_id":555666,"secret":"secret_xyz"}';

  TMockHTTPClient.ClearCalls;
  aResponse := fProcessor.ProcessWebhook(aRequestBody);

  CheckTrue(wrtOK=aResponse.ResponseType);
  CheckTrue(fCommandExecuted, 'Команда из payload должна выполниться');
  CheckTrue(TMockHTTPClient.WasCalled('messages.send'), 'Должен быть вызов API для ответа');
end;

procedure TWebhookIntegrationTests.TestWebhookToMessageHandler;
var
  aResponse: TVKWebhookResponse;
begin
  fBot.AddMessageHandler(@HandleAnyMessage);

  aResponse := fProcessor.ProcessWebhook(
    MakeWebhookJSON('message_new', '{"message":{"text":"Integration test","peer_id":333}}', 555666, 'secret_xyz'));

  CheckTrue(wrtOK=aResponse.ResponseType);
  CheckEquals('Integration test', fMessageText);
end;

procedure TWebhookIntegrationTests.TestMultipleWebhookCalls;
var
  aResponse1, aResponse2, aResponse3: TVKWebhookResponse;
begin
  fBot.AddMessageHandler(@HandleAnyMessage);

  aResponse1 := fProcessor.ProcessWebhook(
    MakeWebhookJSON('message_new', '{"message":{"text":"First","peer_id":1}}', 555666, 'secret_xyz'));
  aResponse2 := fProcessor.ProcessWebhook(
    MakeWebhookJSON('message_new', '{"message":{"text":"Second","peer_id":2}}', 555666, 'secret_xyz'));
  aResponse3 := fProcessor.ProcessWebhook(
    '{"type":"confirmation"}');

  CheckTrue(wrtOK=aResponse1.ResponseType);
  CheckTrue(wrtOK=aResponse2.ResponseType);
  CheckTrue(wrtConfirmation=aResponse3.ResponseType);
  CheckEquals('Second', fMessageText, 'Последнее сообщение должно быть обработано');
end;

initialization
  RegisterTest(TWebhookProcessorTests);
  RegisterTest(TWebhookIntegrationTests);

end.
