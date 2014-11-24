program ecv02;
{$SetPEFlags $11}

{$R *.res}

uses
	FastMM4,
	WinAPI,
	logs,
	vcl_components,
	vcl_application,
	vcl_window,
	sql_constants,
	sql_dbsqladapter,
	sql_database,
	s_config,
	file_sys,
	plate_drawer,
	opts,
	strings,
	reader,
	WinAPI_GDIRenderer;

type
	TMainWnd    = class(TReader)
	private
		function    InitTbl(T: Cardinal): Boolean;
	public
		Config    : TConfigNode;
		constructor Create(AOwner: TComponent); override;
		destructor  Destroy; override;
		procedure   Init; override;

		procedure   Resize; override;
		function    Log(M: AnsiString): Boolean;
	end;
	TApp        = class(TApplication)
	public
		Wnd       : TMainWnd;
		procedure   Initialize; override;
	end;

{ TMainWnd }

constructor TMainWnd.Create(AOwner: TComponent);
var
	R: TRect;
begin
	GetClientRect(GetDesktopWindow, R);
	Width := 800;
	Height:= 600;
	Left  := R.Left + ((R.Right - R.Left) - Width) div 2;
	Top   := R.Top + ((R.Bottom - R.Top) - Height) div 2;
	Config := TConfigNode.Create('config');
	if Config.LoadConfig('ergo.cfg') then begin
		SQL_DBPATH := Config['dbdir'];
		if Config['mangadir'] <> '' then OPT_MANGADIR := ExpandFileName(Config['mangadir']);
		if Config['datadir'] <> '' then OPT_DATADIR := ExpandFileName(Config['datadir']);
		BG := CreateSolidBrush(HTC(Config['bg.color']));//, $d0a0a0));
		WG := CreateSolidBrush(HTC(Config['wg.color']));//, $e0c0c0));
		FG := CreateSolidBrush(HTC(Config['fg.color']));//, $d0a0a0));
		SG := CreateSolidBrush(HTC(Config['sg.color']));//, $ffddcc));
		RD_PLATEHEIGHT := STI(Config['height.plates'], 86);
		RD_PLATEWIDTH  := STI(Config['width.plates'], 260);
		RD_PREVIEWWIDTH:= trunc((RD_PLATEHEIGHT - 3) * 0.656);
		OPT_DRAWFRAME   := Config.Bool['drawframe'];
		OPT_DONTENLARGE := not Config.Bool['enlarge'];
		OPT_PREVIEWS    := Config.Bool['previews'];
	end;
	inherited;
	ShowSize := true;
	Caption:= 'Ergo Manga Reader v2.0';
	Initialize;
	WantRender := true;
end;

destructor TMainWnd.Destroy;
begin
	Config.Free;
	inherited;
end;

procedure TMainWnd.Init;
var
	i: Integer;
begin
	inherited Init;
	_db_load;
	for i := TBL_MANGA to TBL_MAX do
		if SQLFAIL(SQLCommand('status table `%s`', [TBL_NAMES[i]])) then InitTbl(i);
end;

function TMainWnd.InitTbl(T: Cardinal): Boolean;
var
	n: AnsiString;
begin
	n := TBL_NAMES[T];
	if FileExists(_db_tblfile(n)) then exit (false);
	SQLCommand('drop table `%s`;', [n]);
	result :=
	 (SQLCommand('create table `%s`;', [n]) = DB_OK) and
	 (SQLCommand('alter table `%s` %s;', [n, TBL_SCHEMA[t]]) = DB_OK);
end;

procedure TMainWnd.Resize;
var
	s: AnsiString;
begin
	inherited;
	s := Caption;
	ShowSize := false;
	Caption := '';
	ShowSize := true;
	Caption := s;
end;

function TMainWnd.Log(M: AnsiString): Boolean;
begin
	result := false;
	LogMSG := M;
end;

{ TApp }

procedure TApp.Initialize;
begin
	CreateWnd(Wnd, TMainWnd);
	l_SetHandler(Wnd.Log);
	l_Start('data\logs\');
end;

begin
	App := TApp.Create(nil);
	App.Run;
end.

