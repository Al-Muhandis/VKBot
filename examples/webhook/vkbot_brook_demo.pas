program vkbot_brook_demo;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,            
  fpjson,
  BrookApplication, BrookHTTPConsts, BrookAction, BrookUtils,
  VKTypes, VKBotFramework, VKWebhook
  ;

type
  { TVKCallbackAction }
  TVKCallbackAction = class(TBrookAction)
  public
    procedure Post; override;
  end;

  { TMyVKBot }

  TMyVKBot = class(TVKBot)
  protected
    procedure OnStartCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
  end;

var
  _Bot: TMyVKBot;
  _Webhook: TVKWebhookProcessor;

{ TMyVKBot }

procedure TMyVKBot.OnStartCommand(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  aMsg.Reply('Привет! Бот работает через BrookFramework.');
end;

  { TVKCallbackAction }

procedure TVKCallbackAction.Post;
var
  aRequestBody: string;
  aResponseObj: TVKWebhookResponse;
begin
  aRequestBody := HttpRequest.Content;
  aResponseObj := _Webhook.ProcessWebhook(aRequestBody);

  HttpResponse.ContentType := 'text/plain; charset=utf-8';
  HttpResponse.Code := aResponseObj.HTTPStatus;
  HttpResponse.Content := aResponseObj.Content;
end;

begin
  _Bot := TMyVKBot.Create('YOUR_VK_TOKEN');
  _Bot.CommandHandlers['/start']:=@_Bot.OnStartCommand;

  _Webhook := TVKWebhookProcessor.Create(
    _Bot,
    'YOUR_CONFIRMATION_CODE',
    'YOUR_SECRET'
  );

  TVKCallbackAction.Register('/vk/callback', rmPost);
  BrookApp.Run;

end.
