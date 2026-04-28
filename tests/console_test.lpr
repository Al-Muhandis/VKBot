program console_test;

{$mode objfpc}{$H+}

uses
  Classes, consoletestrunner, VKBotFrameworkTests
  ;

type

  { TMyTestRunner }

  TMyTestRunner = class(TTestRunner);

var
  Application: TMyTestRunner;

begin
  DefaultRunAllTests:=True;
  Application := TMyTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'FPCUnit Console test runner';
  Application.Run;
  Application.Free;
end.
