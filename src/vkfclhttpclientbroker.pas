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
  fClient.ConnectTimeout := 10000;
  { Must exceed VK_LONG_POLL_WAIT: the LongPoll server holds an idle
    connection for the whole wait period before replying }
  fClient.IOTimeout := (VK_LONG_POLL_WAIT + 10) * 1000;
end;

destructor TFCLHTTPClient.Destroy;
begin
  fClient.Free;
  inherited;
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

