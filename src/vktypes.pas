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

const
  { API constants }
  VK_API_VERSION = '5.199';
  VK_LONG_POLL_WAIT = 25;
  VK_BASE_API_URL = 'https://api.vk.com/method/';

  { Default webhook responses }
  VK_WEBHOOK_OK = 'ok';
  VK_HTTP_OK = 200;
  VK_HTTP_BAD_REQUEST = 400;
  VK_HTTP_UNAUTHORIZED = 401;
  VK_HTTP_INTERNAL_ERROR = 500;

{ Helper functions }
function VKEventTypeFromString(const aType: string): TVKEventType;
function VKEventTypeToString(aType: TVKEventType): string;
function VKButtonColorToString(aColor: TVKButtonColor): string;

{ Webhook helpers }
function CreateWebhookOKResponse: TVKWebhookResponse;
function CreateWebhookConfirmationResponse(const aConfirmationCode: string): TVKWebhookResponse;
function CreateWebhookErrorResponse(const aError: string; aHTTPStatus: Integer = VK_HTTP_INTERNAL_ERROR): TVKWebhookResponse;

implementation

{ Helper: string → enum }
function VKEventTypeFromString(const aType: string): TVKEventType;
begin
  Result := etUnknown;
  case aType of
    'message_new': Result := etMessageNew;
    'message_reply': Result := etMessageReply;
    'message_edit': Result := etMessageEdit;
    'message_typing_state': Result := etMessageTypingState;
    'photo_new': Result := etPhotoNew;
    'photo_comment_new': Result := etPhotoCommentNew;
    'photo_comment_edit': Result := etPhotoCommentEdit;
    'photo_comment_restore': Result := etPhotoCommentRestore;
    'photo_comment_delete': Result := etPhotoCommentDelete;
    'audio_new': Result := etAudioNew;
    'video_new': Result := etVideoNew;
    'video_comment_new': Result := etVideoCommentNew;
    'video_comment_edit': Result := etVideoCommentEdit;
    'video_comment_restore': Result := etVideoCommentRestore;
    'video_comment_delete': Result := etVideoCommentDelete;
    'wall_post_new': Result := etWallPostNew;
    'wall_repost': Result := etWallRepost;
    'wall_reply_new': Result := etWallReplyNew;
    'wall_reply_edit': Result := etWallReplyEdit;
    'wall_reply_restore': Result := etWallReplyRestore;
    'wall_reply_delete': Result := etWallReplyDelete;
    'board_post_new': Result := etBoardPostNew;
    'board_post_edit': Result := etBoardPostEdit;
    'board_post_restore': Result := etBoardPostRestore;
    'board_post_delete': Result := etBoardPostDelete;
    'market_comment_new': Result := etMarketCommentNew;
    'market_comment_edit': Result := etMarketCommentEdit;
    'market_comment_restore': Result := etMarketCommentRestore;
    'market_comment_delete': Result := etMarketCommentDelete;
    'group_leave': Result := etGroupLeave;
    'group_join': Result := etGroupJoin;
    'user_block': Result := etUserBlock;
    'user_unblock': Result := etUserUnblock;
    'poll_vote_new': Result := etPollVoteNew;
    'group_officers_edit': Result := etGroupOfficersEdit;
    'group_change_settings': Result := etGroupChangeSettings;
    'group_change_photo': Result := etGroupChangePhoto;
    'vkpay_transaction': Result := etVkpayTransaction;
  end;
end;

{ Helper: enum → string }
function VKEventTypeToString(aType: TVKEventType): string;
const
  aNames: array[TVKEventType] of string = (
    'unknown',
    'message_new', 'message_reply', 'message_edit', 'message_typing_state',
    'photo_new', 'photo_comment_new', 'photo_comment_edit', 'photo_comment_restore', 'photo_comment_delete',
    'audio_new',
    'video_new', 'video_comment_new', 'video_comment_edit', 'video_comment_restore', 'video_comment_delete',
    'wall_post_new', 'wall_repost',
    'wall_reply_new', 'wall_reply_edit', 'wall_reply_restore', 'wall_reply_delete',
    'board_post_new', 'board_post_edit', 'board_post_restore', 'board_post_delete',
    'market_comment_new', 'market_comment_edit', 'market_comment_restore', 'market_comment_delete',
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
    'primary',    // Blue
    'secondary',  // White (default)
    'negative',   // Red
    'positive'    // Green
  );
begin
  Result := aColors[aColor];
end;

{ Create standard OK response }
function CreateWebhookOKResponse: TVKWebhookResponse;
begin
  Result.ResponseType := wrtOK;
  Result.Content := VK_WEBHOOK_OK;
  Result.HTTPStatus := VK_HTTP_OK;
end;

{ Create confirmation response }
function CreateWebhookConfirmationResponse(const aConfirmationCode: string): TVKWebhookResponse;
begin
  Result.ResponseType := wrtConfirmation;
  Result.Content := aConfirmationCode;
  Result.HTTPStatus := VK_HTTP_OK;
end;

{ Create error response }
function CreateWebhookErrorResponse(const aError: string; aHTTPStatus: Integer): TVKWebhookResponse;
begin
  Result.ResponseType := wrtError;
  Result.Content := aError;
  Result.HTTPStatus := aHTTPStatus;
end;

end.
