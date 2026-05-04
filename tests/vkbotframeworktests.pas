{$mode objfpc}{$H+}{$J-}

unit VKBotFrameworkTests;

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser, VKBotFramework, VKBotFrameworkMocks
  ;

type

  TTestVKBot = class(TMockVKBot);

  { TMessageTests }
  TMessageTests = class(TTestCase)
  private
    fBot: TMockVKBot;
    fMsgData: TJSONObject;
    fMessage: TVKMessage;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetText;
    procedure TestGetPeerID;
    procedure TestGetFromID;
    procedure TestGetPayload;
    procedure TestReplyCallsSend;
    procedure TestSendWithExplicitPeerID;
    procedure TestReplySendsToCorrectPeer;
    procedure TestSendWithKeyboard;
  end;

  { TKeyboardTests }
  TKeyboardTests = class(TTestCase)
  private
    fKeyboard: TVKKeyboard;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCreateDefault;
    procedure TestBuildStructure;
    procedure TestAddButton;
    procedure TestAddRow;
    procedure TestBuildWithPayload;
    procedure TestOneTimeAndInlineFlags;
  end;

  { TBotCommandTests }
  TBotCommandTests = class(TTestCase)
  private
    fBot: TTestVKBot;
    fCommandCalled: Boolean;
    fHandlerCalled: Boolean;
    fLastArgs: TStringArray;
    fMsgData: TJSONObject;
    fReceivedPeerID: Int64;
    fReceivedText: String;
    procedure RunMethodProcessMessage;
    procedure PayloadCommandHandler(const {%H-}aMsg: TVKMessage; const aArgs: TStringArray);
    procedure TestPayloadCommandCaseInsensitive;
    procedure TestPayloadWithInvalidJSON;
    procedure TestPayloadWithoutCommandField;
    procedure UnknownHandler(const {%H-}aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure DummyCommandHandler(const {%H-}aMessage: TVKMessage; const AArgs: TStringArray);
    procedure DummyMessageHandler(const aMsg: TVKMessage);
  published
    procedure TestOnCommandRegistration;
    procedure TestCommandWithArgs;
    procedure TestCommandCaseInsensitive;
    procedure TestUnknownCommandNotHandled;
    procedure TestPayloadCommandHandling;
  end;

  { TBotMessageHandlerTests }
  TBotMessageHandlerTests = class(TTestCase)
  private
    fBot: TTestVKBot;
    fCmdCalled: Boolean;
    fHandlerCalled: Boolean;
    fReceivedPeerID: Int64;
    fReceivedText: String;
    procedure TestCmd(const {%H-}Msg: TVKMessage; const {%H-}Args: TStringArray);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure DummyMessageHandler(const aMsg: TVKMessage);
  published
    procedure TestOnMessageRegistration;
    procedure TestMessageHandlerCalledForNonCommand;
    procedure TestMessageHandlerNotCalledForHandledCommand;
  end;

  { TBotEventTests }
  TBotEventTests = class(TTestCase)
  private
    fBot: TTestVKBot;
    fEventCalled: Boolean;
    fReceivedEvent: TJSONObject;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    procedure DummyEventHandler(const aEvent: TJSONObject);
  published
    procedure TestOnEventRegistration;
    procedure TestProcessEventUnknownType;
  end;

  { TAPICallTests }
  TAPICallTests = class(TTestCase)
  private
    fBot: TMockVKBot;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAPICallURLFormat;
    procedure TestAPICallWithParams;
    procedure TestSendMessageSuccess;
    procedure TestSendMessageWithKeyboard;
    procedure TestAPICallReturnsCorrectData;
    procedure TestMultipleAPICallsLogged;
  end;

  { TIntegrationTests }
  TIntegrationTests = class(TTestCase)
  private
    fBot: TTestVKBot;
    fEventCalled: Boolean;
    fMessageReceived: Boolean;
    fReceivedEvent: TJSONObject;
    fReceivedText: string;     
    procedure DummyEventHandler(const aEvent: TJSONObject);
    procedure HandleMessage(const aMsg: TVKMessage);
    procedure HandleCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestCommandTriggersAPICall;
    procedure TestMessageHandlerTriggersReply;
    procedure TestEventProcessing;
  end;

  { TEventTypeHelperTests }

  TEventTypeHelperTests = class(TTestCase)
  published
    procedure TestStringToEnum_KnownTypes;
    procedure TestStringToEnum_UnknownType;
    procedure TestEnumToString_RoundTrip;
    procedure TestStringToEnum_CaseSensitivity;
  end;

implementation

uses
  fphttpclient, VKTypes
  ;

{ TMessageTests }

procedure TMessageTests.SetUp;
begin
  fBot := TMockVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');

  fMsgData := TJSONObject.Create;
  fMsgData.Add('text', 'Hello, World!');
  fMsgData.Add('peer_id', Int64(987654));
  fMsgData.Add('from_id', Int64(111222));
  fMsgData.Add('payload', '{"action":"start"}');
  fMessage := TVKMessage.Create(fBot, fMsgData);
end;

procedure TMessageTests.TearDown;
begin
  fMessage.Free;
  fMsgData.Free;
  fBot.Free;
end;

procedure TMessageTests.TestGetText;
begin
  CheckEquals('Hello, World!', fMessage.Text);
end;

procedure TMessageTests.TestGetPeerID;
begin
  CheckEquals(Int64(987654), fMessage.PeerID);
end;

procedure TMessageTests.TestGetFromID;
begin
  CheckEquals(Int64(111222), fMessage.FromID);
end;

procedure TMessageTests.TestGetPayload;
begin
  CheckEquals('{"action":"start"}', fMessage.Payload);
end;

procedure TMessageTests.TestReplyCallsSend;
var
  aLastURL: string;
begin
  fMessage.Reply('Reply text');

  CheckTrue(TMockHTTPClient.GetCallCount > 0, 'HTTP клиент должен быть вызван');
  aLastURL := TMockHTTPClient.GetLastURL;

  // Проверяем, что Reply использует правильный PeerID
  CheckTrue(Pos('peer_id=987654', aLastURL) > 0, 'Reply должен использовать PeerID из сообщения');
  CheckTrue(Pos('message=Reply', aLastURL) > 0, 'Reply должен отправить текст');
end;

procedure TMessageTests.TestSendWithExplicitPeerID;
var
  aLastURL: string;
begin
  fMessage.Send('Test message', 555666);

  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('peer_id=555666', aLastURL) > 0, 'Send должен использовать явно указанный PeerID');
