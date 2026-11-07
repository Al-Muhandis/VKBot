unit VKBaseHTTPClient;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils
  ;

type

  EHTTPClient = class(Exception);

  TBaseClientClass = class of TBaseHTTPClient;

  { TBaseHTTPClient }

  TBaseHTTPClient = class(TComponent)
  private
    FIOTimeout: Integer;
  protected
    function GetIOTimeout: Integer; virtual;
    { Socket read/write timeout in ms. Unlike ConnectTimeout it also bounds
      a stalled TLS handshake: SO_RCVTIMEO applies to the SSL_connect reads,
      so a dropped-handshake burst (TSPU) fails after this many milliseconds
      instead of stalling the bot. Base implementation only stores the value;
      brokers forward it to the underlying HTTP client. }
    procedure SetIOTimeout(AValue: Integer); virtual;
  public
    function Get(const aURL: string): string; virtual; abstract;
    { Multipart file upload (POST multipart/form-data).
      aFieldName — form field the file is sent under (VK upload servers
      use "photo" for photos and "file" for docs). }
    function PostFile(const aURL, aFieldName, aFileName: string): string; virtual; abstract;
    class function GetClientClass: TBaseClientClass;
    class procedure RegisterClientClass;
    class procedure UnregisterClientClass;
    property IOTimeout: Integer read GetIOTimeout write SetIOTimeout;
  end;

implementation

var
  _BaseHTTPClientClass: TBaseClientClass = nil;

function TBaseHTTPClient.GetIOTimeout: Integer;
begin
  Result := FIOTimeout;
end;

procedure TBaseHTTPClient.SetIOTimeout(AValue: Integer);
begin
  FIOTimeout := AValue;
end;

class procedure TBaseHTTPClient.RegisterClientClass;
begin
  if Assigned(_BaseHTTPClientClass) then
    raise EHTTPClient.Create('HTTP client class already registered!');
  _BaseHTTPClientClass := Self;
end;

class procedure TBaseHTTPClient.UnregisterClientClass;
begin
  _BaseHTTPClientClass := nil;
end;

class function TBaseHTTPClient.GetClientClass: TBaseClientClass;
begin
  if not Assigned(_BaseHTTPClientClass) then
    raise EHTTPClient.Create('No HTTP client class registered! Please use RegisterClientClass procedure');
  Result:=_BaseHTTPClientClass;
end;

end.

