program ecvpatcher;

uses
  Forms,
  patcher_form in 'pas\updater\patcher_form.pas' {MainViewer};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainViewer, MainViewer);
  Application.Run;
end.
