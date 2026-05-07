unit VKBotFramework;

{$mode objfpc}{$H+}{$J-}

interface

uses
  SysUtils, Classes, fphttpclient, fpjson, jsonparser, ghashmap, gvector, VKTypes, vkbasehttpclient
  ;

type
  TVKMessage = class;
  TVKMessageEvent = class;
  TVKMessageReply = class;
  TVKBot = class;

  { Event handler types }
  TMessageHandler      = procedure(const aMessage: TVKMessage) of object;
  TCommandHandler      = procedure(const aMessage: TVKMessage; const aArgs: TStringArray) of object;
  TEventHandler        = procedure(const aEvent: TJSONObject) of object;
  TMessageEventHandler = procedure(const aEvent: TVKMessageEvent) of object;
  TMessageReplyHandler = procedure(const aReply: TVKMessageReply) of object;

  { Deeplink handler.
    Called while incoming message contains ref (user income with link like vk.me/<username>?ref=<...>).
    aMsg       — income message (any text — that user typed).
    aRef       — ref parameter value from link.
    aRefSource — ref_source parameter value (empty, if not passed). }
  TDeeplinkHandler = procedure(const aMsg: TVKMessage; const aRef, aRefSource: string) of object;

  { TVKMessage }
  {
    TVKMessage — JSON wrapper for incoming message.
  }
  TVKMessage = class
  private
    fData: TJSONObject;
    fBot: TVKBot;
    function GetConversationMessageId: Int64;
    function GetText: string;
    function GetPeerID: Int64;
    function GetFromID: Int64;
    function GetPayload: string;
    function GetRef: string;
    function GetRefSource: string;
  public
    constructor Create(aBot: TVKBot; aData: TJSONObject);

    procedure Reply(const aText: string; const aKeyboard: string = '');
    procedure Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');

    property ConversationMessageId: Int64  read GetConversationMessageId;

    property Text:                  string read GetText;
    property PeerID:                Int64  read GetPeerID;
    property FromID:                Int64  read GetFromID;
    property Payload:               string read GetPayload;

    property Ref:                   string read GetRef;
    property RefSource:             string read GetRefSource;

    property Data: TJSONObject read fData;
  end;

  { TVKMessageEvent }
  {
    TVKMessageEvent — JSON wrapper for message_event (callback inline button).
    The object has no nested "message"; it contains directly:
      user_id, peer_id, event_id, conversation_message_id, payload (TJSONObject).
  }
  TVKMessageEvent = class
  private
    fData: TJSONObject;
    fBot:  TVKBot;
    function GetUserID: Int64;
    function GetPeerID: Int64;
    function GetEventID: string;
    function GetConversationMessageId: Int64;
    function GetPayload: TJSONObject;
  public
    constructor Create(aBot: TVKBot; aData: TJSONObject);

    { Send a text message back to the same peer }
    procedure Reply(const aText: string; const aKeyboard: string = '');

    property UserID:                 Int64       read GetUserID;
    property PeerID:                 Int64       read GetPeerID;
    property EventID:                string      read GetEventID;
    property ConversationMessageId:  Int64       read GetConversationMessageId;
    { Payload is a TJSONObject (do NOT free — owned by fData) }
    property Payload:                TJSONObject read GetPayload;

    property Data: TJSONObject read fData;
  end;

  { TVKMessageReply }
  {
    TVKMessageReply — JSON wrapper for message_reply event.
    The object contains the replied message directly (same field set as TVKMessage):
      id, peer_id, from_id, text, conversation_message_id, etc.
    Unlike message_new the object IS the message (no nested "message" key).
  }
  TVKMessageReply = class
  private
    fData: TJSONObject;
    fBot:  TVKBot;
    function GetConversationMessageId: Int64;
    function GetText: string;
    function GetPeerID: Int64;
    function GetFromID: Int64;
    function GetMessageID: Int64;
  public
    constructor Create(aBot: TVKBot; aData: TJSONObject);

    { Send a text message back to the same peer }
    procedure Reply(const aText: string; const aKeyboard: string = '');
    procedure Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');

    property ConversationMessageId: Int64  read GetConversationMessageId;
    property MessageID:             Int64  read GetMessageID;
    property Text:                  string read GetText;
    property PeerID:                Int64  read GetPeerID;
    property FromID:                Int64  read GetFromID;

    property Data: TJSONObject read fData;
  end;

  { TStringHash }

  TStringHash = class
    class function hash(s: String; n: Integer): Integer; inline;
  end;

  generic TStringHashMap<T> = class(specialize THashMap<String, T, TStringHash>) end;

  { TEventTypeHash }

  TEventTypeHash = class
    class function hash(s: TVKEventType; n: Integer): Integer; inline;
  end;

  generic TEventTypeHashMap<T> = class(specialize THashMap<TVKEventType, T, TEventTypeHash>) end;

  TCommandMap              = specialize TStringHashMap<TCommandHandler>;
  TEventMap                = specialize TEventTypeHashMap<TEventHandler>;

  { TVKBot }
  {
    TVKBot — main bot class.
  }
  TVKBot = class
  private
    fJSON: TJSONData;
    fOnMessage: TMessageHandler;
    fOnMessageEvent: TMessageEventHandler;
    fOnMessageReply: TMessageReplyHandler;
    fToken: string;
    fGroupID: Int64;
    fAPIVersion: string;
    fCommands:             TCommandMap;
    fEventHandlers:        TEventMap;
    fOnDeeplink: TDeeplinkHandler;

    fRunning: Boolean;
    fServer: string;
    fKey: string;
    fTS: Int64;
    fOnLog: TOnLogEvent;

    procedure InitLongPoll;
    function APICall(const aMethod: string; const aParams: TJSONObject): TJSONData;
    procedure DoLog(aLogLevel: TLogLevel; const aMessage: String);

    function GetCommandHandler(const aCommand: string): TCommandHandler;
    procedure SetCommandHandler(const aCommand: string; aHandler: TCommandHandler);
    function GetEventHandlerByName(const aEventType: String): TEventHandler;
    function GetEventHandlerByEnum(aEventType: TVKEventType): TEventHandler;
    procedure SetEventHandlerByEnum(aEventType: TVKEventType; aHandler: TEventHandler);
    procedure SetEventHandlerByName(const aEventType: String; aHandler: TEventHandler);

    { Dispatch deeplink inside ProcessMessage.
      Call if msg.Ref nonempty. Does not continues processing. }
    procedure DispatchDeeplink(const aMsg: TVKMessage);

  protected
    procedure ProcessMessage(const aMessage: TJSONObject);
    procedure ProcessMessageEvent(const aEventObject: TJSONObject);
    procedure ProcessMessageReply(const aReplyObject: TJSONObject);
    property RawJSON: TJSONData read fJSON write fJSON;
    property EventMap: TEventMap read fEventHandlers;
    property CommandMap: TCommandMap read fCommands;
  public
    constructor Create(const aToken: string; aGroupID: Int64 = 0);
    destructor Destroy; override;

    { Bot control - for LongPoll mode }
    procedure Start;
    procedure Stop;

    { Process update - can be called externally (e.g., from webhook) }
    procedure ProcessUpdate(const aUpdate: TJSONObject);

    { API methods }
    function SendMessage(aPeerID: Int64; const aText: string; const aKeyboard: string = ''): Boolean;
    function EditMessage(aPeerID, aMessageID: Int64; const aText: string; const aKeyboard: string = ''): Boolean;
    function DeleteMessage(aPeerID, aMessageID: Int64; aDeleteForAll: Boolean = False): Boolean; overload;
    function DeleteMessage(aPeerID: Int64; const aMessageIDs: array of Int64;
      aDeleteForAll: Boolean = False): Boolean; overload;
    function GetMessagesUploadServer(const aType: string = 'doc'; aPeerID: Int64 = 0): TJSONData;

    property OnDeeplink: TDeeplinkHandler read fOnDeeplink write fOnDeeplink;

    property Token:   string  read fToken;
    property GroupID: Int64   read fGroupID;
    property Running: Boolean read fRunning;

    property CommandHandlers[const aCommand: string]: TCommandHandler read GetCommandHandler write SetCommandHandler;
    property EventHandlers[aEventType: TVKEventType]: TEventHandler
      read GetEventHandlerByEnum write SetEventHandlerByEnum;
    property EventHandlersByName[const aEventType: String]: TEventHandler
      read GetEventHandlerByName write SetEventHandlerByName;
    property OnLog: TOnLogEvent read fOnLog write fOnLog;

    property OnMessage:      TMessageHandler read fOnMessage write fOnMessage;               
    property OnMessageReply: TMessageReplyHandler read fOnMessageReply write fOnMessageReply;
    property OnMessageEvent: TMessageEventHandler read fOnMessageEvent write fOnMessageEvent;

    property RawResponse: TJSONData read fJSON write fJSON;
  end;

  { Keyboard builder }

  { TVKKeyboard }

  TVKKeyboard = class
  private
    fButtons: TJSONArray;
    fOneTime: Boolean;
    fInline: Boolean;
  public
    constructor Create(aOneTime: Boolean = False; aInline: Boolean = False);
    destructor Destroy; override;

    function AddButton(const aLabel: string; aColor: TVKButtonColor=bcSecondary; aType: TVKButtonType=btText;
      const aPayload: string=''): TVKKeyboard;
    function AddRow: TVKKeyboard;
    function Build: string;

    property OneTime: Boolean read fOneTime write fOneTime;
    property Inline:  Boolean read fInline  write fInline;
  end;

