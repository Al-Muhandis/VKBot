program smoke_test;

{$mode objfpc}{$H+}

{ Smoke test against the REAL VK API (read-only calls only, nothing is sent):

  1. utils.getServerTime without a token (VK allows it) — checks network,
     HTTPS and JSON pipeline end to end.
  2. If the VK_TOKEN environment variable is set, also runs users.get
     (user id 1) and groups.getById (the token's own group).

  Exit code = number of failed checks. }

uses
  SysUtils, Classes, DateUtils, fpjson, VKBotFramework;

var
  Bot: TVKBot;
  ServerTime: Int64;
  Token: string;
  Resp: TJSONData;
  Failures: Integer;

procedure Pass(const aName: string);
begin
  WriteLn('PASS  ', aName);
end;

procedure Fail(const aName: string; const aDetails: string = '');
begin
  Inc(Failures);
  WriteLn('FAIL  ', aName);
  if aDetails <> '' then
    WriteLn('      ', aDetails);
end;

begin
  Failures := 0;
  Bot := TVKBot.Create(GetEnvironmentVariable('VK_TOKEN'));
  try
    { 1. Public method, no token needed }
    ServerTime := Bot.GetServerTime;
    if (ServerTime > 1700000000) and (Abs(ServerTime - DateTimeToUnix(Now)) < 24 * 3600) then
      Pass(Format('utils.getServerTime (%d, within 24h of local clock)', [ServerTime]))
    else
      Fail('utils.getServerTime', Format('got %d, local unix %d', [ServerTime, DateTimeToUnix(Now)]));

    { 2. Token-scoped read-only calls }
    Token := Bot.Token;
    if Token = '' then
      WriteLn('SKIP  token checks (set VK_TOKEN to run them)')
    else
    begin
      Resp := Bot.UsersGet('1');
      if Assigned(Resp) and (Resp is TJSONArray) and (TJSONArray(Resp).Count > 0) then
        Pass('users.get(id=1): ' + TJSONObject(TJSONArray(Resp).Items[0]).Get('first_name', ''))
      else
        Fail('users.get(id=1)', 'no response (check token/network)');
      Resp.Free;

      Resp := Bot.GetGroupInfo;
      if Assigned(Resp) then
      begin
        Pass('groups.getById(own group): ' + TJSONObject(Resp).Get('name', ''));
        Resp.Free;
      end
      else
        Fail('groups.getById(own group)', 'no response (group token required)');
    end;
  finally
    Bot.Free;
  end;

  WriteLn;
  if Failures = 0 then
    WriteLn('SMOKE OK')
  else
    WriteLn('SMOKE FAILED: ', Failures, ' check(s)');
  Halt(Failures);
end.
