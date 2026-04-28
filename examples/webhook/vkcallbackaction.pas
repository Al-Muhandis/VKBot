unit VKCallbackAction;

{$mode objfpc}{$H+}

interface

uses
  BrookAction, VKWebhook;

type
  TVKCallbackAction = class(TBrookAction)
  public
    class procedure Post; override;
  end;

implementation

uses
  BrookHTTPConsts;

var
  Webhook: TVKWebhookProcessor;

class procedure TVKCallbackAction.Post;
var
  R: TVKWebhookResponse;
begin
  R := Webhook.ProcessWebhook(HttpRequest.Content);
  HttpResponse.Code := R.StatusCode;
  HttpResponse.Content := R.Body;
end;

end.