implementation

uses
  DateUtils, opensslsockets, VKFCLHTTPClientBroker
  ;

{ TVKMessage }

constructor TVKMessage.Create(aBot: TVKBot; aData: TJSONObject);
begin
  inherited Create;
  fBot  := aBot;
  fData := aData;
end;

function TVKMessage.GetText: string;
begin
  Result := fData.Get('text', EmptyStr);
end;

function TVKMessage.GetConversationMessageId: Int64;
begin
  Result := fData.Get('conversation_message_id', Integer(0));
end;

function TVKMessage.GetPeerID: Int64;
begin
  Result := fData.Get('peer_id', Int64(0));
end;

function TVKMessage.GetFromID: Int64;
begin
  Result := fData.Get('from_id', Int64(0));
end;

function TVKMessage.GetPayload: string;
begin
  Result := fData.Get('payload', EmptyStr);
end;

function TVKMessage.GetRef: string;
begin
  Result := fData.Get('ref', EmptyStr);
end;

function TVKMessage.GetRefSource: string;
begin
  Result := fData.Get('ref_source', EmptyStr);
end;

procedure TVKMessage.Reply(const aText: string; const aKeyboard: string = '');
begin
  Send(aText, PeerID, aKeyboard);
end;

procedure TVKMessage.Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');
begin
  fBot.SendMessage(specialize IfThen<Int64>(aPeerID = 0, PeerID, aPeerID), aText, aKeyboard);
