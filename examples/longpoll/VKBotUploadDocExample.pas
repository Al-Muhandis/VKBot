program VKBotUploadDocExample;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fphttpclient, fpjson, jsonparser, opensslsockets, VKBotFramework, VKTypes
  ;

type

  { TExampleVKBot }

  TExampleVKBot = class(TVKBot)
  public
    procedure BotLog(aLevel: TLogLevel; const aMessage: string);
  end;

function UploadDocumentToVK(const aUploadURL, aFileName: string): string;
var
  aClient: TFPHTTPClient;
  aJSON: TJSONData;
  aResponse: TStringStream;
begin
  Result := EmptyStr;
  aClient := TFPHTTPClient.Create(nil);
  try
    aResponse := TStringStream.Create(EmptyStr);
    try
      aClient.FileFormPost(aUploadURL, 'file', aFileName, aResponse);
      aJSON := GetJSON(aResponse.DataString);
    finally
      aResponse.Free;
    end;
    try
      if aJSON.JSONType <> jtObject then
        raise Exception.Create('Invalid upload response format');
      Result := TJSONObject(aJSON).Get('file', EmptyStr);
    finally
      aJSON.Free;
    end;
  finally
    aClient.Free;
  end;
end;

function BuildDocAttachment(const aDocsSaveResponse: TJSONData): string;
var
  aResponseObj: TJSONObject;
  aDocObj: TJSONObject;
begin
  Result := EmptyStr;
  if not Assigned(aDocsSaveResponse) then
    Exit;
  if aDocsSaveResponse.JSONType <> jtObject then
    Exit;

  aResponseObj := aDocsSaveResponse as TJSONObject;

  aDocObj := aResponseObj.Get('doc', TJSONObject(nil));
  if not Assigned(aDocObj) then
    Exit;

  Result := Format('doc%d_%d', [
    aDocObj.Get('owner_id', Integer(0)),
    aDocObj.Get('id', Integer(0))
  ]);
end;

var
  Bot: TExampleVKBot;
  UploadServerResponse: TJSONData;
  DocsSaveResponse: TJSONData;
  UploadURL: string;
  UploadedFileToken: string;
  Attachment: string;
  TargetPeerID: Int64;
  FilePath: string;

{ TExampleVKBot }

procedure TExampleVKBot.BotLog(aLevel: TLogLevel; const aMessage: string);
begin
  WriteLn(aMessage);
end;

begin
  Randomize;

  if ParamCount < 2 then
  begin
    WriteLn('Usage: VKBotUploadDocExample <peer_id> <file_path>');
    Halt(1);
  end;

  TargetPeerID := StrToInt64Def(ParamStr(1), 0);
  FilePath := ParamStr(2);
  if (TargetPeerID <= 0) or (not FileExists(FilePath)) then
  begin
    WriteLn('Invalid peer_id or file_path');
    Halt(1);
  end;

  Bot := TExampleVKBot.Create(
    'YOUR_TOKEN',
    123456789);
  try
    Bot.OnLog:=@Bot.BotLog;
    { 1) Получаем upload_url через docs.getMessagesUploadServer }
    UploadServerResponse := Bot.GetMessagesUploadServer('doc', TargetPeerID);
    try
      if not Assigned(UploadServerResponse) then
        raise Exception.Create('Failed to get Upload url');
      UploadURL := TJSONObject(UploadServerResponse).Get('upload_url', EmptyStr);
      if UploadURL.IsEmpty then
        raise Exception.Create('upload_url is empty');
    finally
      { JSON structure stored in Bot internally }
      //UploadServerResponse.Free;
    end;

    { 2) Загружаем файл в upload_url (multipart/form-data) }
    UploadedFileToken := UploadDocumentToVK(UploadURL, FilePath);
    if UploadedFileToken.IsEmpty then
      raise Exception.Create('Upload did not return "file" token');

    { 3) Сохраняем документ через docs.save }
    DocsSaveResponse := Bot.DocsSave(UploadedFileToken, ExtractFileName(FilePath));
    try
      Attachment := BuildDocAttachment(DocsSaveResponse);
      if Attachment.IsEmpty then
        raise Exception.Create('Could not build doc attachment');
    finally
      //DocsSaveResponse.Free;
    end;

    { 4) Отправляем сообщение в личный чат пользователя с attachment }
    if not Bot.SendMessage(TargetPeerID, 'Файл успешно загружен ✅', '', Attachment) then
      raise Exception.Create('SendMessage failed');

    WriteLn('Done. Sent attachment: ' + Attachment);
  finally
    Bot.Free;
  end;
end.
