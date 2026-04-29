unit VKCallbackAction;

{$mode objfpc}{$H+}

interface

uses
  BrookAction, VKWebhook;

type
  TVKCallbackAction = class(TBrookAction)
  public
    procedure Post; override;
  end;

implementation

uses
  BrookHTTPConsts;

var
  Webhook: TVKWebhookProcessor;

procedure TVKCallbackAction.Post;
var
  R: TVKWebhookResponse;
begin
  R := Webhook.ProcessWebhook(HttpRequest.Content);
  HttpResponse.Code := R.HTTPStatus;
  HttpResponse.Content := R.Content;
end;

end.