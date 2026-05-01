{$mode objfpc}{$H+}{$J-}
unit VKBotFramework;

interface

uses
  SysUtils, Classes, fphttpclient, fpjson, jsonparser, ghashmap, gvector, VKTypes
  ;

type
  TVKMessage = class;
  TVKBot = class;

  { Event handler types }
  TMessageHandler = procedure(const aMessage: TVKMessage) of object;
  TCommandHandler = procedure(const aMessage: TVKMessage; const aArgs: TStringArray) of object;
  TEventHandler = procedure(const aEvent: TJSONObject) of object;

  { HTTP Client abstraction for testing }
  IHTTPClient = interface
    ['{8F3C9A2E-1B4D-4E5F-9C8A-7D6E5F4A3B2C}']
    function Get(const aURL: string): string;
  end;

  { VK Message wrapper }

  { TVKMessage }

  TVKMessage = class
  private
    fData: TJSONObject;
    fBot: TVKBot;
    function GetText: string;
    function GetPeerID: Int64;
    function GetFromID: Int64;
    function GetPayload: string;
  public
    constructor Create(aBot: TVKBot; aData: TJSONObject);

    procedure Reply(const aText: string; const aKeyboard: string = '');
    procedure Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');

    property Text: string read GetText;
    property PeerID: Int64 read GetPeerID;
    property FromID: Int64 read GetFromID;
    property Payload: string read GetPayload;
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

  { Generic map with enum key }
  generic TEventTypeHashMap<T> = class(specialize THashMap<TVKEventType, T, TEventTypeHash>) end;

  TCommandMap = specialize TStringHashMap<TCommandHandler>;
  TEventMap = specialize TEventTypeHashMap<TEventHandler>;
  THandlerList = specialize TVector<TMessageHandler>;

  { Main bot class }

  { TVKBot }

  TVKBot = class
  private
    fJSON: TJSONData;
    fToken: string;
    fGroupID: Int64;
    fAPIVersion: string;
    fCommands: TCommandMap;
    fMessageHandlers: THandlerList;
    fEventHandlers: TEventMap;
    fRunning: Boolean;
    fServer: string;
    fKey: string;
    fTS: Int64;
    fHTTPClient: IHTTPClient; { Optional: for dependency injection in tests or custom scenarios }
    fOnLog: TOnLogEvent;

    procedure InitLongPoll;
    function APICall(const aMethod: string; const aParams: TJSONObject): TJSONData;
    procedure DoLog(aLogLevel: TLogLevel; const aMessage: String); private
    function GetCommandHandler(const aCommand: string): TCommandHandler;
    function GetEventHandler(const aEventType: String): TEventHandler;
    procedure SetCommandHandler(const aCommand: string; aHandler: TCommandHandler);
    function GetEventHandler(aEventType: TVKEventType): TEventHandler;
    procedure SetEventHandler(aEventType: TVKEventType; aHandler: TEventHandler);
    procedure SetEventHandler(const aEventType: String; AValue: TEventHandler);
  protected
    function CreateHTTPClient: IHTTPClient; virtual;
    function GetHTTPClient: IHTTPClient;
    procedure ProcessMessage(const aMessage: TJSONObject);
    property RawJSON: TJSONData read fJSON write fJSON;
    property EventMap: TEventMap read fEventHandlers;
    property CommandMap: TCommandMap read fCommands;
  public
    procedure AddMessageHandler(aHandler: TMessageHandler);

    constructor Create(const aToken: string; aGroupID: Int64 = 0);
    destructor Destroy; override;

    { Bot control - for LongPoll mode }
    procedure Start;
    procedure Stop;

    { Process update - can be called externally (e.g., from webhook) }
    procedure ProcessUpdate(const aUpdate: TJSONObject);

    { API methods }
    function SendMessage(aPeerID: Int64; const aText: string; const aKeyboard: string = ''): Boolean;

    { Testing support: inject custom HTTP client (optional) }
    procedure SetHTTPClient(aClient: IHTTPClient);

    property Token: string read fToken;
    property GroupID: Int64 read fGroupID;
    property Running: Boolean read fRunning;
    property CommandHandlers[const aCommand: string]: TCommandHandler read GetCommandHandler write SetCommandHandler;
    property EventHandlers[aEventType: TVKEventType]: TEventHandler read GetEventHandler write SetEventHandler;
    property EventHandlersByName[const aEventType: String]: TEventHandler read GetEventHandler write SetEventHandler;
    property MessageHandlers: THandlerList read fMessageHandlers;
    property OnLog: TOnLogEvent read fOnLog write fOnLog;
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

    function AddButton(const aLabel: string; aColor: TVKButtonColor = bcSecondary;
      const aPayload: string = ''): TVKKeyboard;
    function AddRow: TVKKeyboard;
    function Build: string;

    property OneTime: Boolean read fOneTime write fOneTime;
    property Inline: Boolean read fInline write fInline;
  end;