end;

procedure TMessageTests.TestReplySendsToCorrectPeer;
begin
  TMockHTTPClient.ClearCalls;

  fMessage.Reply('Response');

  CheckEquals(1, TMockHTTPClient.GetCallCount, 'Должен быть один вызов');
  CheckTrue(TMockHTTPClient.WasCalled('peer_id=987654'), 'Должен отправить на правильный peer_id');
end;

procedure TMessageTests.TestSendWithKeyboard;
var
  aKB: TVKKeyboard;
  aLastURL: string;
begin
  aKB := TVKKeyboard.Create;
  try
    aKB.AddButton('Test Button');
    fMessage.Send('Choose', 0, aKB.Build);

    aLastURL := TMockHTTPClient.GetLastURL;
    CheckTrue(Pos('keyboard=', aLastURL) > 0, 'Send должен передать клавиатуру');
  finally
    aKB.Free;
  end;
end;

{ TKeyboardTests }

procedure TKeyboardTests.SetUp;
begin
  fKeyboard := TVKKeyboard.Create;
end;

procedure TKeyboardTests.TearDown;
begin
  fKeyboard.Free;
end;

procedure TKeyboardTests.TestCreateDefault;
begin
  CheckFalse(fKeyboard.OneTime, 'one_time по умолчанию false');
  CheckFalse(fKeyboard.Inline, 'inline по умолчанию false');
end;

procedure TKeyboardTests.TestBuildStructure;
var
  aJSON: TJSONData;
  aKeyboardObj: TJSONObject;
begin
  fKeyboard.AddButton('Test');
  aJSON := GetJSON(fKeyboard.Build);
  try
    CheckTrue(aJSON is TJSONObject, 'Build должен возвращать JSON-объект');
    aKeyboardObj := aJSON as TJSONObject;

    CheckEquals(False, aKeyboardObj.Get('one_time', True), 'one_time флаг');
    CheckEquals(False, aKeyboardObj.Get('inline', True), 'inline флаг');
    CheckTrue(aKeyboardObj.Find('buttons') <> nil, 'Должно быть поле buttons');
  finally
    aJSON.Free;
  end;
end;

