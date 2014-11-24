program ecv02dbview;

uses
	FastMM4,
	Forms,
	form_dbview in 'pas\form_dbview.pas' {DBViewer};

{$R *.res}

begin
	Application.Initialize;
	Application.CreateForm(TDBViewer, DBViewer);
	Application.Run;
end.
