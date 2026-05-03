{$mode objfpc}{$H+}{$J-}

unit VKDeeplinkTests;

{ Тесты VK Deeplink (ref/ref_source механизм).

  Как работает deeplink в VK:
    - Ссылка: vk.me/<username>?ref=<метка>[&ref_source=<доп.метка>]
    - Пользователь переходит по ней и пишет ЛЮБОЕ сообщение боту.
    - VK добавляет в объект сообщения поля "ref" и "ref_source".
    - Бот читает их из TVKMessage.Ref / TVKMessage.RefSource.
    - Deeplink-обработчик вызывается ВМЕСТЕ с обычным pipeline (не вместо).
}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  fpjson, jsonparser,
  VKTypes, VKBotFramework, VKBotFrameworkMocks
  ;

type

  TTestVKBot = class(TMockVKBot);

  { -----------------------------------------------------------------------
    TVKDeeplinkBuilderTests — тесты TVKDeeplink.Build / BuildByGroupID
    ----------------------------------------------------------------------- }
  TVKDeeplinkBuilderTests = class(TTestCase)
  published
    procedure TestBuild_SimpleRef;
    procedure TestBuild_WithRefSource;
    procedure TestBuild_RefIsURLEncoded;
    procedure TestBuild_EmptyRef_Raises;
    procedure TestBuild_EmptyUsername_Raises;
    procedure TestBuildByGroupID_Valid;
    procedure TestBuildByGroupID_ZeroGroupID_Raises;
    procedure TestBuildByGroupID_NegativeGroupID_Raises;
    procedure TestBuildByGroupID_WithRefSource;
  end;

  { -----------------------------------------------------------------------
    TVKMessageRefTests — тесты чтения ref/ref_source из TVKMessage
    ----------------------------------------------------------------------- }
  TVKMessageRefTests = class(TTestCase)
  private
    fBot: TTestVKBot;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestRef_PresentInJSON;
    procedure TestRefSource_PresentInJSON;
    procedure TestRef_AbsentInJSON_ReturnsEmpty;
    procedure TestRefSource_AbsentInJSON_ReturnsEmpty;
    procedure TestRef_EmptyString_ReturnsEmpty;
  end;

  { -----------------------------------------------------------------------
    TVKBotDeeplinkDispatchTests — тесты диспетчеризации deeplink в TVKBot
    ----------------------------------------------------------------------- }
  TVKBotDeeplinkDispatchTests = class(TTestCase)
  private
    fBot: TTestVKBot;

    fExactHandlerCalled:   Boolean;
    fFallbackHandlerCalled: Boolean;
    fCommandHandlerCalled: Boolean;
    fMessageHandlerCalled: Boolean;
    fReceivedRef:       string;
    fReceivedRefSource: string;
    fReceivedText:      string;

    { Вспомогательный метод: симулирует входящее сообщение с ref/ref_source }
    procedure SendMessageWithRef(const aText, aRef: string; const aRefSource: string = ''; aPeerID: Int64 = 100);
    { Входящее сообщение БЕЗ ref }
    procedure SendPlainMessage(const aText: string; aPeerID: Int64 = 100);

    procedure OnExactHandler(const {%H-}aMsg: TVKMessage; const aRef, aRefSource: string);
    procedure OnOtherExactHandler(const {%H-}aMsg: TVKMessage; const {%H-}aRef, {%H-}aRefSource: string);
    procedure OnDeepLinkHandler(const {%H-}aMsg: TVKMessage; const aRef, aRefSource: string);
    procedure OnStartCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
    procedure OnAnyMessage(const aMsg: TVKMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { Deeplink }
    procedure TestDispatch_FallbackCalled_WhenNoExact;
    procedure TestDispatch_FallbackRefPassed;
    procedure TestDispatch_FallbackNotCalledWhenNoRef;

    { Нет deeplink-обработчиков — только обычный pipeline }
    procedure TestDispatch_NoHandlers_PlainPipelineRuns;

    { Сообщение без ref — deeplink не срабатывает }
    procedure TestDispatch_NoRef_DeeplinkNotTriggered;
    procedure TestDispatch_EmptyRef_DeeplinkNotTriggered;
  end;

implementation

{ ===== TVKDeeplinkBuilderTests ===== }

procedure TVKDeeplinkBuilderTests.TestBuild_SimpleRef;
begin
  CheckEquals('https://vk.me/mygroup?ref=summer-promo', TVKDeeplink.Build('mygroup', 'summer-promo'));
end;

procedure TVKDeeplinkBuilderTests.TestBuild_WithRefSource;
begin
  CheckEquals('https://vk.me/mygroup?ref=ad&ref_source=vk-feed', TVKDeeplink.Build('mygroup', 'ad', 'vk-feed'));
end;

procedure TVKDeeplinkBuilderTests.TestBuild_RefIsURLEncoded;
var
  aURL: string;
begin
  { Кириллица и спецсимволы должны URL-кодироваться }
  aURL := TVKDeeplink.Build('mygroup', 'лето 2025');
  CheckTrue(Pos('?ref=', aURL) > 0, 'Должен быть параметр ref');
  CheckTrue(Pos(' ', aURL) = 0, 'Пробелы должны быть закодированы');
  CheckTrue(Pos('mygroup', aURL) > 0);
end;

procedure TVKDeeplinkBuilderTests.TestBuild_EmptyRef_Raises;
begin
  try
    TVKDeeplink.Build('mygroup', EmptyStr);
    Fail('Должно поднять EArgumentException для пустого ref');
  except
    on E: EArgumentException do ; // ожидаемо
  end;
end;

procedure TVKDeeplinkBuilderTests.TestBuild_EmptyUsername_Raises;
begin
  try
    TVKDeeplink.Build(EmptyStr, 'promo');
    Fail('Должно поднять EArgumentException для пустого username');
  except
    on E: EArgumentException do ; // ожидаемо
  end;
end;

procedure TVKDeeplinkBuilderTests.TestBuildByGroupID_Valid;
begin
  CheckEquals('https://vk.me/club123456789?ref=promo', TVKDeeplink.BuildByGroupID(123456789, 'promo'));
end;

procedure TVKDeeplinkBuilderTests.TestBuildByGroupID_ZeroGroupID_Raises;
begin
  try
    TVKDeeplink.BuildByGroupID(0, 'promo');
    Fail('Должно поднять EArgumentException для GroupID = 0');
  except
    on E: EArgumentException do ;
  end;
end;

procedure TVKDeeplinkBuilderTests.TestBuildByGroupID_NegativeGroupID_Raises;
begin
  try
    TVKDeeplink.BuildByGroupID(-5, 'promo');
    Fail('Должно поднять EArgumentException для GroupID < 0');
  except
    on E: EArgumentException do ;
  end;
end;

procedure TVKDeeplinkBuilderTests.TestBuildByGroupID_WithRefSource;
begin
  CheckEquals('https://vk.me/club999?ref=campaign&ref_source=email',
    TVKDeeplink.BuildByGroupID(999, 'campaign', 'email'));
end;

{ ===== TVKMessageRefTests ===== }

procedure TVKMessageRefTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 123);
  fBot.MockClient.SetDefaultResponse('{"response":1}');