procedure TKeyboardTests.TestAddButton;
var
  aButtons: TJSONArray;
  aFirstRow: TJSONArray;
  aButton: TJSONObject;
  aAction, aJSON: TJSONObject;
begin
  fKeyboard.AddButton('Click Me', bcPrimary, '{"cmd":"test"}');

  aJSON := GetJSON(fKeyboard.Build) as TJSONObject;
  try
    aButtons := aJSON.Arrays['buttons'];
    CheckEquals(1, aButtons.Count, 'Должна быть одна строка');

    aFirstRow := aButtons.Items[0] as TJSONArray;
    CheckEquals(1, aFirstRow.Count, 'В строке должна быть одна кнопка');

    aButton := aFirstRow.Items[0] as TJSONObject;
    CheckEquals('primary', aButton.Get('color', ''), 'Цвет кнопки');

    aAction := aButton.Find('action') as TJSONObject;
    CheckEquals('text', aAction.Get('type', ''), 'Тип действия');
    CheckEquals('Click Me', aAction.Get('label', ''), 'Текст кнопки');
    CheckEquals('{"cmd":"test"}', aAction.Get('payload', ''), 'Payload кнопки');
  finally
    aJSON.Free;
  end;
end;

procedure TKeyboardTests.TestAddRow;
var
  aButtons: TJSONArray;
  aJSON: TJSONObject;
begin
  fKeyboard.AddButton('Button 1');
  fKeyboard.AddRow;
  fKeyboard.AddButton('Button 2');

  aJSON := GetJSON(fKeyboard.Build) as TJSONObject;
  try
    aButtons := aJSON.Arrays['buttons'];
    CheckEquals(2, aButtons.Count, 'Должно быть две строки');

    CheckEquals(1, (aButtons.Items[0] as TJSONArray).Count, 'В первой строке одна кнопка');
    CheckEquals(1, (aButtons.Items[1] as TJSONArray).Count, 'Во второй строке одна кнопка');
  finally
    aJSON.Free;
  end;
end;

procedure TKeyboardTests.TestBuildWithPayload;
var
  aJSON: TJSONObject;
  aButtons: TJSONArray;
  aFirstRow: TJSONArray;
  aButton: TJSONObject;
  aAction: TJSONObject;
begin
  fKeyboard.AddButton('Test', bcSecondary, '{"action":"test"}');

  aJSON := GetJSON(fKeyboard.Build) as TJSONObject;
  try
    aButtons := aJSON.Arrays['buttons'];
    aFirstRow := aButtons.Items[0] as TJSONArray;
    aButton := aFirstRow.Items[0] as TJSONObject;
    aAction := aButton.Find('action') as TJSONObject;

    CheckEquals('{"action":"test"}', aAction.Get('payload', ''), 'Payload должен быть установлен');
  finally
    aJSON.Free;
  end;
end;

procedure TKeyboardTests.TestOneTimeAndInlineFlags;
var
  aKB: TVKKeyboard;
  aJSON: TJSONObject;
begin
  aKB := TVKKeyboard.Create(True, True);
  try
    aKB.AddButton('Test');
    aJSON := GetJSON(aKB.Build) as TJSONObject;
    try
      CheckEquals(True, aJSON.Get('one_time', False), 'one_time флаг должен быть True');
      CheckEquals(True, aJSON.Get('inline', False), 'inline флаг должен быть True');
    finally
      aJSON.Free;
    end;
  finally
    aKB.Free;
  end;
end;

{ TBotCommandTests }

procedure TBotCommandTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fCommandCalled := False;
  fHandlerCalled := False;
  SetLength(fLastArgs, 0);
end;

procedure TBotCommandTests.TearDown;
begin
  fBot.Free;
end;

procedure TBotCommandTests.DummyCommandHandler(const aMessage: TVKMessage; const AArgs: TStringArray);
begin
  fCommandCalled := True;
  fLastArgs := AArgs;
end;

procedure TBotCommandTests.DummyMessageHandler(const aMsg: TVKMessage);
begin
  fHandlerCalled := True;
  fReceivedText := aMsg.Text;
  fReceivedPeerID := aMsg.PeerID;
end;

procedure TBotCommandTests.RunMethodProcessMessage;
begin
  fBot.ProcessMessage(fMsgData);
end;

