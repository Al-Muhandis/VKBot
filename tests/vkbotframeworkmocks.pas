{$mode objfpc}{$H+}{$J-}

unit VKBotFrameworkMocks;

interface

uses
  Classes, SysUtils, fpjson, jsonparser, VKBotFramework, gvector
  ;

type
  { Mock HTTP Client для тестирования }
  TMockHTTPClient = class(TInterfacedObject, IHTTPClient)
  private
    type
      TURLResponse = record
        URL: string;
        Response: string;
      end;
      TURLResponseVector = specialize TVector<TURLResponse>;
    var
    fResponses: TURLResponseVector;
    fCallLog: TStringList;
    fDefaultResponse: string;
  public
    constructor Create;
    destructor Destroy; override;

    { IHTTPClient }
    function Get(const aURL: string): string;

    { Mock control methods }
    procedure AddResponse(const aURLPattern: string; const aResponseStr: string);
    procedure SetDefaultResponse(const aResponse: string);
    function GetCallCount: Integer;
    function GetCall(aIndex: Integer): string;
    procedure ClearCalls;
    function WasCalled(const aURLPattern: string): Boolean;
    function GetLastURL: string;
  end;

  { Mock Bot: extended testing }
  TMockVKBot = class(TVKBot)
  private
    fMockClient: TMockHTTPClient;
  protected
    function CreateHTTPClient: IHTTPClient; override;
  public
    constructor Create(const aToken: string; aGroupID: Int64);
    property MockClient: TMockHTTPClient read fMockClient;
    property RawJSON;
  end;

implementation

{ TMockHTTPClient }

constructor TMockHTTPClient.Create;
begin
  inherited Create;
  fResponses := TURLResponseVector.Create;
  fCallLog := TStringList.Create;
  fDefaultResponse := '{"response":{}}';
end;

destructor TMockHTTPClient.Destroy;
begin
  fResponses.Free;
  fCallLog.Free;
  inherited;
end;

function TMockHTTPClient.Get(const aURL: string): string;
var
  i: Integer;
  aResponse: TURLResponse;
begin
  fCallLog.Add(aURL);

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

procedure TMockHTTPClient.AddResponse(const aURLPattern: string; const aResponseStr: string);
var
  aResponse: TURLResponse;
begin
  aResponse.URL := aURLPattern;
  aResponse.Response := aResponseStr;
  fResponses.PushBack(aResponse);
end;

procedure TMockHTTPClient.SetDefaultResponse(const aResponse: string);
begin
  fDefaultResponse := aResponse;
end;

function TMockHTTPClient.GetCallCount: Integer;
begin
  Result := fCallLog.Count;
end;

function TMockHTTPClient.GetCall(aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < fCallLog.Count) then
    Result := fCallLog[aIndex]
  else
    Result := '';
end;

procedure TMockHTTPClient.ClearCalls;
begin
  fCallLog.Clear;
end;

function TMockHTTPClient.WasCalled(const aURLPattern: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to fCallLog.Count - 1 do
    if Pos(aURLPattern, fCallLog[i]) > 0 then
      Exit(True)
end;

function TMockHTTPClient.GetLastURL: string;
begin
  if fCallLog.Count > 0 then
    Result := fCallLog[fCallLog.Count - 1]
  else
    Result := EmptyStr;
end;

{ TMockVKBot }

constructor TMockVKBot.Create(const aToken: string; aGroupID: Int64);
begin
  inherited Create(aToken, aGroupID);
  fMockClient := TMockHTTPClient.Create;
  SetHTTPClient(fMockClient);
end;

function TMockVKBot.CreateHTTPClient: IHTTPClient;
begin
  Result := nil;
end;

end.
