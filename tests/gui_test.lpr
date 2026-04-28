program gui_test;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, VKBotFrameworkTests, VKWebhookTests
  ;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