procedure TBotCommandTests.PayloadCommandHandler(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  fCommandCalled := True;
  fLastArgs := aArgs;
end;

procedure TBotCommandTests.TestPayloadCommandHandling;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['start']:=@PayloadCommandHandler;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', 'Начать');
    aMsgData.Add('payload', '{"command":"start"}');
    aMsgData.Add('peer_id', Int64(123));

    fBot.ProcessMessage(aMsgData);

    CheckTrue(fCommandCalled, 'Команда из payload должна быть вызвана');
    CheckEquals(0, Length(fLastArgs), 'У команды из payload не должно быть аргументов');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotCommandTests.TestPayloadCommandCaseInsensitive;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['HELP']:=@PayloadCommandHandler;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', 'Помощь');
    aMsgData.Add('payload', '{"command":"help"}'); // lowercase в payload
    aMsgData.Add('peer_id', Int64(456));

    fBot.ProcessMessage(aMsgData);

    CheckTrue(fCommandCalled, 'Регистр команды в payload не должен иметь значения');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotCommandTests.TestPayloadWithInvalidJSON;
begin
  fBot.CommandHandlers['test']:=@PayloadCommandHandler;

  fMsgData := TJSONObject.Create;
  try
    fMsgData.Add('text', 'Test');
    fMsgData.Add('payload', '{invalid json}'); // Невалидный JSON
    fMsgData.Add('peer_id', Int64(789));

    // Не должно вызвать исключение
    CheckException(@RunMethodProcessMessage, Exception, 'Невалидный payload не должен ломать обработку');
  finally
    FreeAndNil(fMsgData);
  end;
end;

procedure TBotCommandTests.TestPayloadWithoutCommandField;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['test']:=@PayloadCommandHandler;
  fBot.AddMessageHandler(@DummyMessageHandler);

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', 'Hello');
    aMsgData.Add('payload', '{"action":"click","data":123}'); // Нет поля "command"
    aMsgData.Add('peer_id', Int64(111));

    fBot.ProcessMessage(aMsgData);

    CheckFalse(fCommandCalled, 'Payload без команды не должен запускать command-хендлер');
    CheckTrue(fHandlerCalled, 'Но должен запустить обычный message-хендлер');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotCommandTests.UnknownHandler(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  fHandlerCalled := True;
end;

procedure TBotCommandTests.TestOnCommandRegistration;
begin
  fBot.CommandHandlers['test']:=@DummyCommandHandler;
  CheckTrue(fBot.CommandMap.Contains('test'), 'Команда должна быть зарегистрирована');
end;

procedure TBotCommandTests.TestCommandWithArgs;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['start']:=@DummyCommandHandler;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', '/start arg1 arg2');
    aMsgData.Add('peer_id', Int64(123));

    fBot.ProcessMessage(aMsgData);

    CheckTrue(fCommandCalled, 'Команда должна быть вызвана');
    CheckEquals(2, Length(fLastArgs), 'Должно быть 2 аргумента');
    CheckEquals('arg1', fLastArgs[0], 'Первый аргумент');
    CheckEquals('arg2', fLastArgs[1], 'Второй аргумент');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotCommandTests.TestCommandCaseInsensitive;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['help']:=@DummyCommandHandler;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', '/HELP');
    aMsgData.Add('peer_id', Int64(123));

    fBot.ProcessMessage(aMsgData);

    CheckTrue(fCommandCalled, 'Команда должна работать независимо от регистра');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotCommandTests.TestUnknownCommandNotHandled;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['known']:=@DummyCommandHandler;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', '/unknown');
    aMsgData.Add('peer_id', Int64(123));

    fBot.ProcessMessage(aMsgData);

    CheckFalse(fCommandCalled, 'Неизвестная команда не должна вызвать обработчик');
  finally
    aMsgData.Free;
  end;
end;

{ TBotMessageHandlerTests }

procedure TBotMessageHandlerTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fCmdCalled := False;
  fHandlerCalled := False;
  fReceivedPeerID := 0;
  fReceivedText := '';
end;

procedure TBotMessageHandlerTests.TearDown;
begin
  fBot.Free;
end;

procedure TBotMessageHandlerTests.DummyMessageHandler(const aMsg: TVKMessage);
begin
  fHandlerCalled := True;
  fReceivedText := aMsg.Text;
  fReceivedPeerID := aMsg.PeerID;
end;

procedure TBotMessageHandlerTests.TestCmd(const Msg: TVKMessage; const Args: TStringArray);
begin
  fCmdCalled := True;
end;

procedure TBotMessageHandlerTests.TestOnMessageRegistration;
begin
  fBot.AddMessageHandler(@DummyMessageHandler);
  CheckEquals(1, fBot.MessageHandlers.Size, 'Обработчик сообщений должен быть зарегистрирован');
end;

procedure TBotMessageHandlerTests.TestMessageHandlerCalledForNonCommand;
var
  aMsgData: TJSONObject;
begin
  fBot.AddMessageHandler(@DummyMessageHandler);

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', 'Hello, world!');
    aMsgData.Add('peer_id', Int64(456));

    fBot.ProcessMessage(aMsgData);

    CheckTrue(fHandlerCalled, 'Обработчик сообщений должен быть вызван');
    CheckEquals('Hello, world!', fReceivedText, 'Текст сообщения должен совпадать');
    CheckEquals(Int64(456), fReceivedPeerID, 'PeerID должен совпадать');
  finally
    aMsgData.Free;
  end;
end;

procedure TBotMessageHandlerTests.TestMessageHandlerNotCalledForHandledCommand;
var
  aMsgData: TJSONObject;
begin
  fCmdCalled := False;
  fHandlerCalled := False;

  fBot.CommandHandlers['test']:=@TestCmd;
  fBot.AddMessageHandler(@DummyMessageHandler);

  aMsgData := TJSONObject.Create;
  aMsgData.Add('text', '/test');
  aMsgData.Add('peer_id', Int64(123));

  fBot.ProcessMessage(aMsgData);
  aMsgData.Free;

  CheckTrue(fCmdCalled, 'Команда должна быть обработана');
  CheckFalse(FHandlerCalled, 'Обычный обработчик не должен сработать для команды');
end;

{ TBotEventTests }

procedure TBotEventTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 123456);
  fEventCalled := False;
  fReceivedEvent := nil;
end;

procedure TBotEventTests.TearDown;
begin
  fBot.Free;
  fReceivedEvent.Free;
end;

procedure TBotEventTests.DummyEventHandler(const aEvent: TJSONObject);
begin
  fEventCalled := True;
  fReceivedEvent := TJSONObject(aEvent.Clone);
end;

{ TBotEventTests }

procedure TBotEventTests.TestOnEventRegistration;
begin
  fBot.EventHandlers[etPhotoNew]:=@DummyEventHandler;
  CheckTrue(fBot.EventMap.Contains(etPhotoNew), 'Событие etPhotoNew должно быть зарегистрировано');

  fBot.EventHandlersByName['custom_event_xyz']:=@DummyEventHandler;
  CheckTrue(fBot.EventMap.Contains(etUnknown), 'Неизвестное событие должно мапиться в etUnknown');
end;

procedure TBotEventTests.TestProcessEventUnknownType;
var
  aUpdate: TJSONObject;
  aObj: TJSONObject;
begin
  fBot.EventHandlers[etWallPostNew]:=@DummyEventHandler;

  aUpdate := TJSONObject.Create;
  try
    aUpdate.Add('type', 'some_unknown_event_type');
    aObj := TJSONObject.Create;
    aObj.Add('data', 'test');
    aUpdate.Add('object', aObj);

    fBot.ProcessUpdate(aUpdate);

    CheckFalse(fEventCalled, 'Обработчик не должен вызваться для неизвестного типа');
  finally
    aUpdate.Free;
  end;
end;

{ TAPICallTests }

procedure TAPICallTests.SetUp;
begin
  fBot := TMockVKBot.Create('test_token_abc', 999888);
end;

procedure TAPICallTests.TearDown;
begin
  fBot.Free;
end;

procedure TAPICallTests.TestAPICallURLFormat;
var
  aLastURL: string;
begin
  // Настраиваем мок для ответа
  TMockHTTPClient.SetDefaultResponse('{"response":{"ok":true}}');

  // Делаем вызов
  fBot.SendMessage(12345, 'Test message');

  // Проверяем, что запрос был сделан
  CheckTrue(TMockHTTPClient.GetCallCount > 0, 'Должен быть хотя бы один HTTP вызов');

  aLastURL := TMockHTTPClient.GetLastURL;

  // Проверяем формат URL
  CheckTrue(Pos('https://api.vk.com/method/', aLastURL) > 0, 'URL должен содержать базовый путь API');
  CheckTrue(Pos('access_token=test_token_abc', aLastURL) > 0, 'URL должен содержать токен');
  CheckTrue(Pos('v=5.199', aLastURL) > 0, 'URL должен содержать версию API');
  CheckTrue(Pos('messages.send', aLastURL) > 0, 'URL должен содержать метод messages.send');
end;

procedure TAPICallTests.TestAPICallWithParams;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{"ok":true}}');

  fBot.SendMessage(67890, 'Hello, World!');

  aLastURL := TMockHTTPClient.GetLastURL;

  // Проверяем параметры в URL
  CheckTrue(Pos('peer_id=67890', aLastURL) > 0, 'URL должен содержать peer_id');
  CheckTrue(Pos('message=Hello', aLastURL) > 0, 'URL должен содержать текст сообщения');
  CheckTrue(Pos('random_id=', aLastURL) > 0, 'URL должен содержать random_id');
