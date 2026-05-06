unit VKWebhook;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils, Classes, fpjson, VKBotFramework, VKTypes
  ;

type
  { Webhook processor - handles VK callback logic }

  { TVKWebhookProcessor }

  TVKWebhookProcessor = class
  private
    fBot: TVKBot;
    fConfirmationCode: string;
    fSecret: string;
    fOnLog: TOnLogEvent;

    procedure DoLog(aLevel: TLogLevel; const aMessage: string);
    function ValidateRequest(const aRequest: TVKWebhookRequest): Boolean;
  public
    constructor Create(aBot: TVKBot; const aConfirmationCode: string; const aSecret: string = '');

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

{ TVKWebhookProcessor }

constructor TVKWebhookProcessor.Create(aBot: TVKBot; const aConfirmationCode: string; const aSecret: string);
begin
  inherited Create;
  fBot := aBot;
  fConfirmationCode := aConfirmationCode;
  fSecret := aSecret;
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

      { Process event through bot }
      if Assigned(fBot) then
      begin
        { Create update object in LongPoll format for compatibility }
        aUpdate := TJSONObject.Create;
        try
          aUpdate.Add('type', aTypeStr);
          aUpdate.Add('object', aRequest.EventObject.Clone);

          DoLog(llDebug, Format('Processing webhook event: %s', [aTypeStr]));
          fBot.ProcessUpdate(aUpdate);
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