end;

procedure TVKMessageRefTests.TearDown;
begin
  fBot.Free;
end;

procedure TVKMessageRefTests.TestRef_PresentInJSON;
var
  aData: TJSONObject;
  aMsg: TVKMessage;
begin
  aData := TJSONObject.Create;
  try
    aData.Add('text', 'Привет');
    aData.Add('peer_id', Int64(1));
    aData.Add('ref', 'summer-promo');
    aMsg := TVKMessage.Create(fBot, aData);
    try
      CheckEquals('summer-promo', aMsg.Ref);
    finally
      aMsg.Free;
    end;
  finally
    aData.Free;
  end;
end;

procedure TVKMessageRefTests.TestRefSource_PresentInJSON;
var
  aData: TJSONObject;
  aMsg: TVKMessage;
begin
  aData := TJSONObject.Create;
  try
    aData.Add('text', 'Привет');
    aData.Add('peer_id', Int64(1));
    aData.Add('ref', 'campaign');
    aData.Add('ref_source', 'vk-feed');
    aMsg := TVKMessage.Create(fBot, aData);
    try
      CheckEquals('campaign', aMsg.Ref);
      CheckEquals('vk-feed', aMsg.RefSource);
    finally
      aMsg.Free;
    end;
  finally
    aData.Free;
  end;