end;

procedure TAPICallTests.TestSendMessageSuccess;
var
  aResult: Boolean;
begin
  // Настраиваем успешный ответ
  TMockHTTPClient.AddResponse('messages.send', '{"response":1234}');

  aResult := fBot.SendMessage(123, 'Test');

  CheckTrue(aResult, 'SendMessage должен вернуть True при успешном ответе');
  CheckTrue(TMockHTTPClient.WasCalled('messages.send'), 'Метод messages.send должен быть вызван');
end;

procedure TAPICallTests.TestSendMessageWithKeyboard;
var
  aKeyboard: TVKKeyboard;
  aKeyboardJSON: string;
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":5678}');

  aKeyboard := TVKKeyboard.Create;
  try
    aKeyboard.AddButton('Button 1');
    aKeyboardJSON := aKeyboard.Build;

    fBot.SendMessage(999, 'Choose option', aKeyboardJSON);

    aLastURL := TMockHTTPClient.GetLastURL;
    CheckTrue(Pos('keyboard=', aLastURL) > 0, 'URL должен содержать параметр keyboard');
  finally
    aKeyboard.Free;
  end;
end;

procedure TAPICallTests.TestAPICallReturnsCorrectData;
var
  aParams: TJSONObject;
begin
  // Создаем JSON с ожидаемым ответом
  TMockHTTPClient.AddResponse('test.method', '{"response":{"user_id":12345,"name":"Test User"}}');

  aParams := TJSONObject.Create;
  try
    aParams.Add('test_param', 'value');
    fBot.SendMessage(111, 'test'); // Используем публичный метод

    CheckTrue(TMockHTTPClient.WasCalled('messages.send'), 'API должен быть вызван');
  finally
    aParams.Free;
  end;