end;

{ TVKMessageEvent }

constructor TVKMessageEvent.Create(aBot: TVKBot; aData: TJSONObject);
begin
  inherited Create;
  fBot  := aBot;
  fData := aData;
end;

function TVKMessageEvent.GetUserID: Int64;
begin
  Result := fData.Get('user_id', Int64(0));
end;

function TVKMessageEvent.GetPeerID: Int64;
begin
  Result := fData.Get('peer_id', Int64(0));
end;

function TVKMessageEvent.GetEventID: string;
begin
  Result := fData.Get('event_id', EmptyStr);
end;

function TVKMessageEvent.GetConversationMessageId: Int64;
begin
  Result := fData.Get('conversation_message_id', Integer(0));
end;

function TVKMessageEvent.GetPayload: TJSONObject;
begin
  Result := fData.Get('payload', TJSONObject(nil));
end;

procedure TVKMessageEvent.Reply(const aText: string; const aKeyboard: string = '');
begin
  fBot.SendMessage(PeerID, aText, aKeyboard);
end;

{ TVKMessageReply }

constructor TVKMessageReply.Create(aBot: TVKBot; aData: TJSONObject);
begin
  inherited Create;
  fBot  := aBot;
  fData := aData;
end;

function TVKMessageReply.GetConversationMessageId: Int64;
begin
  Result := fData.Get('conversation_message_id', Integer(0));
end;

function TVKMessageReply.GetMessageID: Int64;
begin
  Result := fData.Get('id', Int64(0));
