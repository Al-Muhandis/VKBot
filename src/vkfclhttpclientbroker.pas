unit VKFCLHTTPClientBroker;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, vkbasehttpclient
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
    class function GetClientClass: TBaseClientClass;
    class procedure RegisterClientClass;
    class procedure UnregisterClientClass;
  end;

implementation

{ TFCLHTTPClient }

constructor TFCLHTTPClient.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fClient := TFPHTTPClient.Create(nil);
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

initialization
  TFCLHTTPClient.UnregisterClientClass;
  TFCLHTTPClient.RegisterClientClass;

end.