implementation

uses
  DateUtils, opensslsockets
  ;

type
  { Standard HTTP client implementation }
  TStandardHTTPClient = class(TInterfacedObject, IHTTPClient)
  private
    FClient: TFPHTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AURL: string): string;
  end;

{ TStandardHTTPClient }

constructor TStandardHTTPClient.Create;
begin
  inherited Create;
  FClient := TFPHTTPClient.Create(nil);
end;

destructor TStandardHTTPClient.Destroy;
begin
  FClient.Free;
  inherited;
end;

function TStandardHTTPClient.Get(const AURL: string): string;
begin
  Result := FClient.Get(AURL);
end;

function EncodeURLParams(aParams: TStringList): string;
var
  i: Integer;
  aEncoded: TStringList;
begin
  aEncoded := TStringList.Create;
  aEncoded.Delimiter := '&';
  try
    for i := 0 to aParams.Count - 1 do
      aEncoded.AddPair(aParams.Names[i], EncodeURLElement(aParams.ValueFromIndex[i]));
    Result := aEncoded.DelimitedText;
  finally
    aEncoded.Free;
  end;
end;

{ TVKMessage }

constructor TVKMessage.Create(aBot: TVKBot; aData: TJSONObject);
begin
  inherited Create;
  fBot := aBot;
  fData := aData;
end;

function TVKMessage.GetText: string;
begin
  Result := fData.Get('text', EmptyStr);
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

procedure TVKMessage.Reply(const aText: string; const aKeyboard: string = '');
begin
  Send(aText, PeerID, aKeyboard);
end;

procedure TVKMessage.Send(const aText: string; aPeerID: Int64 = 0; const aKeyboard: string = '');
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
  fToken := aToken;
  fGroupID := aGroupID;
  fAPIVersion := VK_API_VERSION;
  fRunning := False;

  fCommands := TCommandMap.Create;
  fMessageHandlers := THandlerList.Create;
  fEventHandlers := TEventMap.Create;

  { Note: HTTP client is now created on-demand in GetHTTPClient, not stored as a field }
  { fHTTPClient is kept only for optional dependency injection via SetHTTPClient }
end;

destructor TVKBot.Destroy;
begin
  Stop;
  fCommands.Free;
  fMessageHandlers.Free;
  fEventHandlers.Free;
  fJSON.Free;
  inherited;
end;

procedure TVKBot.AddMessageHandler(aHandler: TMessageHandler);
begin
  fMessageHandlers.PushBack(aHandler);
end;

function TVKBot.CreateHTTPClient: IHTTPClient;
begin
  Result := TStandardHTTPClient.Create;
end;

function TVKBot.GetHTTPClient: IHTTPClient;
begin
  { If a custom client was injected via SetHTTPClient, use it }
  if Assigned(fHTTPClient) then
    Result := fHTTPClient
  else
    { Otherwise create a new temporary client for this call }
    Result := CreateHTTPClient;
end;

procedure TVKBot.SetHTTPClient(aClient: IHTTPClient);
begin
  fHTTPClient := aClient;
end;

function TVKBot.APICall(const aMethod: string; const aParams: TJSONObject): TJSONData;
var
  aURL: string;
  i: Integer;
  aParamStr, aResponse: string;
  aHTTPClient: IHTTPClient;
  aIsTemporary: Boolean;
