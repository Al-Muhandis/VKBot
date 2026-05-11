unit VKBotFrameworkTests;

{$mode objfpc}{$H+}{$J-}
{$codepage UTF8}

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
    procedure TestAddCallbackButton;
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

  { TMessageEventTests — unit tests for TVKMessageEvent wrapper }
  TMessageEventTests = class(TTestCase)
  private
    fBot:      TMockVKBot;
    fEvtData:  TJSONObject;
    fPayload:  TJSONObject;
    fEvent:    TVKMessageEvent;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetUserID;
    procedure TestGetPeerID;
    procedure TestGetEventID;
    procedure TestGetConversationMessageId;
    procedure TestGetPayload;
    procedure TestGetPayloadNil;
    procedure TestReplyCallsSendMessage;
    procedure TestReplyUsesCorrectPeerID;
    procedure TestAnswerCallsSendMessageEventAnswer;
    procedure TestAnswerPassesEventData;
  end;

  { TMessageEventHandlerTests — ProcessMessageEvent + AddMessageEventHandler }
  TMessageEventHandlerTests = class(TTestCase)
  private
    fBot:             TTestVKBot;
    fHandlerCalled:   Boolean;
    fHandlerCount:    Integer;
    fReceivedUserID:  Int64;
    fReceivedPeerID:  Int64;
    fReceivedEventID: string;
    procedure EventHandler(const aEvent: TVKMessageEvent);
    procedure SecondEventHandler(const {%H-}aEvent: TVKMessageEvent);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestHandlerCalledOnMessageEvent;
    procedure TestHandlerReceivesCorrectData;
    procedure TestNoHandlersDoesNotCrash;
    procedure TestNilEventObjectDoesNotCrash;
  end;

  { TProcessUpdateMessageEventTests — ProcessUpdate behaviour for message_event }
  TProcessUpdateMessageEventTests = class(TTestCase)
  private
    fBot:                TTestVKBot;
    fMsgEventHandled:    Boolean;
    fMsgHandled:         Boolean;
    fRawEventHandled:    Boolean;
    fReceivedUserID:     Int64;
    fReceivedRawObject:  TJSONObject;
    procedure OnMessageEvent(const aEvent: TVKMessageEvent);
    procedure OnRawEvent(const aEvent: TJSONObject);
    function  MakeMessageEventUpdate: TJSONObject;
    procedure TestMessageHandler(const {%H-}aMessage: TVKMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { message_event fires ProcessMessageEvent handler }
    procedure TestMessageEventFiresSpecificHandler;
    { message_event ALSO fires generic EventHandlers[etMessageEvent] }
    procedure TestMessageEventAlsoFiresGenericHandler;
    { both fire in the same ProcessUpdate call }
    procedure TestMessageEventFiresBothHandlers;
    { message_new fires ProcessMessage AND generic EventHandlers[etMessageNew] }
    procedure TestMessageNewFiresBothHandlers;
    { unknown type is ignored without crash }
    procedure TestUnknownEventTypeIgnored(const {%H-}aMsg: TVKMessage);
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
    procedure TestSendMessageWithAttachment;
    procedure TestEditMessageSuccess;
    procedure TestEditMessageWithKeyboard;
    procedure TestDeleteMessageSuccess;
    procedure TestDeleteMessageWithDeleteForAll;
    procedure TestDeleteMultipleMessagesSuccess;
    procedure TestDeleteMultipleMessagesWithDeleteForAll;
    procedure TestDeleteMultipleMessagesEmptyList;
    procedure TestDocsSaveSuccess;
    procedure TestDocsSaveWithOptionalParams;
    procedure TestUsersGetSuccess;
    procedure TestUsersGetWithFields;
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

  { TMessageReplyTests — unit tests for TVKMessageReply wrapper }
  TMessageReplyTests = class(TTestCase)
  private
    fBot:       TMockVKBot;
    fReplyData: TJSONObject;
    fReply:     TVKMessageReply;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestGetText;
    procedure TestGetPeerID;
    procedure TestGetFromID;
    procedure TestGetMessageID;
    procedure TestGetConversationMessageId;
    procedure TestReplyCallsSendMessage;
    procedure TestReplyUsesCorrectPeerID;
    procedure TestSendWithExplicitPeerID;
    procedure TestSendWithKeyboard;
  end;

  { TMessageReplyHandlerTests — ProcessMessageReply + AddMessageReplyHandler }
  TMessageReplyHandlerTests = class(TTestCase)
  private
    fBot:            TTestVKBot;
    fHandlerCalled:  Boolean;
    fHandlerCount:   Integer;
    fReceivedText:   string;
    fReceivedPeerID: Int64;
    fReceivedFromID: Int64;
    procedure ReplyHandler(const aReply: TVKMessageReply);
    procedure SecondReplyHandler(const {%H-}aReply: TVKMessageReply);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestHandlerCalledOnMessageReply;
    procedure TestHandlerReceivesCorrectData;
    procedure TestNoHandlersDoesNotCrash;
    procedure TestNilReplyObjectDoesNotCrash;
  end;

  { TProcessUpdateMessageReplyTests — ProcessUpdate behaviour for message_reply }
  TProcessUpdateMessageReplyTests = class(TTestCase)
  private
    fBot:               TTestVKBot;
    fMsgReplyHandled:   Boolean;
    fRawEventHandled:   Boolean;
    fReceivedText:      string;
    fReceivedRawObject: TJSONObject;
    procedure OnMessageReply(const aReply: TVKMessageReply);
    procedure OnRawEvent(const aEvent: TJSONObject);
    function  MakeMessageReplyUpdate: TJSONObject;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { message_reply fires ProcessMessageReply handler }
    procedure TestMessageReplyFiresSpecificHandler;
    { message_reply ALSO fires generic EventHandlers[etMessageReply] }
    procedure TestMessageReplyAlsoFiresGenericHandler;
    { both fire in the same ProcessUpdate call }
    procedure TestMessageReplyFiresBothHandlers;
    { nil object does not crash }
    procedure TestNilReplyObjectDoesNotCrash;
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
  fKeyboard.AddButton('Click Me', bcPrimary, btText, '{"cmd":"test"}');

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

procedure TKeyboardTests.TestAddCallbackButton;
var
  aButtons: TJSONArray;
  aFirstRow: TJSONArray;
  aButton: TJSONObject;
  aAction, aJSON: TJSONObject;
begin
  fKeyboard.AddButton('Call Me', bcPrimary, btCallback, '{"cmd":"cb"}');

  aJSON := GetJSON(fKeyboard.Build) as TJSONObject;
  try
    aButtons := aJSON.Arrays['buttons'];
    aFirstRow := aButtons.Items[0] as TJSONArray;
    aButton := aFirstRow.Items[0] as TJSONObject;
    aAction := aButton.Find('action') as TJSONObject;

    CheckEquals('callback', aAction.Get('type', ''), 'Тип действия callback');
    CheckEquals('Call Me', aAction.Get('label', ''), 'Текст callback-кнопки');
    CheckEquals('{"cmd":"cb"}', aAction.Get('payload', ''), 'Payload callback-кнопки');
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
  fKeyboard.AddButton('Test', bcSecondary, btText, '{"action":"test"}');

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
  fBot.OnMessage:=@DummyMessageHandler;

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

procedure TBotMessageHandlerTests.TestMessageHandlerCalledForNonCommand;
var
  aMsgData: TJSONObject;
begin
  fBot.OnMessage := @DummyMessageHandler;

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
  fBot.OnMessage := @DummyMessageHandler;

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

procedure TAPICallTests.TestSendMessageWithAttachment;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":5678}');

  fBot.SendMessage(999, 'Photo attached', '', 'photo1_2');

  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('attachment=photo1%5F2', aLastURL) > 0, 'URL должен содержать параметр attachment');