end;

procedure TVKMessageRefTests.TestRef_AbsentInJSON_ReturnsEmpty;
var
  aData: TJSONObject;
  aMsg: TVKMessage;
begin
  aData := TJSONObject.Create;
  try
    aData.Add('text', 'Привет');
    aData.Add('peer_id', Int64(1));
    aMsg := TVKMessage.Create(fBot, aData);
    try
      CheckEquals('', aMsg.Ref, 'Ref должен быть пустым при отсутствии поля');
    finally
      aMsg.Free;
    end;
  finally
    aData.Free;
  end;
end;

procedure TVKMessageRefTests.TestRefSource_AbsentInJSON_ReturnsEmpty;
var
  aData: TJSONObject;
  aMsg: TVKMessage;
begin
  aData := TJSONObject.Create;
  try
    aData.Add('text', 'Текст');
    aData.Add('peer_id', Int64(1));
    aData.Add('ref', 'some-ref');
    { ref_source не добавляем }
    aMsg := TVKMessage.Create(fBot, aData);
    try
      CheckEquals('', aMsg.RefSource, 'RefSource должен быть пустым при отсутствии поля');
    finally
      aMsg.Free;
    end;
  finally
    aData.Free;
  end;
end;

procedure TVKMessageRefTests.TestRef_EmptyString_ReturnsEmpty;
var
  aData: TJSONObject;
  aMsg: TVKMessage;
begin
  aData := TJSONObject.Create;
  try
    aData.Add('text', 'Текст');
    aData.Add('peer_id', Int64(1));
    aData.Add('ref', EmptyStr);
    aMsg := TVKMessage.Create(fBot, aData);
    try
      CheckEquals(EmptyStr, aMsg.Ref);
    finally
      aMsg.Free;
    end;
  finally
    aData.Free;
  end;
end;

{ ===== TVKBotDeeplinkDispatchTests ===== }

procedure TVKBotDeeplinkDispatchTests.SetUp;
begin
  fBot := TTestVKBot.Create('test_token', 123456);
  fBot.MockClient.SetDefaultResponse('{"response":1}');
  fExactHandlerCalled    := False;
  fFallbackHandlerCalled := False;
  fCommandHandlerCalled  := False;
  fMessageHandlerCalled  := False;
  fReceivedRef        := EmptyStr;
  fReceivedRefSource  := EmptyStr;
  fReceivedText       := EmptyStr;
end;

procedure TVKBotDeeplinkDispatchTests.TearDown;
begin
  fBot.Free;
end;

procedure TVKBotDeeplinkDispatchTests.SendMessageWithRef(const aText, aRef: string;
  const aRefSource: string; aPeerID: Int64);
var
  aMsgObj: TJSONObject;
begin
  aMsgObj := TJSONObject.Create;
  try
    aMsgObj.Add('text',     aText);
    aMsgObj.Add('peer_id',  aPeerID);
    aMsgObj.Add('ref',      aRef);
    if aRefSource <> '' then
      aMsgObj.Add('ref_source', aRefSource);
    fBot.ProcessMessage(aMsgObj);
  finally
    aMsgObj.Free;
  end;
end;

procedure TVKBotDeeplinkDispatchTests.SendPlainMessage(const aText: string; aPeerID: Int64);
var
  aMsgObj: TJSONObject;
begin
  aMsgObj := TJSONObject.Create;
  try
    aMsgObj.Add('text',    aText);
    aMsgObj.Add('peer_id', aPeerID);
    { ref намеренно не добавляем }
    fBot.ProcessMessage(aMsgObj);
  finally
    aMsgObj.Free;
  end;
end;

procedure TVKBotDeeplinkDispatchTests.OnExactHandler(const aMsg: TVKMessage;
  const aRef, aRefSource: string);
