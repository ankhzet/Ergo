unit vcl_application;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_window
	;

type
	TClassRef    = class of TWindow;
	TApplication = class(TComponent)
	private
		fTerminated: Boolean;
	public
		procedure    CreateWnd(var w; ClassRef: TClassRef);
		procedure    Initialize; virtual;
		procedure    Run;
		procedure    Done; virtual;

		function     ProcessMessages: Boolean;

		procedure    OnIddle; virtual;
		property     Terminated: Boolean read fTerminated;
	end;

var
	App  : TApplication;

implementation
uses
	logs;

{ TApplication }

procedure TApplication.Initialize;
begin

end;

procedure TApplication.OnIddle;
begin
	sleep(1);
end;

function TApplication.ProcessMessages: Boolean;
var
	Msg: TMSG;
begin
	result := PeekMessage(Msg, 0, 0, 0, PM_REMOVE);
	if result then begin
		TranslateMessage(Msg);
		DispatchMessage(Msg);
	end;
end;

procedure TApplication.Done;
begin
end;

procedure TApplication.Run;
begin
	try
		Initialize;
		fTerminated := false;
		try
			repeat
				if not ProcessMessages then
					OnIddle;
			until Components <= 0;
		finally
			Done;
		end;
	except

	end;
	fTerminated := true;
end;

procedure TApplication.CreateWnd(var w; ClassRef: TClassRef);
begin
	TWindow(w) := ClassRef.Create(Self);
end;

end.