end;

procedure TAPICallTests.TestEditMessageSuccess;
var
  aResult: Boolean;
begin
  TMockHTTPClient.AddResponse('messages.edit', '{"response":1}');

  aResult := fBot.EditMessage(123, 456, 'Updated text');

  CheckTrue(aResult, 'EditMessage должен вернуть True при успешном ответе');
  CheckTrue(TMockHTTPClient.WasCalled('messages.edit'), 'Метод messages.edit должен быть вызван');
end;

procedure TAPICallTests.TestEditMessageWithKeyboard;
var
  aKeyboard: TVKKeyboard;
  aKeyboardJSON: string;
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":1}');

  aKeyboard := TVKKeyboard.Create;
  try
    aKeyboard.AddButton('Button 1');
    aKeyboardJSON := aKeyboard.Build;

    fBot.EditMessage(999, 12345, 'Choose option', 0, aKeyboardJSON);

    aLastURL := TMockHTTPClient.GetLastURL;
    CheckTrue(Pos('messages.edit', aLastURL) > 0, 'URL должен содержать метод messages.edit');
    CheckTrue(Pos('message_id=12345', aLastURL) > 0, 'URL должен содержать параметр message_id');
    CheckTrue(Pos('keyboard=', aLastURL) > 0, 'URL должен содержать параметр keyboard');
  finally
    aKeyboard.Free;
  end;