begin
  Result := nil;

  aURL := Format('%s%s?access_token=%s&v=%s',
    [VK_BASE_API_URL, aMethod, fToken, fAPIVersion]);
  aParamStr := EmptyStr;

  if Assigned(aParams) then
  begin
    for i := 0 to aParams.Count - 1 do
      aParamStr += Format('&%s=%s',
        [aParams.Names[i], EncodeURLElement(aParams.Items[i].AsString)]);
    aURL += aParamStr;
  end;

  { Get HTTP client - either injected or create new temporary instance }
  aHTTPClient := GetHTTPClient;
  aIsTemporary := not Assigned(fHTTPClient);

  try
    FreeAndNil(fJSON);
    aResponse := aHTTPClient.Get(aURL);
    fJSON := GetJSON(aResponse);

    if fJSON is TJSONObject then
      Result := TJSONObject(fJSON).Find('response');

    if not Assigned(Result) then
      DoLog(llError, Format('API call failed: %s, response: %s', [aMethod, aResponse]));
  finally
    { If we created a temporary client (not injected), release reference }
    if aIsTemporary then
      aHTTPClient := nil;
  end;
end;

procedure TVKBot.DoLog(aLogLevel: TLogLevel; const aMessage: String);
begin
  if Assigned(fOnLog) then
    fOnLog(aLogLevel, aMessage);
end;

function TVKBot.GetCommandHandler(const aCommand: string): TCommandHandler;
var
  aLowerCommand: string;
begin
  aLowerCommand := LowerCase(aCommand);
  if fCommands.Contains(aLowerCommand) then
    Result := fCommands[aLowerCommand]
  else
    Result := nil;
end;

function TVKBot.GetEventHandler(const aEventType: String): TEventHandler;
var
  aEvent: TVKEventType;
begin
  aEvent:=VKEventTypeFromString(aEventType);
  if fEventHandlers.Contains(aEvent) then
    Result := fEventHandlers[aEvent]
  else
    Result := nil;
end;

procedure TVKBot.SetCommandHandler(const aCommand: string; aHandler: TCommandHandler);
var
  aLowerCommand: string;
begin
  aLowerCommand := LowerCase(aCommand);
  if Assigned(aHandler) then
    fCommands[aLowerCommand] := aHandler
  else
    fCommands.Delete(aLowerCommand);
end;

function TVKBot.GetEventHandler(aEventType: TVKEventType): TEventHandler;
begin
  if fEventHandlers.Contains(aEventType) then
    Result := fEventHandlers[aEventType]
  else
    Result := nil;
end;

procedure TVKBot.SetEventHandler(aEventType: TVKEventType; aHandler: TEventHandler);
begin
  if Assigned(aHandler) then
    fEventHandlers[aEventType] := aHandler
  else
    fEventHandlers.Delete(aEventType);
end;

procedure TVKBot.SetEventHandler(const aEventType: String; AValue: TEventHandler);
var
  aEvent: TVKEventType;
begin
  aEvent:=VKEventTypeFromString(aEventType);
  if Assigned(AValue) then
    fEventHandlers[aEvent]:=AValue
  else
    fEventHandlers.Delete(aEvent);
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
      fKey := aResponse.Get('key', EmptyStr);
      fTS := aResponse.Get('ts', Int64(0));

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
  aEventObject := aUpdate.Get('object', TJSONObject(nil));

  if not Assigned(aEventObject) then
    Exit;

  aEventType := VKEventTypeFromString(aEventTypeStr);

  if aEventType = etUnknown then
  begin
    DoLog(llWarning, Format('Unknown event type: %s', [aEventTypeStr]));
    Exit;
  end;

  DoLog(llDebug, Format('Processing event: type=%s', [VKEventTypeToString(aEventType)]));

  if aEventType = etMessageNew then
    ProcessMessage(aEventObject.Get('message', TJSONObject(nil)))
  else
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
  aHandler: TCommandHandler;
  aMsgHandler: TMessageHandler;
  aArgs: TStringArray;
  i: Integer;
