unit shelltray_engine;
interface

uses
	WinAPI, functions;

const
	NIIF_INFO       = $00000001;
	NIIF_WARNING    = $00000002;
	NIIF_ERROR      = $00000003;

type
	PNotifyIconData = ^TNotifyIconData;
	TDUMMYUNIONNAME    = record
		case Integer of
			0: (uTimeout: UINT);
			1: (uVersion: UINT);
	end;

	TNotifyIconData = record
		cbSize: DWORD;
		hWnd: HWND;
		uID: UINT;
		uFlags: UINT;
		uCallbackMessage: UINT;
		hIcon: HICON;
	 //Version 5.0 is 128 chars, old ver is 64 chars
		szTip: array [0..127] of Char;
		dwState: DWORD; //Version 5.0
		dwStateMask: DWORD; //Version 5.0
		szInfo: array [0..255] of Char; //Version 5.0
		DUMMYUNIONNAME: TDUMMYUNIONNAME;
		szInfoTitle: array [0..63] of Char; //Version 5.0
		dwInfoFlags: DWORD;   //Version 5.0
	end;

	TTrayEventHdlr= procedure (Msg, wParam: Cardinal) of object;
	TNotifyIconError = (nie_addfailed,nie_removefailed,nie_setversionfailed);
	TNotifyIcon = class
	private
		fData     : TNotifyIconData;
		fIcon     : hIcon;
		fWnd      : hWnd;
		fID       : Cardinal;
		fHandler  : TTrayEventHdlr;
		procedure   setIcon(const Value: hIcon);
		property    Data: TNotifyIconData read fData write fData;
		function    SNFunc(msg: DWORD): Boolean;
		procedure   Error(Kind:TNotifyIconError);
		procedure   PrepareData;
	public
		class function process(wnd: HWND; message: Cardinal; wparam: Integer): Integer; virtual;

		constructor Create;
		destructor  Destroy;override;
		procedure   DoAdd;
		procedure   DoRemove;
		procedure   DoModify;
		procedure   DoSetVersion;
		procedure   Tip(Tip: AnsiString);
		procedure   Msg(Msg, Title: AnsiString; msgType: Cardinal = NIIF_INFO);
		property    Icon: hIcon read fIcon write setIcon;
		property    Window: hWnd read fWnd write fWnd;
		property    ID: Cardinal read fID write fID;
		property    Handler: TTrayEventHdlr read fHandler write fHandler;
	end;

function ProcessWAPIMsg: Boolean;

implementation
uses
	vcl_messages;

const
	NIES: array [TNotifyIconError] of String = (
		'Tray icon add failed!',
		'Tray icon remove failed!',
		'Set version failed'
	);