end;

procedure TAPICallTests.TestMultipleAPICallsLogged;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{}}');

  fBot.SendMessage(1, 'Message 1');
  fBot.SendMessage(2, 'Message 2');
  fBot.SendMessage(3, 'Message 3');

  CheckEquals(3, TMockHTTPClient.GetCallCount, 'Должно быть 3 API вызова');

  // Проверяем, что каждый вызов залогирован
  CheckTrue(Pos('peer_id=1', TMockHTTPClient.GetCall(0)) > 0, 'Первый вызов с peer_id=1');
  CheckTrue(Pos('peer_id=2', TMockHTTPClient.GetCall(1)) > 0, 'Второй вызов с peer_id=2');
  CheckTrue(Pos('peer_id=3', TMockHTTPClient.GetCall(2)) > 0, 'Третий вызов с peer_id=3');
end;

{ TIntegrationTests }

procedure TIntegrationTests.DummyEventHandler(const aEvent: TJSONObject);
begin
  fEventCalled := True;
  fReceivedEvent := TJSONObject(aEvent.Clone);
end;

procedure TIntegrationTests.HandleMessage(const aMsg: TVKMessage);
begin
  fMessageReceived := True;
  fReceivedText := aMsg.Text;
  aMsg.Reply('Auto reply: ' + aMsg.Text);
end;

procedure TIntegrationTests.HandleCommand(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  aMsg.Reply('Command executed');
end;

procedure TIntegrationTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 12345);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fMessageReceived := False;
  fReceivedText := EmptyStr;
  fEventCalled := False;
  fReceivedEvent := nil;
end;

procedure TIntegrationTests.TearDown;
begin
  fReceivedEvent.Free;
  fBot.Free;
end;

procedure TIntegrationTests.TestCommandTriggersAPICall;
var
  aMsgData: TJSONObject;