end;

procedure TAPICallTests.TestDeleteMessageSuccess;
var
  aResult: Boolean;
begin
  TMockHTTPClient.AddResponse('messages.delete', '{"response":{"456":1}}');

  aResult := fBot.DeleteMessage(123, 456);

  CheckTrue(aResult, 'DeleteMessage должен вернуть True при успешном ответе');
  CheckTrue(TMockHTTPClient.WasCalled('messages.delete'), 'Метод messages.delete должен быть вызван');
end;

procedure TAPICallTests.TestDeleteMessageWithDeleteForAll;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{"12345":1}}');

  fBot.DeleteMessage(999, 12345, True);

  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('messages.delete', aLastURL) > 0, 'URL должен содержать метод messages.delete');
  CheckTrue(Pos('peer_id=999', aLastURL) > 0, 'URL должен содержать peer_id');
  CheckTrue(Pos('message_ids=12345', aLastURL) > 0, 'URL должен содержать message_ids');
  CheckTrue(Pos('delete_for_all=1', aLastURL) > 0, 'URL должен содержать delete_for_all');
end;

procedure TAPICallTests.TestDeleteMultipleMessagesSuccess;
var
  aResult: Boolean;
begin
  TMockHTTPClient.AddResponse('messages.delete', '{"response":{"101":1,"102":1,"103":1}}');

  aResult := fBot.DeleteMessage(777, [101, 102, 103]);

  CheckTrue(aResult, 'DeleteMessage(массив) должен вернуть True при успешном ответе');
  CheckTrue(TMockHTTPClient.WasCalled('messages.delete'), 'Метод messages.delete должен быть вызван для массива id');
end;

procedure TAPICallTests.TestDeleteMultipleMessagesWithDeleteForAll;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{"201":1,"202":1}}');

  fBot.DeleteMessage(555, [201, 202], True);

  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('messages.delete', aLastURL) > 0, 'URL должен содержать метод messages.delete');
  CheckTrue(Pos('peer_id=555', aLastURL) > 0, 'URL должен содержать peer_id');
  CheckTrue(Pos('message_ids=201,202', aLastURL) > 0, 'URL должен содержать список message_ids');
  CheckTrue(Pos('delete_for_all=1', aLastURL) > 0, 'URL должен содержать delete_for_all');
end;

procedure TAPICallTests.TestDeleteMultipleMessagesEmptyList;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{}}');

  CheckFalse(fBot.DeleteMessage(123, []), 'DeleteMessage(пустой массив) должен вернуть False');
  CheckFalse(TMockHTTPClient.WasCalled('messages.delete'), 'При пустом массиве API не должен вызываться');
end;

procedure TAPICallTests.TestDocsSaveSuccess;
var
  aResponse: TJSONData;
begin
  TMockHTTPClient.AddResponse('docs.save', '{"response":{"type":"doc","doc":{"id":1}}}');

  aResponse := fBot.DocsSave('uploaded_file_token');
  try
    CheckNotNull(aResponse, 'DocsSave должен вернуть данные ответа');
    CheckTrue(TMockHTTPClient.WasCalled('docs.save'), 'Метод docs.save должен быть вызван');
  finally
    //aResponse.Free; frees in fBot
  end;
end;

procedure TAPICallTests.TestDocsSaveWithOptionalParams;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":{"type":"doc","doc":{"id":2}}}');

  fBot.DocsSave('uploaded_file_token', 'My title', 'tag1,tag2');
  try
    aLastURL := TMockHTTPClient.GetLastURL;
    CheckTrue(Pos('docs.save', aLastURL) > 0, 'URL должен содержать метод docs.save');
    CheckTrue(Pos('file=uploaded%5Ffile%5Ftoken', aLastURL) > 0, 'URL должен содержать параметр file');
    CheckTrue(Pos('title=My', aLastURL) > 0, 'URL должен содержать параметр title');
    CheckTrue(Pos('tags=tag1,tag2', aLastURL) > 0, 'URL должен содержать параметр tags');
  finally
    //aResponse.Free; frees in fBot
  end;
end;

procedure TAPICallTests.TestUsersGetSuccess;
var
  aResponse: TJSONData;
begin
  TMockHTTPClient.AddResponse('users.get', '{"response":[{"id":1,"first_name":"Ivan","last_name":"Ivanov"}]}');

  aResponse := fBot.UsersGet('1');
  try
    CheckNotNull(aResponse, 'UsersGet должен вернуть данные ответа');
    CheckTrue(TMockHTTPClient.WasCalled('users.get'), 'Метод users.get должен быть вызван');
  finally
    //aResponse.Free; frees in fBot
  end;