begin
  fExactHandlerCalled := True;
  fReceivedRef        := aRef;
  fReceivedRefSource  := aRefSource;
end;

procedure TVKBotDeeplinkDispatchTests.OnOtherExactHandler(const aMsg: TVKMessage;
  const aRef, aRefSource: string);
begin
  { Намеренно пуст — проверяем что НЕ вызывается }
end;

procedure TVKBotDeeplinkDispatchTests.OnDeepLinkHandler(const aMsg: TVKMessage;
  const aRef, aRefSource: string);
begin
  fFallbackHandlerCalled := True;
  fReceivedRef           := aRef;
  fReceivedRefSource     := aRefSource;
end;

procedure TVKBotDeeplinkDispatchTests.OnStartCommand(const aMsg: TVKMessage;
  const aArgs: TStringArray);
begin
  fCommandHandlerCalled := True;
  fReceivedText := aMsg.Text;
end;

procedure TVKBotDeeplinkDispatchTests.OnAnyMessage(const aMsg: TVKMessage);
begin
  fMessageHandlerCalled := True;
  fReceivedText := aMsg.Text;
end;

{ --- Fallback --- }

procedure TVKBotDeeplinkDispatchTests.TestDispatch_FallbackCalled_WhenNoExact;
begin
  fBot.OnDeeplink := @OnDeepLinkHandler;
  SendMessageWithRef('Текст', 'unknown-ref');
  CheckTrue(fFallbackHandlerCalled, 'Fallback должен вызваться при отсутствии точного совпадения');
end;

procedure TVKBotDeeplinkDispatchTests.TestDispatch_FallbackRefPassed;
begin
  fBot.OnDeeplink := @OnDeepLinkHandler;
  SendMessageWithRef('Текст', 'my-ref', 'my-source');
  CheckEquals('my-ref',    fReceivedRef);
  CheckEquals('my-source', fReceivedRefSource);
end;

procedure TVKBotDeeplinkDispatchTests.TestDispatch_FallbackNotCalledWhenNoRef;
begin
  fBot.OnDeeplink := @OnDeepLinkHandler;
  SendPlainMessage('Обычное сообщение без ref');
  CheckFalse(fFallbackHandlerCalled, 'Fallback не должен вызываться если ref отсутствует');
end;

{ --- Нет deeplink-обработчиков --- }

procedure TVKBotDeeplinkDispatchTests.TestDispatch_NoHandlers_PlainPipelineRuns;
begin
  { Нет deeplink-обработчиков — обычный pipeline работает как обычно }
  fBot.AddMessageHandler(@OnAnyMessage);
  SendMessageWithRef('Привет', 'some-ref');
  CheckTrue(fMessageHandlerCalled, 'MessageHandler должен сработать даже если нет deeplink-обработчиков');
end;

{ --- Нет ref --- }

procedure TVKBotDeeplinkDispatchTests.TestDispatch_NoRef_DeeplinkNotTriggered;
begin
  fBot.OnDeeplink := @OnDeepLinkHandler;
  SendPlainMessage('Обычное сообщение');
  CheckFalse(fFallbackHandlerCalled, 'Fallback не должен срабатывать без ref');
end;

procedure TVKBotDeeplinkDispatchTests.TestDispatch_EmptyRef_DeeplinkNotTriggered;
var
  aMsgObj: TJSONObject;
begin
  fBot.OnDeeplink := @OnDeepLinkHandler;
  { Поле ref есть, но пустое }
  aMsgObj := TJSONObject.Create;
  try
    aMsgObj.Add('text',    'Текст');
    aMsgObj.Add('peer_id', Int64(1));
    aMsgObj.Add('ref',     '');
    fBot.ProcessMessage(aMsgObj);
  finally
    aMsgObj.Free;
  end;
  CheckFalse(fFallbackHandlerCalled, 'Пустой ref не должен запускать deeplink-обработчик');
end;

initialization
  RegisterTest(TVKDeeplinkBuilderTests);
  RegisterTest(TVKMessageRefTests);
  RegisterTest(TVKBotDeeplinkDispatchTests);

end.
