unit VKBotFrameworkMocks;

{$mode objfpc}{$H+}{$J-}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, VKBotFramework, gvector, vkbasehttpclient
  ;

type
  { Mock HTTP Client для тестирования }

  { TMockHTTPClient }

  TMockHTTPClient = class(TBaseHTTPClient)
  private
    type
      TURLResponse = record
        URL: string;
        Response: string;
      end;
      TURLResponseVector = specialize TVector<TURLResponse>;
    var
    class var fResponses: TURLResponseVector;
    class var fSequentialResponses: TURLResponseVector;
    class var fCallLog: TStringList;
    class var fDefaultResponse: string;
    class var fFailNextCalls: Integer;
    class procedure FreeCallStorage;
  public
    function Get(const aURL: string): string; override;
    { Uploads are logged as "POST <url> [<field>: <file>]" so tests can
      match both the URL and the multipart field name via WasCalled }
    function PostFile(const aURL, aFieldName, aFileName: string): string; override;

    class procedure InitiateCallStorage;

    { Mock control methods }
    class procedure AddResponse(const aURLPattern: string; const aResponseStr: string);
    { Response returned ONCE for the next call matching the pattern,
      then removed (for error-then-success sequences) }
    class procedure AddSequentialResponse(const aURLPattern: string; const aResponseStr: string);
    { Make the next N Get calls raise EHTTPClient (network failures) }
    class procedure FailNextNCalls(aCount: Integer);
    class procedure SetDefaultResponse(const aResponse: string);
    class function GetCallCount: Integer;
    class function GetCall(aIndex: Integer): string;
    class procedure ClearCalls;
    class function WasCalled(const aURLPattern: string): Boolean;
    class function GetLastURL: string;
    class function WasPostCalled: Boolean;
  end;

  { Mock Bot: extended testing }
  TMockVKBot = class(TVKBot)
  public
    constructor Create(const aToken: string; aGroupID: Int64);
    property RawJSON;
  end;

implementation

{ TMockHTTPClient }

class procedure TMockHTTPClient.FreeCallStorage;
begin
  fResponses.Clear;
  fSequentialResponses.Clear;
  fCallLog.Clear;
end;

function TMockHTTPClient.Get(const aURL: string): string;
var
  i: Integer;
  aResponse: TURLResponse;
begin
  fCallLog.Add(aURL);

  if fFailNextCalls > 0 then
  begin
    Dec(fFailNextCalls);
    raise EHTTPClient.Create('mock connection refused');
  end;

  if fSequentialResponses.Size > 0 then
    for i := 0 to fSequentialResponses.Size - 1 do
      if Pos(fSequentialResponses[i].URL, aURL) > 0 then
      begin
        Result := fSequentialResponses[i].Response;
        fSequentialResponses.Erase(i);
        Exit;
      end;

  if fResponses.Size=0 then
    Exit(fDefaultResponse);
  for i := 0 to fResponses.Size - 1 do
  begin
    aResponse := fResponses[i];
    if Pos(aResponse.URL, aURL) > 0 then
    begin
      Result := aResponse.Response;
      Exit;
    end;
  end;

  Result := fDefaultResponse;
end;

function TMockHTTPClient.PostFile(const aURL, aFieldName, aFileName: string): string;
var
  i: Integer;
  aResponse: TURLResponse;
begin
  fCallLog.Add(Format('POST %s [%s: %s]', [aURL, aFieldName, aFileName]));

  if fResponses.Size=0 then
    Exit(fDefaultResponse);
  for i := 0 to fResponses.Size - 1 do
  begin
    aResponse := fResponses[i];
    if Pos(aResponse.URL, aURL) > 0 then
    begin
      Result := aResponse.Response;
      Exit;
    end;
  end;

  Result := fDefaultResponse;
end;

class procedure TMockHTTPClient.AddResponse(const aURLPattern: string; const aResponseStr: string);
var
  aResponse: TURLResponse;
begin
  aResponse.URL := aURLPattern;
  aResponse.Response := aResponseStr;
  fResponses.PushBack(aResponse);
end;

class procedure TMockHTTPClient.AddSequentialResponse(const aURLPattern: string; const aResponseStr: string);
var
  aResponse: TURLResponse;
begin
  aResponse.URL := aURLPattern;
  aResponse.Response := aResponseStr;
  fSequentialResponses.PushBack(aResponse);
end;

class procedure TMockHTTPClient.FailNextNCalls(aCount: Integer);
begin
  fFailNextCalls := aCount;
end;

class procedure TMockHTTPClient.SetDefaultResponse(const aResponse: string);
begin
  fDefaultResponse := aResponse;
end;

class function TMockHTTPClient.GetCallCount: Integer;
begin
  Result := fCallLog.Count;
end;

class function TMockHTTPClient.GetCall(aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < fCallLog.Count) then
    Result := fCallLog[aIndex]
  else
    Result := '';
end;

class procedure TMockHTTPClient.ClearCalls;
begin
  fCallLog.Clear;
end;

class function TMockHTTPClient.WasCalled(const aURLPattern: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to fCallLog.Count - 1 do
    if Pos(aURLPattern, fCallLog[i]) > 0 then
      Exit(True)
end;

class function TMockHTTPClient.GetLastURL: string;
begin
  if fCallLog.Count > 0 then
    Result := fCallLog[fCallLog.Count - 1]
  else
    Result := EmptyStr;
end;

class function TMockHTTPClient.WasPostCalled: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to fCallLog.Count - 1 do
    if Pos('POST ', fCallLog[i]) = 1 then
      Exit(True);
end;

class procedure TMockHTTPClient.InitiateCallStorage;
begin
  FreeCallStorage;
  fDefaultResponse := '{"response":{}}';
  fFailNextCalls := 0;
end;

{ TMockVKBot }

constructor TMockVKBot.Create(const aToken: string; aGroupID: Int64);
begin
  inherited Create(aToken, aGroupID);
  TMockHTTPClient.UnregisterClientClass;
  TMockHTTPClient.RegisterClientClass;
  TMockHTTPClient.InitiateCallStorage;
end;

initialization

  TMockHTTPClient.fCallLog:=TStringList.Create;
  TMockHTTPClient.fResponses:=TMockHTTPClient.TURLResponseVector.Create;
  TMockHTTPClient.fSequentialResponses:=TMockHTTPClient.TURLResponseVector.Create;
  TMockHTTPClient.fDefaultResponse:=EmptyStr;
  TMockHTTPClient.fFailNextCalls:=0;

finalization
  TMockHTTPClient.fResponses.Free;
  TMockHTTPClient.fSequentialResponses.Free;
  TMockHTTPClient.fCallLog.Free;

end.