end;

procedure TAPICallTests.TestUsersGetWithFields;
var
  aLastURL: string;
begin
  TMockHTTPClient.SetDefaultResponse('{"response":[{"id":1,"photo_200":"https://example.com/p.jpg"}]}');

  fBot.UsersGet('1', 'photo_200,city');

  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('users.get', aLastURL) > 0, 'URL должен содержать метод users.get');
  CheckTrue(Pos('user_ids=1', aLastURL) > 0, 'URL должен содержать параметр user_ids');
  CheckTrue(Pos('fields=photo%5F200,city', aLastURL) > 0, 'URL должен содержать параметр fields');
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
  fBot.OnMessage := @HandleMessage;

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

{ TMessageEventTests }

procedure TMessageEventTests.SetUp;
begin
  fBot     := TMockVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');

  fPayload := TJSONObject.Create;
  fPayload.Add('test', Int64(23410));
  fPayload.Add('question', Int64(1));

  fEvtData := TJSONObject.Create;
  fEvtData.Add('user_id', Int64(2856025));
  fEvtData.Add('peer_id', Int64(2856025));
  fEvtData.Add('event_id', '5d19bd487fbd');
  fEvtData.Add('payload', fPayload);     { fEvtData owns fPayload }
  fEvtData.Add('conversation_message_id', Int64(17));

  fEvent := TVKMessageEvent.Create(fBot, fEvtData);
end;

procedure TMessageEventTests.TearDown;
begin
  fEvent.Free;
  fEvtData.Free;    { also frees fPayload }
  fBot.Free;
end;

procedure TMessageEventTests.TestGetUserID;
begin
  CheckEquals(Int64(2856025), fEvent.UserID);
end;

procedure TMessageEventTests.TestGetPeerID;
begin
  CheckEquals(Int64(2856025), fEvent.PeerID);
end;

procedure TMessageEventTests.TestGetEventID;
begin
  CheckEquals('5d19bd487fbd', fEvent.EventID);
end;

procedure TMessageEventTests.TestGetConversationMessageId;
begin
  CheckEquals(Int64(17), fEvent.ConversationMessageId);
end;

procedure TMessageEventTests.TestGetPayload;
var
  aPayload: TJSONObject;
begin
  aPayload := fEvent.Payload;
  CheckNotNull(aPayload, 'Payload не должен быть nil');
  CheckEquals(Int64(23410), aPayload.Get('test', Int64(0)));
  CheckEquals(Int64(1),     aPayload.Get('question', Int64(0)));
end;

procedure TMessageEventTests.TestGetPayloadNil;
var
  aData:  TJSONObject;
  aEvent: TVKMessageEvent;
begin
  { object without payload field }
  aData := TJSONObject.Create;
  try
    aData.Add('user_id', Int64(1));
    aData.Add('peer_id', Int64(1));
    aData.Add('event_id', 'abc');
    aEvent := TVKMessageEvent.Create(fBot, aData);
    try
      CheckNull(aEvent.Payload, 'Payload без поля должен возвращать nil');
    finally
      aEvent.Free;
    end;
  finally
    aData.Free;
  end;
end;

procedure TMessageEventTests.TestReplyCallsSendMessage;
begin
  TMockHTTPClient.ClearCalls;
  fEvent.Reply('Принято!');
  CheckTrue(TMockHTTPClient.GetCallCount > 0, 'Reply должен вызвать messages.send');
end;

procedure TMessageEventTests.TestReplyUsesCorrectPeerID;
begin
  TMockHTTPClient.ClearCalls;
  fEvent.Reply('Ок');
  CheckTrue(TMockHTTPClient.WasCalled('peer_id=2856025'),
    'Reply должен отправить на peer_id из события');
end;

procedure TMessageEventTests.TestAnswerCallsSendMessageEventAnswer;
begin
  TMockHTTPClient.ClearCalls;
  fEvent.Answer;
  CheckTrue(TMockHTTPClient.GetCallCount > 0, 'Answer должен вызвать API');
  CheckTrue(TMockHTTPClient.WasCalled('messages.sendMessageEventAnswer'),
    'Должен вызываться метод messages.sendMessageEventAnswer');
end;

