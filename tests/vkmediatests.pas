{$mode objfpc}{$H+}{$J-}

unit VKMediaTests;

{ Тесты медиа-загрузки: SendPhoto / SendVoiceMessage / SendDocument и
  полный конвейер Upload* (getMessagesUploadServer -> multipart POST -> save).

  Мок HTTP-клиента отвечает по подстроке URL: сначала специфичные паттерны
  (audio_message), потом общие (docs.getMessagesUploadServer). }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, fpjson, jsonparser,
  fphttpclient,
  VKTypes, VKBotFramework, VKWebhook, VKBotFrameworkMocks
  ;

type
  TMediaBot = class(TMockVKBot);

  { TMediaUploadTests — конвейеры загрузки фото/доков }
  TMediaUploadTests = class(TTestCase)
  private
    fBot: TMediaBot;
    procedure ConfigurePhotoResponses(const aSaveResponse: string =
      '{"response":[{"owner_id":111,"id":222}]}';
      const aUploadResponse: string = '{"server":890,"photo":"ph1","hash":"h1"}');
    procedure ConfigureDocResponses(const aSaveResponse: string =
      '{"response":[{"id":333,"owner_id":444}]}');
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestUploadPhoto_FullChain;
    procedure TestSendPhoto_SendsAttachmentAndCaption;
    procedure TestUploadVoice_FullChain;
    procedure TestSendVoiceMessage_SendsAttachment;
    procedure TestUploadDoc_FullChain;
    procedure TestUploadPhoto_NoUploadServer_Fails;
    procedure TestUploadPhoto_InvalidUploadResponse_Fails;
    procedure TestUploadPhoto_EmptySaveArray_Fails;
    procedure TestSendPhoto_FailureReturnsFalse;
  end;

  { TMediaIntegrationTests — webhook -> обработчик -> медиа-ответ }
  TMediaIntegrationTests = class(TTestCase)
  private
    fBot: TMediaBot;
    fProcessor: TVKWebhookProcessor;
    procedure HandlePhotoCommand(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
    procedure HandleVoiceMessage(const aMsg: TVKMessage);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestWebhookCommand_SendsPhoto;
    procedure TestWebhookMessage_SendsVoice;
  end;

implementation

{ TMediaUploadTests }

procedure TMediaUploadTests.SetUp;
begin
  fBot := TMediaBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":1}');
end;

procedure TMediaUploadTests.TearDown;
begin
  fBot.Free;
end;

procedure TMediaUploadTests.ConfigurePhotoResponses(const aSaveResponse: string;
  const aUploadResponse: string);
begin
  TMockHTTPClient.AddResponse('photos.getMessagesUploadServer',
    '{"response":{"upload_url":"https://up.mock/photo"}}');
  TMockHTTPClient.AddResponse('up.mock/photo', aUploadResponse);
  TMockHTTPClient.AddResponse('photos.saveMessagesPhoto', aSaveResponse);
end;

procedure TMediaUploadTests.ConfigureDocResponses(const aSaveResponse: string);
begin
  { голосовой тип ищем первым: в URL он закодирован как type=audio%5Fmessage,
    поэтому общий паттерн docs.getMessagesUploadServer не должен перехватить его }
  TMockHTTPClient.AddResponse('type=audio',
    '{"response":{"upload_url":"https://up.mock/voice"}}');
  TMockHTTPClient.AddResponse('docs.getMessagesUploadServer',
    '{"response":{"upload_url":"https://up.mock/doc"}}');
  TMockHTTPClient.AddResponse('up.mock/voice', '{"file":"voice9"}');
  TMockHTTPClient.AddResponse('up.mock/doc', '{"file":"doc7"}');
  TMockHTTPClient.AddResponse('docs.save', aSaveResponse);
end;

procedure TMediaUploadTests.TestUploadPhoto_FullChain;
var
  aAttachment: string;
begin
  ConfigurePhotoResponses;
  TMockHTTPClient.ClearCalls;

  aAttachment := fBot.UploadPhoto(500, 'pic.jpg');

  CheckEquals('photo111_222', aAttachment, 'Должен вернуться attachment-стринг');
  CheckTrue(TMockHTTPClient.WasCalled('photos.getMessagesUploadServer'),
    'Должен запрашиваться upload-сервер');
  CheckTrue(TMockHTTPClient.WasCalled('peer_id=500'), 'peer_id должен передаваться');
  CheckTrue(TMockHTTPClient.WasCalled('POST https://up.mock/photo'),
    'Файл должен уходить multipart-запросом на upload_url');
  CheckTrue(TMockHTTPClient.WasCalled('[photo: pic.jpg]'),
    'Поле формы photo и имя файла должны быть в запросе');
  CheckTrue(TMockHTTPClient.WasCalled('photos.saveMessagesPhoto'),
    'Загруженное фото должно сохраняться через save');
  CheckTrue(TMockHTTPClient.WasCalled('server=890'), 'server из ответа уходит в save');
  CheckTrue(TMockHTTPClient.WasCalled('hash=h1'), 'hash из ответа уходит в save');
end;

procedure TMediaUploadTests.TestSendPhoto_SendsAttachmentAndCaption;
var
  aURL: string;
begin
  ConfigurePhotoResponses;
  TMockHTTPClient.ClearCalls;

  CheckTrue(fBot.SendPhoto(700, 'pic.jpg', 'Look'), 'SendPhoto должен вернуть True');

  CheckTrue(TMockHTTPClient.WasCalled('messages.send'), 'Фото должно отправляться сообщением');
  aURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('attachment=' + EncodeURLElement('photo111_222'), aURL) > 0,
    'Attachment должен быть photo<owner>_<id>');
  CheckTrue(Pos('message=Look', aURL) > 0, 'Подпись должна передаваться');
