unit VKTypes;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fpjson
  ;

type
  { Log levels }
  TLogLevel = (llDebug, llInfo, llWarning, llError);
  TOnLogEvent = procedure(aLevel: TLogLevel; const aMessage: string) of object;

  { Known VK LongPoll event types }
  TVKEventType = (
    etUnknown,
    etMessageNew,
    etMessageReply,
    etMessageEdit,
    etMessageTypingState,
    etMessageEvent,
    etPhotoNew,
    etPhotoCommentNew,
    etPhotoCommentEdit,
    etPhotoCommentRestore,
    etPhotoCommentDelete,
    etAudioNew,
    etVideoNew,
    etVideoCommentNew,
    etVideoCommentEdit,
    etVideoCommentRestore,
    etVideoCommentDelete,
    etWallPostNew,
    etWallRepost,
    etWallReplyNew,
    etWallReplyEdit,
    etWallReplyRestore,
    etWallReplyDelete,
    etBoardPostNew,
    etBoardPostEdit,
    etBoardPostRestore,
    etBoardPostDelete,
    etMarketCommentNew,
    etMarketCommentEdit,
    etMarketCommentRestore,
    etMarketCommentDelete,
    etGroupLeave,
    etGroupJoin,
    etUserBlock,
    etUserUnblock,
    etPollVoteNew,
    etGroupOfficersEdit,
    etGroupChangeSettings,
    etGroupChangePhoto,
    etVkpayTransaction
  );

  { Button colors for VK keyboard }
  TVKButtonColor = (
    bcPrimary,    // Blue
    bcSecondary,  // White
    bcNegative,   // Red
    bcPositive    // Green
  );

  { Button action types for VK keyboard }
  TVKButtonType = (
    btText,     // text
    btLocation, // location
    btVKPat,    // vkpay
    btOpenLink, // open_link
    btOpenApp,  // open_app
    btCallback  // callback
  );

  { Webhook request data structure }
  TVKWebhookRequest = record
    RawBody: string;
    EventType: TVKEventType;
    EventObject: TJSONObject;
    GroupID: Int64;
    Secret: string;
  end;

  { Webhook response types }
  TVKWebhookResponseType = (
    wrtOK,              // Simple "ok" response
    wrtConfirmation,    // Send confirmation string
    wrtError            // Error occurred
  );

  { Webhook response structure }
  TVKWebhookResponse = record
    ResponseType: TVKWebhookResponseType;
    Content: string;
    HTTPStatus: Integer;
  end;

  { Webhook handler callback }
  TWebhookHandler = function(const aRequest: TVKWebhookRequest): TVKWebhookResponse of object;

  { -----------------------------------------------------------------------
    TVKDeeplink — a class for building VK deeplinks.

    How works deeplink in VK:

      1. Вы создаёте ссылку:
           vk.me/<username>?ref=<метка>[&ref_source=<доп.метка>]

      2. Пользователь переходит по ней — открывается диалог с сообществом.

      3. Пользователь САМ пишет любое сообщение (или нажимает кнопку).
         VK не отправляет ничего автоматически.

      4. В JSON-объекте этого входящего сообщения появляются поля:
           "ref":        "<значение из ссылки>"
           "ref_source": "<значение из ссылки>"  (если было передано)

      5. Бот читает их через TVKMessage.Ref / TVKMessage.RefSource и
         реагирует нужным образом — например, активирует реферальный бонус,
         показывает контент для конкретной рекламной кампании и т.д.

    Ограничения:
      - ref и ref_source — произвольные строки (кириллица, спецсимволы
        допустимы — они URL-кодируются в Build).
      - Пустой ref недопустим (ссылка теряет смысл).
      - Класс содержит только статические методы, экземпляр не нужен.
    ----------------------------------------------------------------------- }

  { TVKDeeplink }

  TVKDeeplink = class
  public
    { Build link like https://vk.me/<username>?ref=<ref>[&ref_source=<refSource>].
      username  — short group name (напр. 'myclub') или 'club<group_id>'.
      ref       — company/source tag (mand., any chars).
      refSource — additional tag (not mand.). }
    class function Build(const aUsername, aRef: string; const aRefSource: string = ''): string;

    { Build link through number GroupID:
      https://vk.me/club<GroupID>?ref=<ref>[&ref_source=<refSource>] }
    class function BuildByGroupID(aGroupID: Int64; const aRef: string; const aRefSource: string = ''): string;
  end;

const
  { API constants }
  VK_API_VERSION    = '5.199';
  VK_LONG_POLL_WAIT = 25;
  VK_BASE_API_URL   = 'https://api.vk.com/method/';
  VK_ME_BASE_URL    = 'https://vk.me/';

  { Default webhook responses }
  VK_WEBHOOK_OK          = 'ok';
  VK_HTTP_OK             = 200;
  VK_HTTP_BAD_REQUEST    = 400;
  VK_HTTP_UNAUTHORIZED   = 401;
  VK_HTTP_INTERNAL_ERROR = 500;

{ Helper functions }
function VKEventTypeFromString(const aType: string): TVKEventType;
function VKEventTypeToString(aType: TVKEventType): string;
function VKButtonColorToString(aColor: TVKButtonColor): string;      
function VKButtonTypeToString(aType: TVKButtonType): string;


{ Webhook helpers }
function CreateWebhookOKResponse: TVKWebhookResponse;
function CreateWebhookConfirmationResponse(const aConfirmationCode: string): TVKWebhookResponse;
function CreateWebhookErrorResponse(const aError: string;
  aHTTPStatus: Integer = VK_HTTP_INTERNAL_ERROR): TVKWebhookResponse;

function VKUserLink(aUser: Int64): String; inline;

implementation

uses
  fphttpclient
  ;

function VKUserLink(aUser: Int64): String;
begin
  Result:=Format('https://vk.com/id%d', [aUser]);
end;

{ Helper: string → enum }
function VKEventTypeFromString(const aType: string): TVKEventType;
begin
  Result := etUnknown;
  case aType of
    'message_new':           Result := etMessageNew;
    'message_reply':         Result := etMessageReply;
    'message_edit':          Result := etMessageEdit;
    'message_typing_state':  Result := etMessageTypingState;
    'message_event':         Result := etMessageEvent;
    'photo_new':             Result := etPhotoNew;
    'photo_comment_new':     Result := etPhotoCommentNew;
    'photo_comment_edit':    Result := etPhotoCommentEdit;
    'photo_comment_restore': Result := etPhotoCommentRestore;
    'photo_comment_delete':  Result := etPhotoCommentDelete;
    'audio_new':             Result := etAudioNew;
    'video_new':             Result := etVideoNew;
    'video_comment_new':     Result := etVideoCommentNew;
    'video_comment_edit':    Result := etVideoCommentEdit;
    'video_comment_restore': Result := etVideoCommentRestore;
    'video_comment_delete':  Result := etVideoCommentDelete;
    'wall_post_new':         Result := etWallPostNew;
    'wall_repost':           Result := etWallRepost;
    'wall_reply_new':        Result := etWallReplyNew;
    'wall_reply_edit':       Result := etWallReplyEdit;
    'wall_reply_restore':    Result := etWallReplyRestore;
    'wall_reply_delete':     Result := etWallReplyDelete;
    'board_post_new':        Result := etBoardPostNew;
    'board_post_edit':       Result := etBoardPostEdit;
    'board_post_restore':    Result := etBoardPostRestore;
    'board_post_delete':     Result := etBoardPostDelete;
    'market_comment_new':    Result := etMarketCommentNew;
    'market_comment_edit':   Result := etMarketCommentEdit;
    'market_comment_restore':Result := etMarketCommentRestore;
    'market_comment_delete': Result := etMarketCommentDelete;
    'group_leave':           Result := etGroupLeave;
    'group_join':            Result := etGroupJoin;
    'user_block':            Result := etUserBlock;
    'user_unblock':          Result := etUserUnblock;
    'poll_vote_new':         Result := etPollVoteNew;
    'group_officers_edit':   Result := etGroupOfficersEdit;
    'group_change_settings': Result := etGroupChangeSettings;
    'group_change_photo':    Result := etGroupChangePhoto;
    'vkpay_transaction':     Result := etVkpayTransaction;
  end;
end;

{ Helper: enum → string }
function VKEventTypeToString(aType: TVKEventType): string;
const
  aNames: array[TVKEventType] of string = (
    'unknown',
    'message_new', 'message_reply', 'message_edit', 'message_typing_state', 'message_event',
    'photo_new', 'photo_comment_new', 'photo_comment_edit',
    'photo_comment_restore', 'photo_comment_delete',
    'audio_new',
    'video_new', 'video_comment_new', 'video_comment_edit',
    'video_comment_restore', 'video_comment_delete',
    'wall_post_new', 'wall_repost',
    'wall_reply_new', 'wall_reply_edit', 'wall_reply_restore', 'wall_reply_delete',
    'board_post_new', 'board_post_edit', 'board_post_restore', 'board_post_delete',
    'market_comment_new', 'market_comment_edit',
    'market_comment_restore', 'market_comment_delete',
    'group_leave', 'group_join',
    'user_block', 'user_unblock',
    'poll_vote_new',
    'group_officers_edit',
    'group_change_settings', 'group_change_photo',
    'vkpay_transaction'
  );
begin
  Result := aNames[aType];
end;

{ Helper: button color → VK API string }
function VKButtonColorToString(aColor: TVKButtonColor): string;
const
  aColors: array[TVKButtonColor] of string = (
    'primary',   // Blue
    'secondary', // White (default)
    'negative',  // Red
    'positive'   // Green
  );
begin
  Result := aColors[aColor];
end;

{ Helper: button type → VK API string }
function VKButtonTypeToString(aType: TVKButtonType): string;
const
  aTypes: array[TVKButtonType] of string = ('text', 'location', 'vkpay', 'open_link', 'open_app', 'callback');
begin
  Result := aTypes[aType];
end;


{ Webhook helpers }

function CreateWebhookOKResponse: TVKWebhookResponse;
begin
  Result.ResponseType := wrtOK;
  Result.Content      := VK_WEBHOOK_OK;
  Result.HTTPStatus   := VK_HTTP_OK;
end;

function CreateWebhookConfirmationResponse(const aConfirmationCode: string): TVKWebhookResponse;
begin
  Result.ResponseType := wrtConfirmation;
  Result.Content      := aConfirmationCode;
  Result.HTTPStatus   := VK_HTTP_OK;
end;

function CreateWebhookErrorResponse(const aError: string; aHTTPStatus: Integer): TVKWebhookResponse;
begin
  Result.ResponseType := wrtError;
  Result.Content      := aError;
  Result.HTTPStatus   := aHTTPStatus;
end;

{ TVKDeeplink }

class function TVKDeeplink.Build(const aUsername, aRef: string;
  const aRefSource: string): string;
begin
  if aUsername.IsEmpty then
    raise EArgumentException.Create(
      'TVKDeeplink.Build: username не может быть пустым');
  if aRef.IsEmpty then
    raise EArgumentException.Create(
      'TVKDeeplink.Build: ref не может быть пустым');

  Result := VK_ME_BASE_URL + aUsername + '?ref=' + EncodeURLElement(aRef);
  if aRefSource <> '' then
    Result += '&ref_source=' + EncodeURLElement(aRefSource);
end;

class function TVKDeeplink.BuildByGroupID(aGroupID: Int64; const aRef: string;
  const aRefSource: string): string;
begin
  if aGroupID <= 0 then
    raise EArgumentException.Create('TVKDeeplink.BuildByGroupID: GroupID должен быть > 0');
  Result := Build('club' + IntToStr(aGroupID), aRef, aRefSource);
end;

end.