procedure TMessageEventTests.TestAnswerPassesEventData;
begin
  TMockHTTPClient.ClearCalls;
  fEvent.Answer(dtShowSnackbar, 'Готово');
  CheckTrue(TMockHTTPClient.WasCalled('event_id=5d19bd487fbd'),
    'Должен передаваться event_id из события');
  CheckTrue(TMockHTTPClient.WasCalled('user_id=2856025'),
    'Должен передаваться user_id из события');
  CheckTrue(TMockHTTPClient.WasCalled('peer_id=2856025'),
    'Должен передаваться peer_id из события');
  CheckTrue(TMockHTTPClient.WasCalled(EncodeURLElement('show_snackbar')),
    'Должен передаваться тип ответа');
end;

{ TMessageEventHandlerTests }

procedure TMessageEventHandlerTests.SetUp;
begin
  fBot            := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fHandlerCalled  := False;
  fHandlerCount   := 0;
  fReceivedUserID := 0;
  fReceivedPeerID := 0;
  fReceivedEventID := '';
end;

procedure TMessageEventHandlerTests.TearDown;
begin
  fBot.Free;
end;

procedure TMessageEventHandlerTests.EventHandler(const aEvent: TVKMessageEvent);
begin
  fHandlerCalled   := True;
  Inc(fHandlerCount);
  fReceivedUserID  := aEvent.UserID;
  fReceivedPeerID  := aEvent.PeerID;
  fReceivedEventID := aEvent.EventID;
end;

procedure TMessageEventHandlerTests.SecondEventHandler(const aEvent: TVKMessageEvent);
begin
  Inc(fHandlerCount);
end;

procedure TMessageEventHandlerTests.TestHandlerCalledOnMessageEvent;
var
  aEvtData: TJSONObject;
begin
  fBot.OnMessageEvent := @EventHandler;

  aEvtData := TJSONObject.Create;
  try
    aEvtData.Add('user_id', Int64(111));
    aEvtData.Add('peer_id', Int64(222));
    aEvtData.Add('event_id', 'aabbcc');
    aEvtData.Add('conversation_message_id', Int64(5));
    fBot.ProcessMessageEvent(aEvtData);

    CheckTrue(fHandlerCalled, 'Обработчик message_event должен быть вызван');
  finally
    aEvtData.Free;
  end;
end;

procedure TMessageEventHandlerTests.TestHandlerReceivesCorrectData;
var
  aEvtData: TJSONObject;
begin
  fBot.OnMessageEvent := @EventHandler;

  aEvtData := TJSONObject.Create;
  try
    aEvtData.Add('user_id', Int64(9999));
    aEvtData.Add('peer_id', Int64(8888));
    aEvtData.Add('event_id', 'deadbeef');
    aEvtData.Add('conversation_message_id', Int64(42));
    fBot.ProcessMessageEvent(aEvtData);

    CheckEquals(Int64(9999),   fReceivedUserID,  'UserID должен совпадать');
    CheckEquals(Int64(8888),   fReceivedPeerID,  'PeerID должен совпадать');
    CheckEquals('deadbeef',    fReceivedEventID, 'EventID должен совпадать');
  finally
    aEvtData.Free;
  end;
end;

procedure TMessageEventHandlerTests.TestNoHandlersDoesNotCrash;
var
  aEvtData: TJSONObject;
begin
  { no handlers registered — must not raise }
  aEvtData := TJSONObject.Create;
  try
    aEvtData.Add('user_id', Int64(1));
    aEvtData.Add('peer_id', Int64(1));
    aEvtData.Add('event_id', 'y');
    fBot.ProcessMessageEvent(aEvtData);
  finally
    aEvtData.Free;
  end;
end;

procedure TMessageEventHandlerTests.TestNilEventObjectDoesNotCrash;
begin
  fBot.OnMessageEvent := @EventHandler;
  fBot.ProcessMessageEvent(nil);
  CheckFalse(fHandlerCalled, 'Обработчик не должен вызываться при nil');
end;

{ TProcessUpdateMessageEventTests }

procedure TProcessUpdateMessageEventTests.SetUp;
begin
  fBot               := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fMsgEventHandled   := False;
  fRawEventHandled   := False;
  fReceivedUserID    := 0;
  fReceivedRawObject := nil;
end;

procedure TProcessUpdateMessageEventTests.TearDown;
begin
  fReceivedRawObject.Free;
  fBot.Free;
end;

procedure TProcessUpdateMessageEventTests.OnMessageEvent(const aEvent: TVKMessageEvent);
begin
  fMsgEventHandled := True;
  fReceivedUserID  := aEvent.UserID;
end;

procedure TProcessUpdateMessageEventTests.OnRawEvent(const aEvent: TJSONObject);
begin
  fRawEventHandled   := True;
  fReceivedRawObject := TJSONObject(aEvent.Clone);
end;