end;

function TVKMessageReply.GetText: string;
begin
  Result := fData.Get('text', EmptyStr);
end;

function TVKMessageReply.GetPeerID: Int64;
begin
  Result := fData.Get('peer_id', Int64(0));
end;

function TVKMessageReply.GetFromID: Int64;
begin
  Result := fData.Get('from_id', Int64(0));
end;

procedure TVKMessageReply.Reply(const aText: string; const aKeyboard: string = '');
begin
  Send(aText, PeerID, aKeyboard);
end;

procedure TVKMessageReply.Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');
begin
  fBot.SendMessage(specialize IfThen<Int64>(aPeerID = 0, PeerID, aPeerID), aText, aKeyboard);
end;

{ TStringHash }

class function TStringHash.hash(s: String; n: Integer): Integer;
var
  c: Char;
begin
  Result := 0;
  for c in s do
    Inc(Result, Ord(c));
  Result := Result mod n;
end;

{ TEventTypeHash }

class function TEventTypeHash.hash(s: TVKEventType; n: Integer): Integer;
begin
  Result := Ord(s) mod n;
end;

{ TVKBot }

constructor TVKBot.Create(const aToken: string; aGroupID: Int64);
begin
  inherited Create;
  fToken      := aToken;
  fGroupID    := aGroupID;
  fAPIVersion := VK_API_VERSION;
  fRunning    := False;

  fCommands             := TCommandMap.Create;
  fEventHandlers        := TEventMap.Create;
end;

destructor TVKBot.Destroy;
begin
  Stop;
  fCommands.Free;
  fEventHandlers.Free;
  fJSON.Free;
  inherited;
end;

function TVKBot.APICall(const aMethod: string; const aParams: TJSONObject): TJSONData;
var
  aURL, aResponse: string;
  i: Integer;
  aHTTPClient: TBaseHTTPClient;
begin
  Result := nil;

  aURL := Format('%s%s?access_token=%s&v=%s', [VK_BASE_API_URL, aMethod, fToken, fAPIVersion]);

  if Assigned(aParams) then
    for i := 0 to aParams.Count - 1 do
      aURL += Format('&%s=%s', [aParams.Names[i], EncodeURLElement(aParams.Items[i].AsString)]);

  aHTTPClient  := TBaseHTTPClient.GetClientClass.Create(nil);
  try
    FreeAndNil(fJSON);
    aResponse := aHTTPClient.Get(aURL);
    fJSON := GetJSON(aResponse);

    if fJSON is TJSONObject then
      Result := TJSONObject(fJSON).Find('response');

    if not Assigned(Result) then
      DoLog(llError, Format('API call failed: %s, response: %s', [aMethod, aResponse]))
    else
      DoLog(llDebug, Format('API call: %s, response: %s', [aMethod, aResponse]));
  finally
    aHTTPClient.Free;
  end;
end;

procedure TVKBot.DoLog(aLogLevel: TLogLevel; const aMessage: String);
begin
  if Assigned(fOnLog) then
    fOnLog(aLogLevel, aMessage);
end;

{ --- Command handlers --- }

function TVKBot.GetCommandHandler(const aCommand: string): TCommandHandler;
var
  aLower: string;
begin
  aLower := LowerCase(aCommand);
  if fCommands.Contains(aLower) then
    Result := fCommands[aLower]
  else
    Result := nil;
end;

procedure TVKBot.SetCommandHandler(const aCommand: string; aHandler: TCommandHandler);
var
  aLower: string;
begin
  aLower := LowerCase(aCommand);
  if Assigned(aHandler) then
    fCommands[aLower] := aHandler
  else
    fCommands.Delete(aLower);
end;

{ --- Event handlers --- }

function TVKBot.GetEventHandlerByName(const aEventType: String): TEventHandler;
var
  aEvent: TVKEventType;
begin
  aEvent := VKEventTypeFromString(aEventType);
  if fEventHandlers.Contains(aEvent) then
    Result := fEventHandlers[aEvent]
  else
    Result := nil;
end;

