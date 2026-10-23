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
  public
    function Get(const aURL: string): string; virtual; abstract;
    { Multipart file upload (POST multipart/form-data).
      aFieldName — form field the file is sent under (VK upload servers
      use "photo" for photos and "file" for docs). }
    function PostFile(const aURL, aFieldName, aFileName: string): string; virtual; abstract;
    class function GetClientClass: TBaseClientClass;
    class procedure RegisterClientClass;
    class procedure UnregisterClientClass;
  end;

implementation

var
  _BaseHTTPClientClass: TBaseClientClass = nil;

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