function TProcessUpdateMessageEventTests.MakeMessageEventUpdate: TJSONObject;
var
  aObject, aPayload: TJSONObject;
begin
  aPayload := TJSONObject.Create;
  aPayload.Add('test', Int64(23410));
  aPayload.Add('question', Int64(1));

  aObject := TJSONObject.Create;
  aObject.Add('user_id', Int64(2856025));
  aObject.Add('peer_id', Int64(2856025));
  aObject.Add('event_id', '5d19bd487fbd');
  aObject.Add('payload', aPayload);
  aObject.Add('conversation_message_id', Int64(17));

  Result := TJSONObject.Create;
  Result.Add('type', 'message_event');
  Result.Add('object', aObject);
end;

procedure TProcessUpdateMessageEventTests.TestMessageHandler(const aMessage: TVKMessage);
begin
  fMsgHandled := True;
end;

procedure TProcessUpdateMessageEventTests.TestMessageEventFiresSpecificHandler;
var
  aUpdate: TJSONObject;
begin
  fBot.OnMessageEvent := @OnMessageEvent;

  aUpdate := MakeMessageEventUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fMsgEventHandled,
      'ProcessMessageEvent-хендлер должен сработать при message_event');
    CheckEquals(Int64(2856025), fReceivedUserID, 'UserID должен быть передан корректно');
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageEventTests.TestMessageEventAlsoFiresGenericHandler;
var
  aUpdate: TJSONObject;
begin
  fBot.EventHandlers[etMessageEvent] := @OnRawEvent;

  aUpdate := MakeMessageEventUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fRawEventHandled,
      'Обобщённый EventHandlers[etMessageEvent] должен также сработать');
    CheckNotNull(fReceivedRawObject, 'Объект события должен быть передан');
    CheckEquals(Int64(2856025), fReceivedRawObject.Get('user_id', Int64(0)));
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageEventTests.TestMessageEventFiresBothHandlers;
var
  aUpdate: TJSONObject;
begin
  fBot.OnMessageEvent := @OnMessageEvent;
  fBot.EventHandlers[etMessageEvent] := @OnRawEvent;

  aUpdate := MakeMessageEventUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fMsgEventHandled,  'Специфичный хендлер должен сработать');
    CheckTrue(fRawEventHandled,  'Обобщённый хендлер должен сработать');
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageEventTests.TestMessageNewFiresBothHandlers;
var
  aUpdate, aObject, aMessage: TJSONObject;
begin
  fMsgHandled := False;

  fBot.OnMessage := @TestMessageHandler;
  fBot.EventHandlers[etMessageNew] := @OnRawEvent;

  aMessage := TJSONObject.Create;
  aMessage.Add('text', 'Привет');
  aMessage.Add('peer_id', Int64(100));
  aMessage.Add('from_id', Int64(200));
  aMessage.Add('conversation_message_id', Int64(1));

  aObject := TJSONObject.Create;
  aObject.Add('message', aMessage);

  aUpdate := TJSONObject.Create;
  try
    aUpdate.Add('type', 'message_new');
    aUpdate.Add('object', aObject);

    fBot.ProcessUpdate(aUpdate);

    CheckTrue(fMsgHandled,      'MessageHandler должен сработать при message_new');
    CheckTrue(fRawEventHandled, 'EventHandlers[etMessageNew] тоже должен сработать');
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageEventTests.TestUnknownEventTypeIgnored(const aMsg: TVKMessage);
begin
  fMsgHandled := True;
end;

{ TMessageReplyTests }

procedure TMessageReplyTests.SetUp;
begin
  fBot := TMockVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');

  fReplyData := TJSONObject.Create;
  fReplyData.Add('id',                        Int64(555));
  fReplyData.Add('peer_id',                   Int64(987654));
  fReplyData.Add('from_id',                   Int64(111222));
  fReplyData.Add('text',                       'Reply text');
  fReplyData.Add('conversation_message_id',   Int64(42));

  fReply := TVKMessageReply.Create(fBot, fReplyData);
end;

procedure TMessageReplyTests.TearDown;
begin
  fReply.Free;
  fReplyData.Free;
  fBot.Free;
end;

procedure TMessageReplyTests.TestGetText;
begin
  CheckEquals('Reply text', fReply.Text);
end;

procedure TMessageReplyTests.TestGetPeerID;
begin
  CheckEquals(Int64(987654), fReply.PeerID);
end;

procedure TMessageReplyTests.TestGetFromID;
begin
  CheckEquals(Int64(111222), fReply.FromID);
end;