begin
  fBot.CommandHandlers['test']:=@HandleCommand;

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', '/test arg1 arg2');
    aMsgData.Add('peer_id', Int64(999));

    TMockHTTPClient.ClearCalls;
    fBot.ProcessMessage(aMsgData);

    // Проверяем, что команда вызвала отправку сообщения
    CheckEquals(1, TMockHTTPClient.GetCallCount, 'Команда должна вызвать SendMessage');
    CheckTrue(TMockHTTPClient.WasCalled(EncodeURLElement('Command executed')), 'Должен отправить ответ команды');
  finally
    aMsgData.Free;
  end;
end;

procedure TIntegrationTests.TestMessageHandlerTriggersReply;
var
  aMsgData: TJSONObject;
begin
  fBot.AddMessageHandler(@HandleMessage);

  aMsgData := TJSONObject.Create;
  try
    aMsgData.Add('text', 'Hello bot');
    aMsgData.Add('peer_id', Int64(888));

    TMockHTTPClient.ClearCalls;
    fBot.ProcessMessage(aMsgData);

    CheckTrue(fMessageReceived, 'Обработчик сообщений должен быть вызван');
    CheckEquals('Hello bot', fReceivedText, 'Текст сообщения должен совпадать');
    CheckEquals(1, TMockHTTPClient.GetCallCount, 'Должен быть один вызов API (Reply)');
    CheckTrue(TMockHTTPClient.WasCalled(EncodeURLElement('Auto reply')), 'Должен отправить авто-ответ');
  finally
    aMsgData.Free;
  end;
end;

procedure TIntegrationTests.TestEventProcessing;
var
  aUpdate: TJSONObject;
  aEventObj: TJSONObject;
begin
  fBot.EventHandlers[etPhotoNew]:=@DummyEventHandler;

  aUpdate := TJSONObject.Create;
  try
    aUpdate.Add('type', 'photo_new');

    aEventObj := TJSONObject.Create;
    aEventObj.Add('photo_id', 12345);
    aUpdate.Add('object', aEventObj);

    fBot.ProcessUpdate(aUpdate);

    CheckTrue(fEventCalled, 'Обработчик etPhotoNew должен сработать');
    CheckNotNull(fReceivedEvent, 'Данные события должны быть переданы');
  finally
    aUpdate.Free;
  end;
end;

{ TEventTypeHelperTests }

procedure TEventTypeHelperTests.TestStringToEnum_KnownTypes;
begin
  CheckEquals(Ord(etMessageNew), Ord(VKEventTypeFromString('message_new')));
  CheckEquals(Ord(etPhotoNew), Ord(VKEventTypeFromString('photo_new')));
  CheckEquals(Ord(etWallPostNew), Ord(VKEventTypeFromString('wall_post_new')));
  CheckEquals(Ord(etGroupJoin), Ord(VKEventTypeFromString('group_join')));
end;

procedure TEventTypeHelperTests.TestStringToEnum_UnknownType;
begin
  CheckEquals(Ord(etUnknown), Ord(VKEventTypeFromString('')));
  CheckEquals(Ord(etUnknown), Ord(VKEventTypeFromString('nonexistent_event')));
  CheckEquals(Ord(etUnknown), Ord(VKEventTypeFromString('message_new_typo')));
end;

procedure TEventTypeHelperTests.TestEnumToString_RoundTrip;
var
  aType: TVKEventType;
begin
  for aType := Low(TVKEventType) to High(TVKEventType) do
  begin
    if aType <> etUnknown then
      CheckEquals(Ord(aType), Ord(VKEventTypeFromString(VKEventTypeToString(aType))),
        Format('Round-trip failed for %d', [Ord(aType)]));
  end;
end;

procedure TEventTypeHelperTests.TestStringToEnum_CaseSensitivity;
begin
  CheckEquals(Ord(etMessageNew), Ord(VKEventTypeFromString('message_new')));
  CheckEquals(Ord(etUnknown), Ord(VKEventTypeFromString('Message_New')));
  CheckEquals(Ord(etUnknown), Ord(VKEventTypeFromString('MESSAGE_NEW')));
end;

initialization
  RegisterTest(TEventTypeHelperTests);
  RegisterTest(TMessageTests);
  RegisterTest(TKeyboardTests);
  RegisterTest(TBotCommandTests);
  RegisterTest(TBotMessageHandlerTests);
  RegisterTest(TBotEventTests);
  RegisterTest(TAPICallTests);
  RegisterTest(TIntegrationTests);

end.