end;

procedure TMediaUploadTests.TestUploadVoice_FullChain;
var
  aAttachment: string;
begin
  ConfigureDocResponses;
  TMockHTTPClient.ClearCalls;

  aAttachment := fBot.UploadDoc(500, 'v.ogg', EmptyStr, EmptyStr, True);

  CheckEquals('audio_message444_333', aAttachment, 'Голос должен дать audio_message<owner>_<id>');
  CheckTrue(TMockHTTPClient.WasCalled('type=' + EncodeURLElement('audio_message')),
    'Тип загрузки audio_message должен запрашиваться');
  CheckTrue(TMockHTTPClient.WasCalled('POST https://up.mock/voice'),
    'Файл должен уходить на голосовой upload_url');
  CheckTrue(TMockHTTPClient.WasCalled('[file: v.ogg]'), 'Поле формы для доков — file');
  CheckTrue(TMockHTTPClient.WasCalled('docs.save'), 'Док должен сохраняться через docs.save');
  CheckTrue(TMockHTTPClient.WasCalled('file=voice9'), 'Ключ file из ответа уходит в save');
end;

procedure TMediaUploadTests.TestSendVoiceMessage_SendsAttachment;
var
  aURL: string;
begin
  ConfigureDocResponses;
  TMockHTTPClient.ClearCalls;

  CheckTrue(fBot.SendVoiceMessage(700, 'v.ogg'));

  aURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('attachment=' + EncodeURLElement('audio_message444_333'), aURL) > 0,
    'Голосовое должно отправляться как audio_message<owner>_<id>');
end;

procedure TMediaUploadTests.TestUploadDoc_FullChain;
var
  aAttachment: string;
begin
  ConfigureDocResponses;
  TMockHTTPClient.ClearCalls;

  aAttachment := fBot.UploadDoc(500, 'report.pdf', 'Report');

  CheckEquals('doc444_333', aAttachment, 'Обычный док должен дать doc<owner>_<id>');
  CheckTrue(TMockHTTPClient.WasCalled('type=doc'), 'Тип загрузки doc должен запрашиваться');
  CheckTrue(TMockHTTPClient.WasCalled('POST https://up.mock/doc'), 'Файл уходит на doc upload_url');
  CheckTrue(TMockHTTPClient.WasCalled('title=Report'), 'Заголовок должен передаваться в save');
end;

procedure TMediaUploadTests.TestUploadPhoto_NoUploadServer_Fails;
begin
  TMockHTTPClient.SetDefaultResponse('{"error":5,"error_msg":"auth failed"}');
  TMockHTTPClient.ClearCalls;

  CheckEquals(EmptyStr, fBot.UploadPhoto(500, 'pic.jpg'),
    'Ошибка получения upload-сервера должна давать пустой результат');
  CheckFalse(TMockHTTPClient.WasPostCalled, 'Без upload_url файла быть не должно');
end;

procedure TMediaUploadTests.TestUploadPhoto_InvalidUploadResponse_Fails;
begin
  ConfigurePhotoResponses('{"response":[]}', 'not json at all');
  TMockHTTPClient.ClearCalls;

  CheckEquals(EmptyStr, fBot.UploadPhoto(500, 'pic.jpg'),
    'Мусор вместо ответа upload-сервера должен давать пустой результат');
  CheckFalse(TMockHTTPClient.WasCalled('photos.saveMessagesPhoto'),
    'save не должен вызываться после битой загрузки');
