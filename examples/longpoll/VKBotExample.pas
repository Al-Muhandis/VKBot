program VKBotExample;

{$mode objfpc}{$H+}

uses
  SysUtils, VKTypes, VKBotFramework, fpjson, eventlog;

type

  { TExampleHandler }

  TExampleHandler = class
  private
    fLogger: TEventLog;
    procedure OnAnyMessage(const {%H-}aMsg: TVKMessage);
    procedure OnEcho(const aMsg: TVKMessage; const aArgs: TStringArray);
    procedure OnHelp(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
    procedure OnLog({%H-}aLevel: TLogLevel; const aMessage: string);
    procedure OnStart(const aMsg: TVKMessage; const {%H-}aArgs: TStringArray);
    procedure OnWallPost(const {%H-}aEvent: TJSONObject);
  public
    constructor Create;
    destructor Destroy; override;
  end;

procedure TExampleHandler.OnStart(const aMsg: TVKMessage; const aArgs: TStringArray);
var
  aKeyboard: TVKKeyboard;
begin
  aKeyboard := TVKKeyboard.Create(True);
  try
    aKeyboard
      .AddButton('Помощь', bcPrimary, '{"command" : "help"}')
      .AddButton('О боте', bcSecondary, '{"command" : "about"}')
      .AddRow
      .AddButton('Выход', bcNegative, '{"command" : "exit"}');
      
    aMsg.Reply('Привет! Я бот на FreePascal 🚀', aKeyboard.Build);
  finally
    aKeyboard.Free;
  end;
end;

procedure TExampleHandler.OnHelp(const aMsg: TVKMessage; const aArgs: TStringArray);
begin
  aMsg.Reply(
    'Available commands:' + LineEnding +
    '/start - Start work' + LineEnding +
    '/help - Help' + LineEnding +
    '/echo <текст> - Repeat text'
  );
end;

procedure TExampleHandler.OnLog(aLevel: TLogLevel; const aMessage: string);
begin
  WriteLn(aMessage);
end;

procedure TExampleHandler.OnEcho(const aMsg: TVKMessage; const aArgs: TStringArray);
var
  aText: string;
  i: Integer;
begin
  if Length(aArgs) = 0 then
  begin
    aMsg.Reply('Use: /echo <текст>');
    Exit;
  end;
  
  aText := EmptyStr;
  for i := 0 to High(aArgs) do
  begin
    if i > 0 then
      aText += ' ';
    aText += aArgs[i];
  end;
  
  aMsg.Reply('🔊 ' + aText);
end;

procedure TExampleHandler.OnAnyMessage(const aMsg: TVKMessage);
begin

end;

procedure TExampleHandler.OnWallPost(const aEvent: TJSONObject);
begin
  WriteLn('New wall post detected!');
end;

constructor TExampleHandler.Create;
begin
  fLogger:=TEventLog.Create(nil);
  fLogger.LogType:=ltFile;
  fLogger.Active:=True;
end;

destructor TExampleHandler.Destroy;
begin
  fLogger.Free;
  inherited Destroy;
end;

var
  _Bot: TVKBot;
  _Handler: TExampleHandler;
begin
  Randomize;
  
  { Создание бота }
  _Handler:=TExampleHandler.Create;
  _Bot := TVKBot.Create(
    'YOUR_TOKEN_HERE',
    123456789); // group ID
  try
    { Регистрация команд }
    _Bot.CommandHandlers['start']:=@_Handler.OnStart;
    _Bot.CommandHandlers['help']:=@_Handler.OnHelp;
    _Bot.CommandHandlers['echo']:=@_Handler.OnEcho;
    _Bot.OnLog:=@_Handler.OnLog;
    
    { Обработчик всех сообщений }
    _Bot.AddMessageHandler(@_Handler.OnAnyMessage);
    
    { Обработчики событий }
    _Bot.EventHandlers[etWallPostNew]:=@_Handler.OnWallPost;
    
    { Запуск }
    WriteLn('VK Bot Framework v1.0');
    WriteLn('Press Ctrl+C to stop');
    _Bot.Start;
  finally
    _Bot.Free;
    _Handler.Free;
  end;
end.
