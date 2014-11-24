program ecv10;
{$SetPEFlags $11}
{$DEFINE WIN32_LEAN_AND_MEAN}

{$R *.res}

{%File 'interface list'}

uses
	FastMM4,
	file_sys,
	WinAPI,
	vcl_menus,
	vcl_messages,
	functions,
	strings,
	opts,
	shelltray_engine,
	EMU_Types,
	c_http,
	c_webserver,
	c_buffers,
	s_config,
	sql_dbcommon,
	sql_constants,
	sql_dbsqladapter,
	sql_database,
	sql_resstrings,
	ctl_homepage,
	ctl_reader,
	ctl_import,
	ctl_index;

type
	TMyWebApp  = class(TWebInterface)
	protected
		ti       : TNotifyIcon;
		menu     : HMENU;
	public
		destructor Destroy; override;
		procedure  Initialize;
		procedure  HandleTray(Msg, wParam: Cardinal);
		function   LoadPlugins: Integer; override;
	end;

{ TMyWebApp }

const
	WMID_OPENMANGA = 100;
	WMID_STOP      = 101;

procedure TMyWebApp.HandleTray(Msg, wParam: Cardinal);
var
	p: TPoint;
	l: AnsiString;
begin
	case Msg of
		WM_COMMAND:
			case wParam of
				WMID_OPENMANGA: begin
					l := 'explorer.exe "' + OPT_MANGADIR + '"';
					WinExec(@l[1], SW_SHOWNORMAL);
				end;
				WMID_STOP: Stop;
			end;
		WM_MOUSEMOVE:;
		WM_LBUTTONDOWN:;
		WM_LBUTTONUP:;
		WM_LBUTTONDBLCLK: Stop;
		WM_RBUTTONDOWN:;
		WM_RBUTTONUP: begin
			GetCursorPos(p);
			SetForegroundWindow(ti.Window);
			TrackPopupMenu(menu, TPM_RIGHTBUTTON, p.X, p.Y, 0, ti.Window, nil);
			PostMessage(ti.Window, WM_NULL, 0, 0);
		end;
		WM_RBUTTONDBLCLK:;
	end;
end;

procedure TMyWebApp.Initialize;
var
	witf: String;
begin
	menu := CreatePopupMenu;
	InsertMenu(menu, 0, 0, WMID_OPENMANGA, 'Open manga &folder');
	InsertMenu(menu, 1, 0, 0, nil);
	InsertMenu(menu, 2, 0, WMID_STOP, '&Exit');

	ti := TNotifyIcon.Create;
	ti.Handler := HandleTray;
	ti.DoAdd;
	ti.Icon := LoadIcon(HInstance, 'zloadicon');

	EMU_Log('Plugins loaded: %d...', [LoadPlugins]);
	LoadMangaList;

	ti.Icon := LoadIcon(HInstance, 'zreadyicon');
	ti.Tip(RS_APP_TITLE + #13#10 + RS_APP_BALOON_TIP);
	witf := WEB_ITF_LOCL;
	if witf <> WEB_ITF_IP then witf := witf + ', ' + WEB_ITF_IP;
	ti.Msg(RS_APP_DB_LOADED + #13#10 + RS_APP_BALOON_TIP + #13#10 + RS_APP_BALOON_WEBITF + witf, RS_APP_TITLE);
end;

destructor TMyWebApp.Destroy;
begin
	ti.Free;
	inherited;
end;

function InitTbl(T: Cardinal): Boolean;
var
	n: AnsiString;
begin
	result := false;
	n := TBL_NAMES[T];
	if FileExists(_db_tblfile(n)) then exit;
	SQLCommand('drop table `%s`;', [n]);
	result :=
		(SQLCommand('create table `%s`;', [n]) = DB_OK) and
		(SQLCommand('alter table `%s` %s;', [n, TBL_SCHEMA[t]]) = DB_OK);
end;

function TMyWebApp.LoadPlugins: Integer;
begin
	RegisterPlugin(TImporter.Create);
	RegisterPlugin(TReader.Create);
	RegisterPlugin(THomepage.Create);
	RegisterPlugin(TIndex.Create);
	result := 4;
end;

var
	i: Integer;
	h: THandle;
	n: AnsiString;
begin
//	asm int 3 end;
	n := LowerCase(join('_', Explode('\', ParamStr(0))));
	h := OpenEvent(EVENT_ALL_ACCESS, false, PChar(n));
	if h <> 0 then begin
		MessageBox(GetDesktopWindow, RS_APP_IS_RUNNING, RS_APP_TITLE, MB_OK or MB_ICONERROR);
		exit;
	end else
		CreateEvent(nil, false, false, PChar(n));

	IsMultiThread := true;
	try
		Config := TConfigNode.Create('config');
		if Config.LoadConfig('ergo.cfg') then begin
			SQL_DBPATH := Config['dbdir'];
			if Config['mangadir'] <> '' then OPT_MANGADIR := ExpandFileName(Config['mangadir']);
			if Config['datadir'] <> '' then OPT_DATADIR := ExpandFileName(Config['datadir']);
			if Config['remoteip'] <> '' then WEB_ITF_IP := Config['remoteip'];
			if Config['port'] <> '' then WEB_ITF_PORT := sti(Config['port']);
		end;

		i := 0;
		while i < ParamCount do begin
			inc(i);
			case ContainsS(ParamStr(i), explode(',', '-ip')) of
				0: begin
					inc(i);
					WEB_ITF_IP := ParamStr(i);
				end;
			end;
		end;

		_db_load;
		for i := TBL_MANGA to TBL_MAX do
			if SQLFAIL(SQLCommand('status table `%s`', [TBL_NAMES[i]])) then InitTbl(i);

		with TMyWebApp.Create do
			try
				startListenThread;
				while not listener.isActive do
					if Terminating then
						break
					else
						sleep(1);

				Initialize;
				repeat
					if not ProcessWAPIMsg then
						sleep(1);
				until Terminating;
			finally
				Free;
			end;
	except
		on E: TObject do
			MessageBox(GetDesktopWindow, @Exception(E).Message[1], RS_APP_TITLE, MB_OK);
	end;
end.