function TVKBot.GetEventHandlerByEnum(aEventType: TVKEventType): TEventHandler;
begin
  if fEventHandlers.Contains(aEventType) then
    Result := fEventHandlers[aEventType]
  else
    Result := nil;
end;

procedure TVKBot.SetEventHandlerByEnum(aEventType: TVKEventType; aHandler: TEventHandler);
begin
  if Assigned(aHandler) then
    fEventHandlers[aEventType] := aHandler
  else
    fEventHandlers.Delete(aEventType);
end;

procedure TVKBot.SetEventHandlerByName(const aEventType: String; aHandler: TEventHandler);
var
  aEvent: TVKEventType;
begin
  aEvent := VKEventTypeFromString(aEventType);
  if Assigned(aHandler) then
    fEventHandlers[aEvent] := aHandler
  else
    fEventHandlers.Delete(aEvent);
end;

{ --- Deeplink handlers --- }

procedure TVKBot.DispatchDeeplink(const aMsg: TVKMessage);
var
  aRef, aRefSource: string;
begin
  aRef       := aMsg.Ref;
  aRefSource := aMsg.RefSource;

  if Assigned(fOnDeeplink) then
  begin
    DoLog(llInfo, Format('Deeplink: ref="%s" ref_source="%s" from user %d', [aRef, aRefSource, aMsg.FromID]));
    fOnDeeplink(aMsg, aRef, aRefSource);
    Exit;
  end;

  DoLog(llDebug, Format('Deeplink: нет обработчика для ref="%s"', [aRef]));
end;

procedure TVKBot.InitLongPoll;
var
  aParams: TJSONObject;
  aResponse: TJSONObject;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('group_id', fGroupID);
    aResponse := APICall('groups.getLongPollServer', aParams) as TJSONObject;
    if Assigned(aResponse) then
    begin
      fServer := aResponse.Get('server', EmptyStr);
      fKey    := aResponse.Get('key',    EmptyStr);
      fTS     := aResponse.Get('ts',     Int64(0));
      DoLog(llDebug, Format('LongPoll initialized: server=%s, ts=%d', [fServer, fTS]));
    end;
  finally
    aParams.Free;
  end;
end;

procedure TVKBot.ProcessUpdate(const aUpdate: TJSONObject);
var
  aEventType: TVKEventType;
  aEventObject: TJSONObject;
  aHandler: TEventHandler;
  aEventTypeStr: TJSONStringType;
begin
  aEventTypeStr := aUpdate.Get('type', EmptyStr);
  aEventObject  := aUpdate.Get('object', TJSONObject(nil));

  if not Assigned(aEventObject) then
    Exit;

  aEventType := VKEventTypeFromString(aEventTypeStr);

  if aEventType = etUnknown then
  begin
    DoLog(llWarning, Format('Unknown event type: %s', [aEventTypeStr]));
    Exit;
  end;

  DoLog(llDebug, Format('Processing event: type=%s', [VKEventTypeToString(aEventType)]));
  DoLog(llDebug, 'JSON: '+aUpdate.AsJSON);

  case aEventType of
    etMessageNew:   ProcessMessage(aEventObject.Get('message', TJSONObject(nil)));
    etMessageReply: ProcessMessageReply(aEventObject);
    etMessageEvent: ProcessMessageEvent(aEventObject);
  end;
  if fEventHandlers.Contains(aEventType) then
  begin
    aHandler := fEventHandlers[aEventType];
    aHandler(aEventObject);
  end;
end;

procedure TVKBot.ProcessMessage(const aMessage: TJSONObject);
var
  aMsg: TVKMessage;
  aText, aPayloadStr: string;
  aPayloadJSON: TJSONObject;
  aCommand: string;
  aParts: TStringArray;
  aCmdHandler: TCommandHandler;
  aArgs: TStringArray;