end;

procedure TMediaUploadTests.TestUploadPhoto_EmptySaveArray_Fails;
begin
  ConfigurePhotoResponses('{"response":[]}');
  TMockHTTPClient.ClearCalls;

  CheckEquals(EmptyStr, fBot.UploadPhoto(500, 'pic.jpg'),
    'Пустой ответ save должен давать пустой результат');
end;

procedure TMediaUploadTests.TestSendPhoto_FailureReturnsFalse;
begin
  ConfigurePhotoResponses('{"response":[]}');
  TMockHTTPClient.ClearCalls;

  CheckFalse(fBot.SendPhoto(700, 'pic.jpg', 'nope'),
    'Ошибка загрузки не должна ронять SendPhoto');
  CheckFalse(TMockHTTPClient.WasCalled('messages.send'),
    'Сообщение не должно отправляться при неудачной загрузке');
end;

{ TMediaIntegrationTests }

procedure TMediaIntegrationTests.SetUp;
begin
  fBot := TMediaBot.Create('test_token', 123456);
  TMockHTTPClient.SetDefaultResponse('{"response":1}');
  fProcessor := TVKWebhookProcessor.Create(fBot, 'code');
end;

procedure TMediaIntegrationTests.TearDown;
begin
  fProcessor.Free;
  fBot.Free;
end;

procedure TMediaIntegrationTests.HandlePhotoCommand(const aMsg: TVKMessage;
  const aArgs: TStringArray);
begin
  fBot.SendPhoto(aMsg.PeerID, 'photo.jpg', 'Here you go');
end;

procedure TMediaIntegrationTests.HandleVoiceMessage(const aMsg: TVKMessage);
begin
  fBot.SendVoiceMessage(aMsg.PeerID, 'reply.ogg');
end;

procedure TMediaIntegrationTests.TestWebhookCommand_SendsPhoto;
var
  aResponse: TVKWebhookResponse;
  aURL: string;
begin
  TMockHTTPClient.AddResponse('photos.getMessagesUploadServer',
    '{"response":{"upload_url":"https://up.mock/photo"}}');
  TMockHTTPClient.AddResponse('up.mock/photo', '{"server":1,"photo":"p","hash":"h"}');
  TMockHTTPClient.AddResponse('photos.saveMessagesPhoto',
    '{"response":[{"owner_id":111,"id":222}]}');

  fBot.CommandHandlers['photo'] := @HandlePhotoCommand;

  aResponse := fProcessor.ProcessWebhook(
    '{"type":"message_new","object":{"message":{"text":"/photo","peer_id":900}},"group_id":123456}');

  CheckTrue(wrtOK = aResponse.ResponseType, 'Webhook должен ответить ok');
  CheckTrue(TMockHTTPClient.WasCalled('photos.saveMessagesPhoto'),
    'Команда должна прогнать полный конвейер загрузки фото');
  aURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('messages.send', aURL) > 0, 'Последним должен уйти messages.send');
  CheckTrue(Pos('attachment=' + EncodeURLElement('photo111_222'), aURL) > 0,
    'В сообщении должно быть фото');
  CheckTrue(Pos('peer_id=900', aURL) > 0, 'Ответ должен идти в peer из webhook');
end;

procedure TMediaIntegrationTests.TestWebhookMessage_SendsVoice;
var
  aResponse: TVKWebhookResponse;
  aURL: string;
begin
  TMockHTTPClient.AddResponse('type=audio',
    '{"response":{"upload_url":"https://up.mock/voice"}}');
  TMockHTTPClient.AddResponse('up.mock/voice', '{"file":"v"}');
  TMockHTTPClient.AddResponse('docs.save', '{"response":[{"id":333,"owner_id":444}]}');

  fBot.OnMessage := @HandleVoiceMessage;

  aResponse := fProcessor.ProcessWebhook(
    '{"type":"message_new","object":{"message":{"text":"say it","peer_id":901}},"group_id":123456}');

  CheckTrue(wrtOK = aResponse.ResponseType);
  aURL := TMockHTTPClient.GetLastURL;
  CheckTrue(Pos('attachment=' + EncodeURLElement('audio_message444_333'), aURL) > 0,
    'Обработчик должен ответить голосовым сообщением');
end;

initialization
  RegisterTest(TMediaUploadTests);
  RegisterTest(TMediaIntegrationTests);

end.
