program vkbot_fpweb_demo;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fphttpapp, httpdefs, fpweb,
  VKTypes, VKBotFramework, VKWebhook
  ;

type

  { TVKModule }

  TVKModule = class(TFPWebModule)
  published
    procedure CallbackRequest({%H-}aSender: TObject; aRequest: TRequest; aResponse: TResponse; var aHandled: Boolean);
  end;

  { TMyVKBot }

  TMyVKBot = class(TVKBot)
  private
    procedure OnEchoCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
  end;

var
  _Bot: TMyVKBot;
  Webhook: TVKWebhookProcessor;

  { TMyVKBot }

procedure TMyVKBot.OnEchoCommand(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  aMsg.Reply('Echo: ' + aMsg.Text);
end;

{ TVKModule }

procedure TVKModule.CallbackRequest(aSender: TObject; aRequest: TRequest;
  aResponse: TResponse; var aHandled: Boolean);
var
  aResultObj: TVKWebhookResponse;
begin
  aResultObj := Webhook.ProcessWebhook(aRequest.Content);

  aResponse.Code := aResultObj.HTTPStatus;
  aResponse.ContentType := 'text/plain; charset=utf-8';
  aResponse.Content := aResultObj.Content;
  aHandled := True;
end;

begin
  _Bot := TMyVKBot.Create('YOUR_VK_TOKEN');
  _Bot.CommandHandlers['/echo']:=@_Bot.OnEchoCommand;

  Webhook := TVKWebhookProcessor.Create(
    _Bot,
    'YOUR_CONFIRMATION_CODE',
    'YOUR_SECRET'
  );

  Application.Initialize;
  Application.Run;
end.