begin
  if not Assigned(aMessage) then Exit;

  aMsg := TVKMessage.Create(Self, aMessage);
  try
    { --- Deeplink: if the message is received via vk.me?ref=... ---
    We call the deeplink handler FIRST, but DO NOT interrupt the pipeline:
          the message continues to be processed as usual (commands, handlers).
          This allows, for example, to activate a referral and at the same time
          run the /start command. }
    if not aMsg.Ref.IsEmpty then
      DispatchDeeplink(aMsg);

    aPayloadStr := aMsg.GetPayload;
    if aPayloadStr <> '' then
    begin
      aPayloadJSON := GetJSON(aPayloadStr) as TJSONObject;
      if Assigned(aPayloadJSON) then
      begin
        aCommand := LowerCase(aPayloadJSON.Get('command', EmptyStr));
        if (aCommand <> '') and fCommands.GetValue(aCommand, aCmdHandler) then
        begin
          aCmdHandler(aMsg, []);
          DoLog(llInfo, Format('Button command: %s by user %d', [aCommand, aMsg.FromID]));
          aPayloadJSON.Free;
          Exit;
        end;
        aPayloadJSON.Free;
      end;
    end;

    aText := Trim(aMsg.Text);
    if (Length(aText) > 0) and (aText[1] = '/') then
    begin
      aParts := aText.Split([' ']);
      if Length(aParts) > 0 then
      begin
        aCommand := LowerCase(Copy(aParts[0], 2, MaxInt));
        if fCommands.Contains(aCommand) then
        begin
          aCmdHandler := fCommands[aCommand];
          if Length(aParts) > 1 then
            aArgs := Copy(aParts, 1, Length(aParts) - 1)
          else
            SetLength(aArgs, 0);
          aCmdHandler(aMsg, aArgs);
          DoLog(llInfo, Format('Text command: /%s by user %d', [aCommand, aMsg.FromID]));
          Exit;
        end;
      end;
    end;

    if Assigned(fOnMessage) then
      fOnMessage(aMsg);

  finally
    aMsg.Free;
  end;
end;

procedure TVKBot.ProcessMessageEvent(const aEventObject: TJSONObject);
var
  aEvt: TVKMessageEvent;
begin
  if not Assigned(aEventObject) then Exit;

  aEvt := TVKMessageEvent.Create(Self, aEventObject);
  try
    if Assigned(fOnMessageEvent) then
      fOnMessageEvent(aEvt);
  finally
    aEvt.Free;
  end;
end;

procedure TVKBot.ProcessMessageReply(const aReplyObject: TJSONObject);
var
  aReply: TVKMessageReply;
begin
  if not Assigned(aReplyObject) then Exit;

  aReply := TVKMessageReply.Create(Self, aReplyObject);
  try
    if Assigned(fOnMessageReply) then
      fOnMessageReply(aReply);
  finally
    aReply.Free;
  end;
end;

procedure TVKBot.Start;
var
  aURL, aResponse: string;
  aJSON: TJSONData;
  aUpdates: TJSONArray;
  i: Integer;
  aHTTPClient: TBaseHTTPClient;
begin
  if fRunning then Exit;

  if fGroupID = 0 then
    raise Exception.Create('GroupID is required for LongPoll mode');

  DoLog(llInfo, 'Starting VK Bot in LongPoll mode...');
  InitLongPoll;
  fRunning := True;
  DoLog(llInfo, Format('Bot started. GroupID: %d, API v%s', [fGroupID, fAPIVersion]));

  aHTTPClient := TBaseHTTPClient.GetClientClass.Create(nil);
  try
    while fRunning do
    begin
      try
        aURL := Format('%s?act=a_check&key=%s&ts=%d&wait=%d', [fServer, fKey, fTS, VK_LONG_POLL_WAIT]);

        aResponse := aHTTPClient.Get(aURL);
        aJSON     := GetJSON(aResponse);

        if aJSON is TJSONObject then
        begin
          fTS      := TJSONObject(aJSON).Int64s['ts'];
          aUpdates := TJSONObject(aJSON).Get('updates', TJSONArray(nil));
          if Assigned(aUpdates) then
            for i := 0 to aUpdates.Count - 1 do
              if aUpdates[i] is TJSONObject then
                ProcessUpdate(TJSONObject(aUpdates[i]));
        end;

        aJSON.Free;
      except
        on E: Exception do
        begin
          DoLog(llError, Format('LongPoll error: %s', [E.Message]));
          Sleep(1000);
          InitLongPoll;
        end;
      end;
    end;
  finally
    aHTTPClient.Free;
  end;
end;

procedure TVKBot.Stop;
begin
  fRunning := False;