const
	NIF_MESSAGE     = $00000001;
	NIF_ICON        = $00000002;
	NIF_TIP         = $00000004;
	NIF_INFO        = $00000010;

	NIN_BALLOONSHOW = WM_USER + 2;
	NIN_BALLOONHIDE = WM_USER + 3;
	NIN_BALLOONTIMEOUT = WM_USER + 4;
	NIN_BALLOONUSERCLICK = WM_USER + 5;
	NIN_SELECT = WM_USER + 0;
	NINF_KEY = $1;
	NIN_KEYSELECT = NIN_SELECT or NINF_KEY;

	{other constants can be found in vs.net---vc7's dir: PlatformSDK\Include\ShellAPI.h}

  {define the callback message} 
	TRAY_CALLBACK = WM_USER + $7258;

	NOTIFYICON_VERSION = 4;
	NIM_SETVERSION  = $00000004;
	NIM_SETFOCUS    = $00000003;

	NIM_ADD         = $00000000;
	NIM_MODIFY      = $00000001;
	NIM_DELETE      = $00000002;

	shell32 = 'shell32.dll';

function Shell_NotifyIcon(dwMessage: DWORD; lpData: PNotifyIconData): BOOL; stdcall; external shell32 name 'Shell_NotifyIconA';

{ TNotifyIcon }

var
	nInstance: TNotifyIcon;

function sysicon_dp(wnd: HWND; msg: Cardinal; wparam, lparam: Integer): Integer; stdcall;
begin
	case msg of
	TRAY_CALLBACK:
		result := TNotifyIcon.process(wnd, lParam, wParam);
	WM_COMMAND:
		result := TNotifyIcon.process(wnd, msg, wParam);
	else
		result := DefWindowProc(wnd, msg, wparam, lparam);
	end;
end;

function ProcessWAPIMsg: Boolean;
var
	m: TMSG;
begin
	result := PeekMessage(m, 0, 0, 0, PM_REMOVE);
	if result then begin
		TranslateMessage(m);
		DispatchMessage(m);
	end;
end;

constructor TNotifyIcon.Create;
const
	sysicon_wcls= 'NSIH_Window';
var
	ws: TWndClass;
begin
	nInstance := self;
	fID := $dcc;//Cardinal(Self);
	FillChar(ws, sizeof(ws), 0);
	ws.style := CS_OWNDC;
	ws.lpfnWndProc := @sysicon_dp;
	ws.hInstance := HInstance;
	ws.lpszClassName := sysicon_wcls;
	if RegisterClass(ws) = 0 then
		raise Exception.Create('Can''t register class o_O');


	fWnd := CreateWindowEx(0, ws.lpszClassName, '', WS_POPUP, 0, 0, 0, 0, GetDesktopWindow, 0, HInstance, nil);
	if fWnd = 0 then
		raise Exception.Create('AAA!');

	SetWindowLong(fWnd, GWL_WNDPROC, Integer(@sysicon_dp));

	PrepareData;
//	DoSetVersion;
end;

destructor TNotifyIcon.Destroy;
begin
	DoRemove;
end;

procedure TNotifyIcon.DoAdd;
begin
	DoRemove;
	if not SNFunc(NIM_ADD) then Error(nie_addfailed);
//	PrepareData;
end;

procedure TNotifyIcon.DoModify;
begin
	SNFunc(NIM_MODIFY);
end;

procedure TNotifyIcon.DoRemove;
begin
	if not SNFunc(NIM_DELETE) then Error(nie_removefailed);
end;

procedure TNotifyIcon.DoSetVersion;
begin
	fData.DUMMYUNIONNAME.uVersion := NOTIFYICON_VERSION;
	if not SNFunc(NIM_SETVERSION) then Error(nie_setversionfailed);
//	PrepareData;
end;

procedure TNotifyIcon.Error(Kind: TNotifyIconError);
begin
	exit;
//	if GetLastError<>0 then
//	raise Exception.Create(NIES[Kind]+': '+SysErrorMessage(GetLastError))
//	else
	raise Exception.Create(NIES[Kind]);
end;

procedure TNotifyIcon.PrepareData;
begin
	FillChar(fData, SizeOf(Data),0);
	with fData do begin
		cbSize:=SizeOf(Data);
		hWnd:= fWnd;
		uCallbackMessage := TRAY_CALLBACK;
		uFlags := NIF_MESSAGE;
		uID:=ID;
		Shell_NotifyIcon(NIM_MODIFY, @Data);
	end;
end;

procedure TNotifyIcon.setIcon(const Value: hIcon);
begin
	fIcon:=Value;
	with fData do begin
		if Value <> 0 then begin
			uFlags := NIF_ICON;
			hIcon := Value;
		end else
			if uFlags and NIF_ICON<>0 then begin
				uFlags:= NIF_ICON;
				hIcon := 0;
			end;
	end;
	Shell_NotifyIcon(NIM_MODIFY, @Data);
end;

function TNotifyIcon.SNFunc(msg: DWORD): Boolean;
begin
	result:=Shell_NotifyIcon(msg, @Data);
end;

procedure mm(str: AnsiString; p: Pointer; maxl: Integer);
begin
	FillChar(p^, maxl, 0);
	maxl := iMin(maxl, length(str));
	Move(str[1], p^, maxl);
end;

procedure TNotifyIcon.Tip(Tip: AnsiString);
begin
	with Data do begin
		uFlags := NIF_TIP;
		mm(Tip, @szTip[0], 127);
	end;
	Shell_NotifyIcon(NIM_MODIFY, @Data);
end;

procedure TNotifyIcon.Msg(Msg, Title: AnsiString; msgType: Cardinal);
begin
	with Data do begin
		uFlags := NIF_INFO;
		mm(msg, @szInfo[0], 255);
		mm(title, @szInfoTitle[0], 63);
		dwInfoFlags := msgType;
		DUMMYUNIONNAME.uTimeout := 0;
	end;
	Shell_NotifyIcon(NIM_MODIFY, @Data);
end;

class function TNotifyIcon.process(wnd: HWND; message: Cardinal; wparam: Integer): Integer;
begin
	result := 1;
	with nInstance do
		if Assigned(Handler) then
			Handler(Message, wParam);
end;

end.

