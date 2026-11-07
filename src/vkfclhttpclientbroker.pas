unit VKFCLHTTPClientBroker;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets, vkbasehttpclient, VKTypes
  ;

type

  { Standard HTTP client implementation }
  { TFCLHTTPClient }
  TFCLHTTPClient = class(TBaseHTTPClient)
  private
    fClient: TFPHTTPClient;
  protected
    function GetIOTimeout: Integer; override;
    procedure SetIOTimeout(AValue: Integer); override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function Get(const AURL: string): string; override;
    function PostFile(const aURL, aFieldName, aFileName: string): string; override;
  end;

implementation

{ TFCLHTTPClient }

constructor TFCLHTTPClient.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fClient := TFPHTTPClient.Create(nil);
  { Short connect timeout: a fresh TCP+TLS connection to VK normally
    takes well under a second; failing fast lets APICall retry with a
    new connection instead of stalling the whole single-threaded bot }
  fClient.ConnectTimeout := 4000;
  { Bounds the TLS handshake too: a TSPU burst dropping handshake packets
    stalls SSL_connect until SO_RCVTIMEO fires, so 10s keeps an API call
    recoverable instead of blocking the bot for 35s. VK API replies in
    well under a second; the LongPoll client overrides this with
    (VK_LONG_POLL_WAIT + 10) * 1000 in TVKBot.Start. }
  fClient.IOTimeout := VK_API_IO_TIMEOUT_MS;
end;

destructor TFCLHTTPClient.Destroy;
begin
  fClient.Free;
  inherited;
end;

function TFCLHTTPClient.GetIOTimeout: Integer;
begin
  Result := fClient.IOTimeout;
end;

procedure TFCLHTTPClient.SetIOTimeout(AValue: Integer);
begin
  fClient.IOTimeout := AValue;
end;

function TFCLHTTPClient.Get(const AURL: string): string;
begin
  Result := fClient.Get(AURL);
end;

function TFCLHTTPClient.PostFile(const aURL, aFieldName, aFileName: string): string;
var
  aResponse: TStringStream;
begin
  aResponse := TStringStream.Create;
  try
    fClient.FileFormPost(aURL, aFieldName, aFileName, aResponse);
    Result := aResponse.DataString;
  finally
    aResponse.Free;
  end;
end;

initialization
  TFCLHTTPClient.UnregisterClientClass;
  TFCLHTTPClient.RegisterClientClass;

end.

