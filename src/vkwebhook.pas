unit VKWebhook;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, fpjson, VKBotFramework, VKTypes
  ;

type
  { Webhook processor - handles VK callback logic }

  { Remembers recently processed callback event ids (FIFO, bounded) so VK
    re-deliveries of an unconfirmed event are ignored instead of being
    processed a second time (each re-processing spends duplicate API
    calls and feeds VK flood control) }
  TVKEventDedup = class
  private
    fMaxCount: Integer;
    fQueue: TStringList;   { keys in arrival order, oldest first }
    fIndex: TStringList;   { sorted copy for O(log n) lookups }
  public
    constructor Create(aMaxCount: Integer);
    destructor Destroy; override;
    { True only the first time aKey is seen; the key is remembered }
    function IsNew(const aKey: string): Boolean;
  end;

  { TVKWebhookProcessor }

  TVKWebhookProcessor = class
  private
    fBot: TVKBot;
    fConfirmationCode: string;
    fDedup: TVKEventDedup;
    fSecret: string;
    fOnLog: TOnLogEvent;

    procedure DoLog(aLevel: TLogLevel; const aMessage: string);
    function ValidateRequest(const aRequest: TVKWebhookRequest): Boolean;
  public
    constructor Create(aBot: TVKBot; const aConfirmationCode: string; const aSecret: string = '');
    destructor Destroy; override;

    { Main webhook processing method }
    { Call this from your HTTP handler with the request body }
    function ProcessWebhook(const aRequestBody: string): TVKWebhookResponse;

    property ConfirmationCode: string read fConfirmationCode write fConfirmationCode;
    property Secret: string read fSecret write fSecret;
    property OnLog: TOnLogEvent read fOnLog write fOnLog;
  end;

implementation

uses
  jsonparser
  ;

{ TVKEventDedup }

constructor TVKEventDedup.Create(aMaxCount: Integer);
begin
  inherited Create;
  fMaxCount := aMaxCount;
  fQueue := TStringList.Create;
  fIndex := TStringList.Create;
  fIndex.Sorted := True;
  fIndex.Duplicates := dupIgnore;
end;

destructor TVKEventDedup.Destroy;
begin
  fQueue.Free;
  fIndex.Free;
  inherited;
end;

function TVKEventDedup.IsNew(const aKey: string): Boolean;
begin
  Result := fIndex.IndexOf(aKey) < 0;
  if not Result then
    Exit;
  fQueue.Add(aKey);
  fIndex.Add(aKey);
  if fQueue.Count > fMaxCount then
  begin
    fIndex.Delete(fIndex.IndexOf(fQueue[0]));
    fQueue.Delete(0);
  end;
end;

{ TVKWebhookProcessor }

constructor TVKWebhookProcessor.Create(aBot: TVKBot; const aConfirmationCode: string; const aSecret: string);
begin
  inherited Create;
  fBot := aBot;
  fConfirmationCode := aConfirmationCode;
  fSecret := aSecret;
  fDedup := TVKEventDedup.Create(VK_WEBHOOK_DEDUP_MAX);
end;

destructor TVKWebhookProcessor.Destroy;
begin
  fDedup.Free;
  inherited;
end;

procedure TVKWebhookProcessor.DoLog(aLevel: TLogLevel; const aMessage: string);
begin
  if Assigned(fOnLog) then
    fOnLog(aLevel, aMessage)
  else if Assigned(fBot) and Assigned(fBot.OnLog) then
    fBot.OnLog(aLevel, aMessage);
end;

function TVKWebhookProcessor.ValidateRequest(const aRequest: TVKWebhookRequest): Boolean;
begin
  Result := True;

  { Validate secret if configured }
  if (fSecret <> EmptyStr) and (aRequest.Secret <> fSecret) then
  begin
    DoLog(llWarning, 'Webhook secret mismatch');
    Result := False;
    Exit;
  end;

  { Validate group ID if bot has one }
  if Assigned(fBot) and (fBot.GroupID > 0) and (aRequest.GroupID <> fBot.GroupID) then
  begin
    DoLog(llWarning, Format('Webhook group_id mismatch: expected %d, got %d', [fBot.GroupID, aRequest.GroupID]));
    Result := False;
  end;