begin
  if not Assigned(aMessage) then Exit;

  aMsg := TVKMessage.Create(Self, aMessage);
  try
    { Check payload for button CommandMap }
    aPayloadStr := aMsg.GetPayload;
    if aPayloadStr <> '' then
    begin
      aPayloadJSON := GetJSON(aPayloadStr) as TJSONObject;
      if Assigned(aPayloadJSON) then
      begin
        aCommand := LowerCase(aPayloadJSON.Get('command', EmptyStr));
        if (aCommand <> '') then
          if fCommands.GetValue(aCommand, aHandler) then
          begin
            aHandler(aMsg, []);
            DoLog(llInfo, Format('Button command executed: %s by user %d', [aCommand, aMsg.FromID]));
            aPayloadJSON.Free;
            Exit;
          end;
        aPayloadJSON.Free;
      end;
    end;

    { Check text for slash CommandMap }
    aText := Trim(aMsg.Text);
    if (Length(aText) > 0) and (aText[1] = '/') then
    begin
      aParts := aText.Split([' ']);
      if Length(aParts) > 0 then
      begin
        aCommand := LowerCase(Copy(aParts[0], 2, MaxInt));
        if fCommands.Contains(aCommand) then
        begin
          aHandler := fCommands[aCommand];
          if Length(aParts) > 1 then
            aArgs := Copy(aParts, 1, Length(aParts) - 1)
          else
            SetLength(aArgs, 0);
          aHandler(aMsg, aArgs);
          DoLog(llInfo, Format('Text command executed: /%s by user %d', [aCommand, aMsg.FromID]));
          Exit;
        end;
      end;
    end;

    { Call general message handlers }
    if fMessageHandlers.Size > 0 then
      for i := 0 to fMessageHandlers.Size - 1 do
      begin
        aMsgHandler := fMessageHandlers[i];
        aMsgHandler(aMsg);
      end;
  finally
    aMsg.Free;
  end;
end;

procedure TVKBot.Start;
var
  aURL, aResponse: string;
  aJSON: TJSONData;
  aUpdates: TJSONArray;
  i: Integer;
  aHTTPClient: IHTTPClient;
begin
  if fRunning then
    Exit;

  if fGroupID = 0 then
    raise Exception.Create('GroupID is required for LongPoll mode');

  DoLog(llInfo, 'Starting VK Bot in LongPoll mode...');
  InitLongPoll;
  fRunning := True;
  DoLog(llInfo, Format('Bot started. GroupID: %d, API v%s', [fGroupID, fAPIVersion]));

  { Create or get HTTP client for the polling loop }
  aHTTPClient := GetHTTPClient;

  while fRunning do
  begin
    try
      aURL := Format('%s?act=a_check&key=%s&ts=%d&wait=%d',
        [fServer, fKey, fTS, VK_LONG_POLL_WAIT]);

      aResponse := aHTTPClient.Get(aURL);
      aJSON := GetJSON(aResponse);

      if aJSON is TJSONObject then
      begin
        fTS := TJSONObject(aJSON).Int64s['ts'];
        aUpdates := TJSONObject(aJSON).Get('updates', TJSONArray(nil));

        if Assigned(aUpdates) then
        begin
          for i := 0 to aUpdates.Count - 1 do
            if aUpdates[i] is TJSONObject then
              ProcessUpdate(TJSONObject(aUpdates[i]));
        end;
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
end;

procedure TVKBot.Stop;
begin
  fRunning := False;
  DoLog(llInfo, 'Bot stopped');
end;

function TVKBot.SendMessage(aPeerID: Int64; const aText: string;
  const aKeyboard: string = ''): Boolean;
var
  aParams: TJSONObject;
  aRandomID: Int64;
begin
  Result := False;
  aParams := TJSONObject.Create;
  try
    aRandomID := DateTimeToUnix(Now) * 1000 + Random(1000);

    aParams.Add('peer_id', aPeerID);
    aParams.Add('message', aText);
    aParams.Add('random_id', aRandomID);

    if aKeyboard <> '' then
      aParams.Add('keyboard', aKeyboard);

    Result := Assigned(APICall('messages.send', aParams));
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
  fInline := aInline;
  AddRow; // Start with first row
end;

destructor TVKKeyboard.Destroy;
begin
  fButtons.Free;
  inherited;
end;

function TVKKeyboard.AddButton(const aLabel: string; aColor: TVKButtonColor = bcSecondary;
  const aPayload: string = ''): TVKKeyboard;
var
  aCurrentRow: TJSONArray;
  aButton, aAction: TJSONObject;
begin
  if fButtons.Count = 0 then
    AddRow;

  aCurrentRow := fButtons.Items[fButtons.Count - 1] as TJSONArray;

  aButton := TJSONObject.Create;
  aAction := TJSONObject.Create;

  aAction.Add('type', 'text');
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
    aKeyboard.Add('inline', fInline);
    aKeyboard.Add('buttons', fButtons.Clone);
    Result := aKeyboard.AsJSON;
  finally
    aKeyboard.Free;
  end;
end;

end.