end;

function TVKBot.SendMessage(aPeerID: Int64; const aText: string; const aKeyboard: string = ''): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id',   aPeerID);
    aParams.Add('message',   aText);
    aParams.Add('random_id', DateTimeToUnix(Now) * 1000 + Random(1000));
    if not aKeyboard.IsEmpty then
      aParams.Add('keyboard', aKeyboard);
    Result := Assigned(APICall('messages.send', aParams));
  finally
    aParams.Free;
  end;
end;
function TVKBot.EditMessage(aPeerID, aMessageID: Int64; const aText: string; const aKeyboard: string = ''): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id',    aPeerID);
    aParams.Add('message_id', aMessageID);
    aParams.Add('message',    aText);
    if not aKeyboard.IsEmpty then
      aParams.Add('keyboard', aKeyboard);
    Result := Assigned(APICall('messages.edit', aParams));
  finally
    aParams.Free;
  end;
end;
function TVKBot.DeleteMessage(aPeerID, aMessageID: Int64; aDeleteForAll: Boolean = False): Boolean;
begin
  Result := DeleteMessage(aPeerID, [aMessageID], aDeleteForAll);
end;

function TVKBot.DeleteMessage(aPeerID: Int64; const aMessageIDs: array of Int64;
  aDeleteForAll: Boolean = False): Boolean;
var
  aParams: TJSONObject;
  i: Integer;
  aMessageIDsParam: string;
begin
  Result := False;
  if Length(aMessageIDs) = 0 then
    Exit;

  aMessageIDsParam := EmptyStr;
  for i := Low(aMessageIDs) to High(aMessageIDs) do
  begin
    if not aMessageIDsParam.IsEmpty then
      aMessageIDsParam += ',';
    aMessageIDsParam += IntToStr(aMessageIDs[i]);
  end;

  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    aParams.Add('message_ids', aMessageIDsParam);
    if aDeleteForAll then
      aParams.Add('delete_for_all', 1);
    Result := Assigned(APICall('messages.delete', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetMessagesUploadServer(const aType: string = 'doc'; aPeerID: Int64 = 0): TJSONData;
var
  aParams: TJSONObject;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('type', aType);
    if aPeerID > 0 then
      aParams.Add('peer_id', aPeerID);

    Result := APICall('docs.getMessagesUploadServer', aParams);
  finally
    aParams.Free;
  end;
end;


{ TVKKeyboard }

constructor TVKKeyboard.Create(aOneTime: Boolean = False; aInline: Boolean = False);
begin
  inherited Create;
  fButtons := TJSONArray.Create;
  fOneTime := aOneTime;
  fInline  := aInline;
  AddRow;
end;

destructor TVKKeyboard.Destroy;
begin
  fButtons.Free;
  inherited;
end;

function TVKKeyboard.AddButton(const aLabel: string; aColor: TVKButtonColor; aType: TVKButtonType;
  const aPayload: string): TVKKeyboard;
var
  aCurrentRow: TJSONArray;
  aButton, aAction: TJSONObject;
begin
  if fButtons.Count = 0 then AddRow;
  aCurrentRow := fButtons.Items[fButtons.Count - 1] as TJSONArray;

  aButton := TJSONObject.Create;
  aAction := TJSONObject.Create;
  aAction.Add('type', VKButtonTypeToString(aType));
  aAction.Add('label', aLabel);
  if aPayload <> '' then
    aAction.Add('payload', aPayload);
  aButton.Add('action', aAction);
  aButton.Add('color', VKButtonColorToString(aColor));
  aCurrentRow.Add(aButton);
  Result := Self;
end;

function TVKKeyboard.AddRow: TVKKeyboard;
begin
  fButtons.Add(TJSONArray.Create);
  Result := Self;
end;

function TVKKeyboard.Build: string;
var
  aKeyboard: TJSONObject;
begin
  aKeyboard := TJSONObject.Create;
  try
    aKeyboard.Add('one_time', fOneTime);
    aKeyboard.Add('inline',   fInline);
    aKeyboard.Add('buttons',  fButtons.Clone);
    Result := aKeyboard.AsJSON;
  finally
    aKeyboard.Free;
  end;
end;

end.
