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

    { aReplyTo — conversation_message_id of the message to quote
      (use ConversationMessageId of an incoming message) }
    procedure Reply(const aText: string; const aKeyboard: string = ''; const aAttachment: string = '';
      aReplyTo: Int64 = 0);
    procedure Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '';
      const aAttachment: string = ''; aReplyTo: Int64 = 0);

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
    procedure Reply(const aText: string; const aKeyboard: string = ''; const aAttachment: string = '';
      aReplyTo: Int64 = 0);
    { Acknowledge/callback answer for inline button click (messages.sendMessageEventAnswer) }
    function Answer(const aType: TVKEventDataType = dtUnspecified; const aText: string = '';
      const aKeyboard: String = ''; const aLink: string = ''): Boolean;

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
    procedure Reply(const aText: string; const aKeyboard: string = ''; const aAttachment: string = '';
      aReplyTo: Int64 = 0);
    procedure Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '';
      const aAttachment: string = ''; aReplyTo: Int64 = 0);

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

  TDocFileType = (dfUnspecified, dfDoc, dfAudioMessage);

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
    fTS: Int64;
    procedure ProcessMessage(const aMessage: TJSONObject);
    procedure ProcessMessageEvent(const aEventObject: TJSONObject);
    procedure ProcessMessageReply(const aReplyObject: TJSONObject);
    { Apply one LongPoll reply: dispatch updates, advance ts,
      re-init the session on failed=2/3 }
    procedure ProcessLongPollResponse(aRoot: TJSONObject);
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
    { aReplyTo — conversation_message_id of the message to quote (0 = plain send) }
    function SendMessage(aPeerID: Int64; const aText: string; const aKeyboard: string = '';
      const aAttachment: string = ''; aReplyTo: Int64 = 0): Boolean;
    { Fetch recent dialog history (messages.getHistory), caller-owned result }
    function GetHistory(aPeerID: Int64; aCount: Integer = 20; aOffset: Int64 = 0): TJSONData;
    { Pin/unpin the chat's pinned message (aConversationMessageID = cmid) }
    function PinMessage(aPeerID, aConversationMessageID: Int64): Boolean;
    function UnpinMessage(aPeerID: Int64): Boolean;
    { "typing..." indicator: aType is 'typing' or 'audiomessage' }
    function SetActivity(aPeerID: Int64; const aType: string = 'typing'): Boolean;
    { Group chats (Telegram supergroup equivalents) }
    { Create a multi-chat with the users, returns chat_id (0 on failure).
      Peer for the new chat is 2000000000 + chat_id. }
    function CreateChat(const aUserIDs: array of Int64; const aTitle: string): Int64;
    function EditChatTitle(aChatID: Int64; const aTitle: string): Boolean;
    { Chat info / member list (caller-owned results) }
    function GetConversationById(aPeerID: Int64): TJSONData;
    function GetConversationMembers(aPeerID: Int64; const aFields: string = '';
      aCount: Integer = 200; aOffset: Int64 = 0): TJSONData;
    { Group info and membership (subscription checks for Telegram mirrors).
      aGroupID = 0 means the bot's own group (fGroupID / token owner). }
    function GetGroupInfo(aGroupID: Int64 = 0; const aFields: string = ''): TJSONData;
    function IsMember(aUserID: Int64; aGroupID: Int64 = 0): Boolean;
    function GetGroupMembers(aGroupID: Int64 = 0; aCount: Integer = 1000;
      aOffset: Int64 = 0): TJSONData;
    { Resolve a short name (vk.com/<screen_name>) to a user/group id,
      caller-owned result; nil when the name is unknown }
    function ResolveScreenName(const aScreenName: string): TJSONData;
    { VK server unix time (no token required by VK) }
    function GetServerTime: Int64;
    { You can specify MessageID or CMID (conversation_message_id) to indentify message to edit.
    For example You can pass MessageID as 0 and CMID as some nonzero value }
    function EditMessage(aPeerID, aMessageID: Int64; const aText: string; aCMID: Int64 = 0;
      const aKeyboard: string = ''): Boolean;
    function DeleteMessage(aPeerID, aMessageID: Int64; aDeleteForAll: Boolean = False): Boolean; overload;
    function DeleteMessage(aPeerID: Int64; const aMessageIDs: array of Int64;
      aDeleteForAll: Boolean = False): Boolean; overload;
    function SendMessageEventAnswer(aUserID, aPeerID: Int64; const aEventID: string;
      const aType: TVKEventDataType = dtShowSnackbar; const aText: string = ''; const aKeyboard: String = '';
      const aLink: string = ''): Boolean;
    { These three return a CALLER-OWNED copy of the "response" field —
      free the result when done. nil when the API call failed.
      RawResponse keeps the bot-owned JSON of the very last APICall. }
    function GetMessagesUploadServer(const aType: TDocFileType = dfUnspecified; aPeerID: Int64 = 0): TJSONData;
    function DocsSave(const aFile: string; const aTitle: string = ''; const aTags: string = ''): TJSONData;
    function UsersGet(const aUserIDs: string; const aFields: string = ''): TJSONData;

    { --- Media upload pipelines (mirror of Telegram bot media sending) ---
      Each Upload* helper runs the full VK upload chain and returns the
      attachment string ("photo<owner>_<id>", "audio_message<owner>_<id>",
      "doc<owner>_<id>") usable as SendMessage aAttachment — or '' when
      any step failed. The Send* one-shots upload a file from disk and
      send it in a single call. }
    function GetPhotosUploadServer(aPeerID: Int64 = 0): TJSONData;
    { Raw multipart upload to a previously obtained upload_url.
      Returns the server response body ('' on network failure). }
    function UploadFile(const aUploadURL, aFieldName, aFileName: string): string;
    function UploadPhoto(aPeerID: Int64; const aFileName: string): string;
    function UploadDoc(aPeerID: Int64; const aFileName: string; const aTitle: string = '';
      const aTags: string = ''; aVoice: Boolean = False): string;
    function SendPhoto(aPeerID: Int64; const aFileName: string; const aCaption: string = ''): Boolean;
    function SendVoiceMessage(aPeerID: Int64; const aFileName: string): Boolean;
    function SendDocument(aPeerID: Int64; const aFileName: string; const aTitle: string = ''): Boolean;

    property OnDeeplink: TDeeplinkHandler read fOnDeeplink write fOnDeeplink;

    property Token:   string  read fToken write fToken;
    property GroupID: Int64   read fGroupID write fGroupID;
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
    { delete empty rows...? }
    procedure DeleteEmptyRows;
  public
    constructor Create(aOneTime: Boolean = False; aInline: Boolean = False);
    destructor Destroy; override;

    function AddButton(const aLabel: string; aColor: TVKButtonColor=bcUnspecified; aType: TVKButtonType=btText;
      const aPayload: string=''; const aLink: String = ''): TVKKeyboard;
    function AddOpenLinkButton(const aLabel: string; const aLink: String = ''): TVKKeyboard;
    function AddRow: TVKKeyboard;
    function Build: string;

    property OneTime: Boolean read fOneTime write fOneTime;
    property Inline:  Boolean read fInline  write fInline;
  end;

implementation

uses
  DateUtils, VKFCLHTTPClientBroker
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
  Result := fData.Get('conversation_message_id', Int64(0));
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

procedure TVKMessage.Reply(const aText: string; const aKeyboard: string; const aAttachment: string;
  aReplyTo: Int64);
begin
  Send(aText, PeerID, aKeyboard, aAttachment, aReplyTo);
end;

procedure TVKMessage.Send(const aText: string; aPeerID: Int64; const aKeyboard: string;
  const aAttachment: string; aReplyTo: Int64);
begin
  fBot.SendMessage(specialize IfThen<Int64>(aPeerID = 0, PeerID, aPeerID), aText, aKeyboard, aAttachment, aReplyTo);
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
  Result := fData.Get('conversation_message_id', Int64(0));
end;

function TVKMessageEvent.GetPayload: TJSONObject;
begin
  Result := fData.Get('payload', TJSONObject(nil));
end;

procedure TVKMessageEvent.Reply(const aText: string; const aKeyboard: string; const aAttachment: string;
  aReplyTo: Int64);
begin
  fBot.SendMessage(PeerID, aText, aKeyboard, aAttachment, aReplyTo);
end;

function TVKMessageEvent.Answer(const aType: TVKEventDataType; const aText: string; const aKeyboard: String;
  const aLink: string): Boolean;
begin
  Result := fBot.SendMessageEventAnswer(UserID, PeerID, EventID, aType, aText, aKeyboard, aLink);
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
  Result := fData.Get('conversation_message_id', Int64(0));
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

procedure TVKMessageReply.Reply(const aText: string; const aKeyboard: string; const aAttachment: string;
  aReplyTo: Int64);
begin
  Send(aText, PeerID, aKeyboard, aAttachment, aReplyTo);
end;

procedure TVKMessageReply.Send(const aText: string; aPeerID: Int64; const aKeyboard: string;
  const aAttachment: string; aReplyTo: Int64);
begin
  fBot.SendMessage(specialize IfThen<Int64>(aPeerID = 0, PeerID, aPeerID), aText, aKeyboard, aAttachment, aReplyTo);
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
  i, aAttempt: Integer;
  aErrCode: Integer;
  aDelayMs: Integer;
  aStartMs: QWord;
  aErrObj: TJSONData;
  aHTTPClient: TBaseHTTPClient;

  { Retry pause for a VK error code; 0 = do not retry }
  function ErrorRetryDelay(aCode: Integer): Integer;
  begin
    case aCode of
      6:  Result := VK_API_RETRY_ERR6_MS;
      9:  Result := VK_API_RETRY_ERR9_MS;
      10: Result := VK_API_RETRY_ERR10_MS;
      29: Result := VK_API_RETRY_ERR29_MS;
    else
      Result := 0;
    end;
  end;

begin
  Result := nil;

  aURL := Format('%s%s?access_token=%s&v=%s', [VK_BASE_API_URL, aMethod, fToken, fAPIVersion]);

  if Assigned(aParams) then
    for i := 0 to aParams.Count - 1 do
      aURL += Format('&%s=%s', [aParams.Names[i], EncodeURLElement(aParams.Items[i].AsString)]);

  FreeAndNil(fJSON);
  for aAttempt := 1 to VK_API_MAX_ATTEMPTS do
  begin
    aResponse := EmptyStr;
    try
      aStartMs := GetTickCount64;
      aHTTPClient := TBaseHTTPClient.GetClientClass.Create(nil);
      try
        aResponse := aHTTPClient.Get(aURL);
      finally
        aHTTPClient.Free;
      end;
    except
      on E: Exception do
      begin
        if aAttempt < VK_API_MAX_ATTEMPTS then
        begin
          aDelayMs := VK_API_RETRY_NETWORK_MS * aAttempt;
          DoLog(llWarning, Format('API call %s attempt %d/%d failed (%s: %s), retrying in %d ms',
            [aMethod, aAttempt, VK_API_MAX_ATTEMPTS, E.ClassName, E.Message, aDelayMs]));
          Sleep(aDelayMs);
          Continue;
        end;
        DoLog(llError, Format('API call failed: %s, network error after %d attempts (%s: %s)',
          [aMethod, VK_API_MAX_ATTEMPTS, E.ClassName, E.Message]));
        Exit(nil);
      end;
    end;

    try
      fJSON := GetJSON(aResponse);
    except
      FreeAndNil(fJSON);
      if aAttempt < VK_API_MAX_ATTEMPTS then
      begin
        DoLog(llWarning, Format('API call %s attempt %d/%d returned invalid JSON, retrying',
          [aMethod, aAttempt, VK_API_MAX_ATTEMPTS]));
        Sleep(VK_API_RETRY_NETWORK_MS);
        Continue;
      end;
      DoLog(llError, Format('API call failed: %s, invalid JSON after %d attempts, response: %s',
        [aMethod, VK_API_MAX_ATTEMPTS, aResponse]));
      Exit(nil);
    end;

    if fJSON is TJSONObject then
      Result := TJSONObject(fJSON).Find('response')
    else
      Result := nil;

    if Assigned(Result) then
    begin
      DoLog(llDebug, Format('API call: %s (%d ms), response: %s',
        [aMethod, GetTickCount64 - aStartMs, aResponse]));
      Exit;
    end;

    aErrCode := 0;
    if fJSON is TJSONObject then
    begin
      aErrObj := TJSONObject(fJSON).Find('error');
      if aErrObj is TJSONObject then
        aErrCode := TJSONObject(aErrObj).Get('error_code', 0);
    end;
    aDelayMs := ErrorRetryDelay(aErrCode);

    if (aDelayMs > 0) and (aAttempt < VK_API_MAX_ATTEMPTS) then
    begin
      DoLog(llWarning, Format('API call %s attempt %d/%d failed with VK error %d, retrying in %d ms',
        [aMethod, aAttempt, VK_API_MAX_ATTEMPTS, aErrCode, aDelayMs]));
      FreeAndNil(fJSON);
      Result := nil;
      Sleep(aDelayMs);
      Continue;
    end;

    DoLog(llError, Format('API call failed: %s, response: %s', [aMethod, aResponse]));
    Exit(nil);
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
      { Payload comes from the client side: broken JSON must not abort
        the update batch, so fall back to the usual pipeline }
      try
        aPayloadJSON := GetJSON(aPayloadStr) as TJSONObject;
      except
        on E: Exception do
        begin
          DoLog(llWarning, Format('Invalid message payload: %s', [E.Message]));
          aPayloadJSON := nil;
        end;
      end;
      if Assigned(aPayloadJSON) then
      try
        aCommand := LowerCase(aPayloadJSON.Get('command', EmptyStr));
        if (aCommand <> '') and fCommands.GetValue(aCommand, aCmdHandler) then
        begin
          aCmdHandler(aMsg, []);
          DoLog(llInfo, Format('Button command: %s by user %d', [aCommand, aMsg.FromID]));
          Exit;
        end;
      finally
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
        try
          if aJSON is TJSONObject then
            ProcessLongPollResponse(TJSONObject(aJSON));
        finally
          aJSON.Free;
        end;
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

procedure TVKBot.ProcessLongPollResponse(aRoot: TJSONObject);
var
  aFailed: Int64;
  aUpdates: TJSONArray;
  i: Integer;
begin
  aFailed := aRoot.Get('failed', Int64(0));
  case aFailed of
    0:
      begin
        fTS := aRoot.Get('ts', fTS);
        aUpdates := aRoot.Get('updates', TJSONArray(nil));
        if Assigned(aUpdates) then
          for i := 0 to aUpdates.Count - 1 do
            if aUpdates[i] is TJSONObject then
              ProcessUpdate(TJSONObject(aUpdates[i]));
      end;
    1:
      begin
        { history partly lost — continue from the ts VK suggests }
        DoLog(llWarning, 'LongPoll: history expired (failed=1)');
        fTS := aRoot.Get('ts', fTS);
      end;
  else
    begin
      { failed=2/3: key or server is no longer valid }
      DoLog(llWarning, Format('LongPoll: failed=%d, re-initializing session', [aFailed]));
      InitLongPoll;
    end;
  end;
end;

procedure TVKBot.Stop;
begin
  fRunning := False;
end;

{ Monotonic random_id: VK silently drops a message whose random_id it has
  already seen, so ids must stay unique. Seeded from the wall clock in the
  initialization section below to survive process restarts. }
var
  _RandomID: Int64 = 0;

function NextRandomID: Int64;
begin
  Inc(_RandomID);
  Result := _RandomID;
end;

function TVKBot.SendMessage(aPeerID: Int64; const aText: string; const aKeyboard: string;
  const aAttachment: string; aReplyTo: Int64): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id',   aPeerID);
    aParams.Add('message',   aText);
    aParams.Add('random_id', NextRandomID);
    if not aKeyboard.IsEmpty then
      aParams.Add('keyboard', aKeyboard);
    if not aAttachment.IsEmpty then
      aParams.Add('attachment', aAttachment);
    if aReplyTo <> 0 then
      aParams.Add('reply_to', aReplyTo);
    Result := Assigned(APICall('messages.send', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetHistory(aPeerID: Int64; aCount: Integer; aOffset: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    aParams.Add('count',   aCount);
    if aOffset > 0 then
      aParams.Add('offset', aOffset);

    aResponse := APICall('messages.getHistory', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.PinMessage(aPeerID, aConversationMessageID: Int64): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  if aConversationMessageID = 0 then
    Exit;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    aParams.Add('conversation_message_id', aConversationMessageID);
    Result := Assigned(APICall('messages.pin', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.UnpinMessage(aPeerID: Int64): Boolean;
var
  aParams: TJSONObject;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    Result := Assigned(APICall('messages.unpin', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.SetActivity(aPeerID: Int64; const aType: string): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  if aType.IsEmpty then
    Exit;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    aParams.Add('type',    aType);
    Result := Assigned(APICall('messages.setActivity', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.CreateChat(const aUserIDs: array of Int64; const aTitle: string): Int64;
var
  aParams: TJSONObject;
  aIDs: string;
  i: Integer;
  aResponse: TJSONData;
begin
  Result := 0;
  if aTitle.IsEmpty or (Length(aUserIDs) = 0) then
    Exit;

  aIDs := EmptyStr;
  for i := Low(aUserIDs) to High(aUserIDs) do
  begin
    if not aIDs.IsEmpty then
      aIDs += ',';
    aIDs += IntToStr(aUserIDs[i]);
  end;

  aParams := TJSONObject.Create;
  try
    aParams.Add('user_ids', aIDs);
    aParams.Add('title',    aTitle);
    aResponse := APICall('messages.createChat', aParams);
    if Assigned(aResponse) then
      Result := aResponse.AsInteger;
  finally
    aParams.Free;
  end;
end;

function TVKBot.EditChatTitle(aChatID: Int64; const aTitle: string): Boolean;
var
  aParams: TJSONObject;
begin
  Result := False;
  if (aChatID <= 0) or aTitle.IsEmpty then
    Exit;
  aParams := TJSONObject.Create;
  try
    aParams.Add('chat_id', aChatID);
    aParams.Add('title',   aTitle);
    Result := Assigned(APICall('messages.editChat', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetConversationById(aPeerID: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_ids', aPeerID);
    aResponse := APICall('messages.getConversationsById', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetConversationMembers(aPeerID: Int64; const aFields: string;
  aCount: Integer; aOffset: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id', aPeerID);
    if not aFields.IsEmpty then
      aParams.Add('fields', aFields);
    aParams.Add('count',   aCount);
    if aOffset > 0 then
      aParams.Add('offset', aOffset);

    aResponse := APICall('messages.getConversationMembers', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetGroupInfo(aGroupID: Int64; const aFields: string): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    if aGroupID = 0 then
      aGroupID := fGroupID;
    if aGroupID > 0 then
      aParams.Add('group_id', aGroupID);
    if not aFields.IsEmpty then
      aParams.Add('fields', aFields);

    aResponse := APICall('groups.getById', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.IsMember(aUserID: Int64; aGroupID: Int64): Boolean;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  Result := False;
  if aGroupID = 0 then
    aGroupID := fGroupID;
  if (aUserID = 0) or (aGroupID = 0) then
    Exit;

  aParams := TJSONObject.Create;
  try
    aParams.Add('group_id', aGroupID);
    aParams.Add('user_id',  aUserID);
    aResponse := APICall('groups.isMember', aParams);
    if Assigned(aResponse) then
      Result := aResponse.AsInteger <> 0;
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetGroupMembers(aGroupID: Int64; aCount: Integer; aOffset: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    if aGroupID = 0 then
      aGroupID := fGroupID;
    if aGroupID > 0 then
      aParams.Add('group_id', aGroupID);
    aParams.Add('count', aCount);
    if aOffset > 0 then
      aParams.Add('offset', aOffset);

    aResponse := APICall('groups.getMembers', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.ResolveScreenName(const aScreenName: string): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  Result := nil;
  if aScreenName.IsEmpty then
    Exit;

  aParams := TJSONObject.Create;
  try
    aParams.Add('screen_name', aScreenName);
    aResponse := APICall('utils.resolveScreenName', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone;
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetServerTime: Int64;
var
  aResponse: TJSONData;
begin
  Result := 0;
  aResponse := APICall('utils.getServerTime', nil);
  if Assigned(aResponse) then
    Result := aResponse.AsInteger;
end;
function TVKBot.EditMessage(aPeerID, aMessageID: Int64; const aText: string; aCMID: Int64; const aKeyboard: string
  ): Boolean;
var
  aParams: TJSONObject;
begin
  Result  := False;
  aParams := TJSONObject.Create;
  try
    aParams.Add('peer_id',    aPeerID);
    if aMessageID<>0 then
      aParams.Add('message_id', aMessageID);
    if aCMID<>0 then
      aParams.Add('cmid', aCMID);
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

function TVKBot.SendMessageEventAnswer(aUserID, aPeerID: Int64; const aEventID: string; const aType: TVKEventDataType;
  const aText: string; const aKeyboard: String; const aLink: string): Boolean;
var
  aParams: TJSONObject;
  aEventData: TJSONObject;
begin
  Result := False;
  if (aUserID = 0) or (aPeerID = 0) or aEventID.IsEmpty then
    Exit;

  aParams := TJSONObject.Create;
  try
    aParams.Add('user_id', aUserID);
    aParams.Add('peer_id', aPeerID);
    aParams.Add('event_id', aEventID);

    if (aType<>dtUnspecified) or (not aText.IsEmpty) or (not aKeyboard.IsEmpty) or (not aLink.IsEmpty) then
    begin
      aEventData := TJSONObject.Create;
      if aType<>dtUnspecified then
        aEventData.Add('type', VKEventDataTypeToString(aType));
      if not aText.IsEmpty then
        aEventData.Add('text', aText);
      if not aLink.IsEmpty then
        aEventData.Add('link', aLink); 
      if not aKeyboard.IsEmpty then
        aEventData.Add('keyboard', aKeyboard);
      aParams.Add('event_data', aEventData.AsJSON);
      aEventData.Free;
    end;

    Result := Assigned(APICall('messages.sendMessageEventAnswer', aParams));
  finally
    aParams.Free;
  end;
end;

function TVKBot.GetMessagesUploadServer(const aType: TDocFileType; aPeerID: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    case aType of
      dfDoc:   aParams.Add('type', 'doc');
      dfAudioMessage: aParams.Add('type', 'audio_message');
    end;
    if aPeerID > 0 then
      aParams.Add('peer_id', aPeerID);

    aResponse := APICall('docs.getMessagesUploadServer', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.DocsSave(const aFile: string; const aTitle: string; const aTags: string): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    aParams.Add('file', aFile);
    if not aTitle.IsEmpty then
      aParams.Add('title', aTitle);
    if not aTags.IsEmpty then
      aParams.Add('tags', aTags);

    aResponse := APICall('docs.save', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.UsersGet(const aUserIDs: string; const aFields: string): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    if not aUserIDs.IsEmpty then
      aParams.Add('user_ids', aUserIDs);
    if not aFields.IsEmpty then
      aParams.Add('fields', aFields);

    aResponse := APICall('users.get', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

{ --- Media upload pipelines --- }

function TVKBot.GetPhotosUploadServer(aPeerID: Int64): TJSONData;
var
  aParams: TJSONObject;
  aResponse: TJSONData;
begin
  aParams := TJSONObject.Create;
  try
    if aPeerID > 0 then
      aParams.Add('peer_id', aPeerID);

    aResponse := APICall('photos.getMessagesUploadServer', aParams);
    if Assigned(aResponse) then
      Result := aResponse.Clone
    else
      Result := nil;
  finally
    aParams.Free;
  end;
end;

function TVKBot.UploadFile(const aUploadURL, aFieldName, aFileName: string): string;
var
  aClient: TBaseHTTPClient;
begin
  Result := EmptyStr;
  if aUploadURL.IsEmpty or aFieldName.IsEmpty or aFileName.IsEmpty then
    Exit;

  aClient := TBaseHTTPClient.GetClientClass.Create(nil);
  try
    try
      Result := aClient.PostFile(aUploadURL, aFieldName, aFileName);
      DoLog(llDebug, Format('File uploaded: %s -> %s', [aFileName, aUploadURL]));
    except
      on E: Exception do
      begin
        DoLog(llError, Format('File upload failed: %s, error: %s', [aFileName, E.Message]));
        Result := EmptyStr;
      end;
    end;
  finally
    aClient.Free;
  end;
end;

function TVKBot.UploadPhoto(aPeerID: Int64; const aFileName: string): string;
var
  aUploadServer: TJSONData;
  aUploadURL: string;
  aUploadResp: TJSONData;
  aSaveParams: TJSONObject;
  aSaved: TJSONData;
  aItem: TJSONObject;
begin
  Result := EmptyStr;

  { Step 1: ask VK where to upload the photo }
  aUploadServer := GetPhotosUploadServer(aPeerID);
  if not Assigned(aUploadServer) then
    Exit;
  try
    if not (aUploadServer is TJSONObject) then
      Exit;
    aUploadURL := TJSONObject(aUploadServer).Get('upload_url', EmptyStr);
  finally
    aUploadServer.Free;
  end;
  if aUploadURL.IsEmpty then
    Exit;

  { Step 2: multipart upload to the upload server }
  try
    aUploadResp := GetJSON(UploadFile(aUploadURL, 'photo', aFileName));
  except
    on E: Exception do
    begin
      DoLog(llError, Format('Photo upload failed for %s: %s', [aFileName, E.Message]));
      Exit;
    end;
  end;
  try
    if not (aUploadResp is TJSONObject) then
      Exit;

    { Step 3: save the uploaded photo, extract owner_id/id }
    aSaveParams := TJSONObject.Create;
    try
      aSaveParams.Add('server', TJSONObject(aUploadResp).Get('server', 0));
      aSaveParams.Add('photo',  TJSONObject(aUploadResp).Get('photo', EmptyStr));
      aSaveParams.Add('hash',   TJSONObject(aUploadResp).Get('hash', EmptyStr));
      aSaved := APICall('photos.saveMessagesPhoto', aSaveParams);
    finally
      aSaveParams.Free;
    end;

    if not Assigned(aSaved) then
      Exit;
    if not (aSaved is TJSONArray) or (TJSONArray(aSaved).Count = 0) then
      Exit;
    if not (TJSONArray(aSaved).Items[0] is TJSONObject) then
      Exit;

    aItem  := TJSONObject(TJSONArray(aSaved).Items[0]);
    Result := Format('photo%d_%d', [aItem.Get('owner_id', Int64(0)), aItem.Get('id', Int64(0))]);
  finally
    aUploadResp.Free;
  end;
end;

function TVKBot.UploadDoc(aPeerID: Int64; const aFileName: string; const aTitle: string;
  const aTags: string; aVoice: Boolean): string;
var
  aUploadServer: TJSONData;
  aUploadURL: string;
  aUploadResp: TJSONData;
  aFileKey: string;
  aSaved: TJSONData;
  aItem: TJSONObject;
begin
  Result := EmptyStr;

  if aVoice then
    aUploadServer := GetMessagesUploadServer(dfAudioMessage, aPeerID)
  else
    aUploadServer := GetMessagesUploadServer(dfDoc, aPeerID);
  if not Assigned(aUploadServer) then
    Exit;
  try
    if not (aUploadServer is TJSONObject) then
      Exit;
    aUploadURL := TJSONObject(aUploadServer).Get('upload_url', EmptyStr);
  finally
    aUploadServer.Free;
  end;
  if aUploadURL.IsEmpty then
    Exit;

  try
    aUploadResp := GetJSON(UploadFile(aUploadURL, 'file', aFileName));
  except
    on E: Exception do
    begin
      DoLog(llError, Format('Doc upload failed for %s: %s', [aFileName, E.Message]));
      Exit;
    end;
  end;
  try
    if not (aUploadResp is TJSONObject) then
      Exit;
    aFileKey := TJSONObject(aUploadResp).Get('file', EmptyStr);
  finally
    aUploadResp.Free;
  end;
  if aFileKey.IsEmpty then
    Exit;

  aSaved := DocsSave(aFileKey, aTitle, aTags);
  if not Assigned(aSaved) then
    Exit;
  try
    { docs.save returns a bare array on old API versions and
      {"type":...,"doc":{...}} (or audio_message analog) since ~5.100 }
    if aSaved is TJSONArray then
    begin
      if (TJSONArray(aSaved).Count = 0) or
        not (TJSONArray(aSaved).Items[0] is TJSONObject) then
        Exit;
      aItem := TJSONObject(TJSONArray(aSaved).Items[0]);
    end
    else if aSaved is TJSONObject then
    begin
      if aVoice then
        aItem := TJSONObject(aSaved).Get('audio_message', TJSONObject(nil))
      else
        aItem := TJSONObject(aSaved).Get('doc', TJSONObject(nil));
      if not Assigned(aItem) then
        Exit;
    end
    else
      Exit;

    if aVoice then
      Result := Format('audio_message%d_%d', [aItem.Get('owner_id', Int64(0)), aItem.Get('id', Int64(0))])
    else
      Result := Format('doc%d_%d', [aItem.Get('owner_id', Int64(0)), aItem.Get('id', Int64(0))]);
  finally
    aSaved.Free;
  end;
end;

function TVKBot.SendPhoto(aPeerID: Int64; const aFileName: string; const aCaption: string): Boolean;
var
  aAttachment: string;
begin
  aAttachment := UploadPhoto(aPeerID, aFileName);
  if aAttachment.IsEmpty then
    Exit(False);
  Result := SendMessage(aPeerID, aCaption, EmptyStr, aAttachment);
end;

function TVKBot.SendVoiceMessage(aPeerID: Int64; const aFileName: string): Boolean;
var
  aAttachment: string;
begin
  aAttachment := UploadDoc(aPeerID, aFileName, EmptyStr, EmptyStr, True);
  if aAttachment.IsEmpty then
    Exit(False);
  Result := SendMessage(aPeerID, EmptyStr, EmptyStr, aAttachment);
end;

function TVKBot.SendDocument(aPeerID: Int64; const aFileName: string; const aTitle: string): Boolean;
var
  aAttachment: string;
begin
  aAttachment := UploadDoc(aPeerID, aFileName, aTitle);
  if aAttachment.IsEmpty then
    Exit(False);
  Result := SendMessage(aPeerID, EmptyStr, EmptyStr, aAttachment);
end;


{ TVKKeyboard }

procedure TVKKeyboard.DeleteEmptyRows;
var
  i: Integer;
begin
  for i:=fButtons.Count-1 downto 0 do
    if fButtons.Arrays[i].Count=0 then
      fButtons.Delete(i);
end;

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
  const aPayload: string; const aLink: String): TVKKeyboard;
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
  if not aPayload.IsEmpty then
    aAction.Add('payload', aPayload);
  if not aLink.IsEmpty then
    aAction.Add('link', aLink);
  aButton.Add('action', aAction);
  { VK allows color only for text and callback buttons }
  if (aColor<>bcUnspecified) and (aType in [btText, btCallback]) then
    aButton.Add('color', VKButtonColorToString(aColor));
  aCurrentRow.Add(aButton);
  Result := Self;
end;

function TVKKeyboard.AddOpenLinkButton(const aLabel: string; const aLink: String): TVKKeyboard;
begin
  Result := AddButton(aLabel, bcUnspecified, btOpenLink, EmptyStr, aLink);
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
    DeleteEmptyRows;
    aKeyboard.Add('buttons',  fButtons.Clone);
    Result := aKeyboard.AsJSON;
  finally
    aKeyboard.Free;
  end;
end;

initialization
  { Wall-clock seed keeps random_id unique across process restarts }
  _RandomID := DateTimeToUnix(Now) * 1000;

end.