end;

function TVKWebhookProcessor.ProcessWebhook(const aRequestBody: string): TVKWebhookResponse;
var
  aJSON: TJSONData;
  aRoot: TJSONObject;
  aTypeStr: string;
  aRequest: TVKWebhookRequest;
  aUpdate: TJSONObject;
  aEventID: string;
begin
  try
    { Parse JSON }
    aJSON := GetJSON(aRequestBody);
    try
      if not (aJSON is TJSONObject) then
      begin
        DoLog(llError, 'Invalid webhook JSON: not an object');
        Exit(CreateWebhookErrorResponse('Invalid JSON', VK_HTTP_BAD_REQUEST));
      end;

      aRoot := TJSONObject(aJSON);
      aTypeStr := aRoot.Get('type', EmptyStr);

      { Handle confirmation request }
      if aTypeStr = 'confirmation' then
      begin
        DoLog(llInfo, 'Received confirmation request');
        Exit(CreateWebhookConfirmationResponse(fConfirmationCode));
      end;

      { Build request structure }
      aRequest.RawBody := aRequestBody;
      aRequest.EventType := VKEventTypeFromString(aTypeStr);
      aRequest.EventObject := aRoot.Get('object', TJSONObject(nil));
      aRequest.GroupID := aRoot.Get('group_id', Int64(0));
      aRequest.Secret := aRoot.Get('secret', EmptyStr);

      { Validate request }
      if not ValidateRequest(aRequest) then
        Exit(CreateWebhookErrorResponse('Validation failed', VK_HTTP_UNAUTHORIZED));

      { Duplicate protection: VK re-delivers callback events it considers
        unconfirmed (slow or lost webhook reply). Re-processing would spend
        duplicate API calls and feed flood control }
      if Assigned(aRequest.EventObject) then
      begin
        aEventID := aRequest.EventObject.Get('event_id', EmptyStr);
        if (aEventID <> EmptyStr) and not fDedup.IsNew(aTypeStr + ':' + aEventID) then
        begin
          DoLog(llWarning, Format('Duplicate %s event_id %s ignored', [aTypeStr, aEventID]));
          Exit(CreateWebhookOKResponse);
        end;
      end;

      { Process event through bot }
      if Assigned(fBot) then
      begin
        { Create update object in LongPoll format for compatibility }
        aUpdate := TJSONObject.Create;
        try
          aUpdate.Add('type', aTypeStr);
          aUpdate.Add('object', aRequest.EventObject.Clone);

          DoLog(llDebug, Format('Processing webhook event: %s', [aTypeStr]));
          try
            fBot.ProcessUpdate(aUpdate);
          except
            { A handler failure must not turn into a non-200 webhook reply:
              VK counts failed attempts and may disable the callback, and
              its retry would arrive as a duplicate event anyway (ignored
              by the dedup above) }
            on E: Exception do
              DoLog(llError, Format('Event %s processing error. %s:%s',
                [aTypeStr, E.ClassName, E.Message]));
          end;
        finally
          aUpdate.Free;
        end;
      end;

      { Return OK }
      Result := CreateWebhookOKResponse;

    finally
      aJSON.Free;
    end;

  except
    on E: EJSONParser do
    begin
      DoLog(llError, 'Invalid webhook JSON structure');
      Exit(CreateWebhookErrorResponse('Invalid JSON', VK_HTTP_BAD_REQUEST));
    end;
    on E: Exception do
    begin
      DoLog(llError, Format('Webhook processing error. %s:%s', [E.ClassName, E.Message]));
      Result := CreateWebhookErrorResponse(E.Message, VK_HTTP_INTERNAL_ERROR);
    end;
  end;
end;

end.