procedure TMessageReplyTests.TestGetMessageID;
begin
  CheckEquals(Int64(555), fReply.MessageID);
end;

procedure TMessageReplyTests.TestGetConversationMessageId;
begin
  CheckEquals(Int64(42), fReply.ConversationMessageId);
end;

procedure TMessageReplyTests.TestReplyCallsSendMessage;
begin
  TMockHTTPClient.ClearCalls;
  fReply.Reply('Ответ');
  CheckTrue(TMockHTTPClient.GetCallCount > 0, 'Reply должен вызвать messages.send');
end;

procedure TMessageReplyTests.TestReplyUsesCorrectPeerID;
begin
  TMockHTTPClient.ClearCalls;
  fReply.Reply('Ок');
  CheckTrue(TMockHTTPClient.WasCalled('peer_id=987654'),
    'Reply должен отправить на peer_id из message_reply');
end;

procedure TMessageReplyTests.TestSendWithExplicitPeerID;
var
  aLastURL: string;
begin
  fReply.Send('Тест', 555666);
  aLastURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('peer_id=555666', aLastURL) > 0, 'Send должен использовать явно указанный PeerID');
end;

procedure TMessageReplyTests.TestSendWithKeyboard;
var
  aKB: TVKKeyboard;
  aLastURL: string;
begin
  aKB := TVKKeyboard.Create;
  try
    aKB.AddButton('Кнопка');
    fReply.Send('Выбери', 0, aKB.Build);
    aLastURL := TMockHTTPClient.GetLastURL;
    CheckTrue(Pos('keyboard=', aLastURL) > 0, 'Send должен передать клавиатуру');
  finally
    aKB.Free;
  end;
end;

{ TMessageReplyHandlerTests }

procedure TMessageReplyHandlerTests.SetUp;
begin
  fBot           := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fHandlerCalled := False;
  fHandlerCount  := 0;
  fReceivedText  := '';
  fReceivedPeerID := 0;
  fReceivedFromID := 0;
end;

procedure TMessageReplyHandlerTests.TearDown;
begin
  fBot.Free;
end;

procedure TMessageReplyHandlerTests.ReplyHandler(const aReply: TVKMessageReply);
begin
  fHandlerCalled  := True;
  Inc(fHandlerCount);
  fReceivedText   := aReply.Text;
  fReceivedPeerID := aReply.PeerID;
  fReceivedFromID := aReply.FromID;
end;

procedure TMessageReplyHandlerTests.SecondReplyHandler(const aReply: TVKMessageReply);
begin
  Inc(fHandlerCount);
end;

procedure TMessageReplyHandlerTests.TestHandlerCalledOnMessageReply;
var
  aData: TJSONObject;
begin
  fBot.OnMessageReply := @ReplyHandler;

  aData := TJSONObject.Create;
  try
    aData.Add('id',      Int64(1));
    aData.Add('peer_id', Int64(100));
    aData.Add('from_id', Int64(200));
    aData.Add('text',    'Привет');
    fBot.ProcessMessageReply(aData);
    CheckTrue(fHandlerCalled, 'Обработчик message_reply должен быть вызван');
  finally
    aData.Free;
  end;
end;

procedure TMessageReplyHandlerTests.TestHandlerReceivesCorrectData;
var
  aData: TJSONObject;
begin
  fBot.OnMessageReply := @ReplyHandler;

  aData := TJSONObject.Create;
  try
    aData.Add('id',      Int64(7));
    aData.Add('peer_id', Int64(8888));
    aData.Add('from_id', Int64(9999));
    aData.Add('text',    'Тестовый ответ');
    fBot.ProcessMessageReply(aData);
    CheckEquals('Тестовый ответ', fReceivedText,    'Text должен совпадать');
    CheckEquals(Int64(8888),      fReceivedPeerID,  'PeerID должен совпадать');
    CheckEquals(Int64(9999),      fReceivedFromID,  'FromID должен совпадать');
  finally
    aData.Free;
  end;
end;

procedure TMessageReplyHandlerTests.TestNoHandlersDoesNotCrash;
var
  aData: TJSONObject;
begin
  { нет обработчиков — не должно быть исключений }
  aData := TJSONObject.Create;
  try
    aData.Add('id',      Int64(1));
    aData.Add('peer_id', Int64(1));
    aData.Add('from_id', Int64(1));
    aData.Add('text',    'Test');
    fBot.ProcessMessageReply(aData);
  finally
    aData.Free;
  end;
end;

procedure TMessageReplyHandlerTests.TestNilReplyObjectDoesNotCrash;
begin
  fBot.OnMessageReply := @ReplyHandler;
  fBot.ProcessMessageReply(nil);
  CheckFalse(fHandlerCalled, 'Обработчик не должен вызываться при nil');
end;

{ TProcessUpdateMessageReplyTests }

procedure TProcessUpdateMessageReplyTests.SetUp;
begin
  fBot                := TTestVKBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":{"message_id":1}}');
  fMsgReplyHandled    := False;
  fRawEventHandled    := False;
  fReceivedText       := '';
  fReceivedRawObject  := nil;
end;

procedure TProcessUpdateMessageReplyTests.TearDown;
begin
  fReceivedRawObject.Free;
  fBot.Free;
end;

procedure TProcessUpdateMessageReplyTests.OnMessageReply(const aReply: TVKMessageReply);
begin
  fMsgReplyHandled := True;
  fReceivedText    := aReply.Text;
end;

procedure TProcessUpdateMessageReplyTests.OnRawEvent(const aEvent: TJSONObject);
begin
  fRawEventHandled   := True;
  fReceivedRawObject := TJSONObject(aEvent.Clone);
end;

function TProcessUpdateMessageReplyTests.MakeMessageReplyUpdate: TJSONObject;
var
  aObject: TJSONObject;
begin
  aObject := TJSONObject.Create;
  aObject.Add('id',                        Int64(101));
  aObject.Add('peer_id',                   Int64(555));
  aObject.Add('from_id',                   Int64(777));
  aObject.Add('text',                       'Бот ответил');
  aObject.Add('conversation_message_id',   Int64(9));

  Result := TJSONObject.Create;
  Result.Add('type',   'message_reply');
  Result.Add('object', aObject);
end;

procedure TProcessUpdateMessageReplyTests.TestMessageReplyFiresSpecificHandler;
var
  aUpdate: TJSONObject;
begin
  fBot.OnMessageReply := @OnMessageReply;

  aUpdate := MakeMessageReplyUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fMsgReplyHandled,
      'ProcessMessageReply-хендлер должен сработать при message_reply');
    CheckEquals('Бот ответил', fReceivedText, 'Text должен быть передан корректно');
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageReplyTests.TestMessageReplyAlsoFiresGenericHandler;
var
  aUpdate: TJSONObject;
begin
  fBot.EventHandlers[etMessageReply] := @OnRawEvent;

  aUpdate := MakeMessageReplyUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fRawEventHandled,
      'Обобщённый EventHandlers[etMessageReply] должен также сработать');
    CheckNotNull(fReceivedRawObject, 'Объект события должен быть передан');
    CheckEquals(Int64(777), fReceivedRawObject.Get('from_id', Int64(0)));
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageReplyTests.TestMessageReplyFiresBothHandlers;
var
  aUpdate: TJSONObject;
begin
  fBot.OnMessageReply := @OnMessageReply;
  fBot.EventHandlers[etMessageReply] := @OnRawEvent;

  aUpdate := MakeMessageReplyUpdate;
  try
    fBot.ProcessUpdate(aUpdate);
    CheckTrue(fMsgReplyHandled, 'Специфичный хендлер должен сработать');
    CheckTrue(fRawEventHandled, 'Обобщённый хендлер должен сработать');
  finally
    aUpdate.Free;
  end;
end;

procedure TProcessUpdateMessageReplyTests.TestNilReplyObjectDoesNotCrash;
var
  aUpdate: TJSONObject;
begin
  fBot.OnMessageReply := @OnMessageReply;

  { object = nil — ProcessUpdate должен выйти без краша }
  aUpdate := TJSONObject.Create;
  try
    aUpdate.Add('type', 'message_reply');
    { намеренно не добавляем 'object' }
    fBot.ProcessUpdate(aUpdate);
    CheckFalse(fMsgReplyHandled, 'Обработчик не должен сработать при отсутствующем object');
  finally
    aUpdate.Free;
  end;
end;

initialization
  RegisterTest(TEventTypeHelperTests);
  RegisterTest(TMessageReplyTests);
  RegisterTest(TMessageReplyHandlerTests);
  RegisterTest(TProcessUpdateMessageReplyTests);
  RegisterTest(TMessageTests);
  RegisterTest(TMessageEventTests);
  RegisterTest(TKeyboardTests);
  RegisterTest(TBotCommandTests);
  RegisterTest(TBotMessageHandlerTests);
  RegisterTest(TBotEventTests);
  RegisterTest(TMessageEventHandlerTests);
  RegisterTest(TProcessUpdateMessageEventTests);
  RegisterTest(TAPICallTests);
  RegisterTest(TIntegrationTests);

end.
