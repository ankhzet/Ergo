unit logs;
interface

type
	TLogHandler = function (Msg: AnsiString): Boolean of object;

procedure l_SetHandler(Handler: TLogHandler);
procedure ll_Write(S: AnsiString; Cons: Boolean = true); overload;
procedure ll_Write(F: AnsiString; Params: array of const; Cons: Boolean = true); overload;
procedure l_Start(logfile: AnsiString);
procedure l_Stop;

function GetTimeStamp(): Cardinal;
function MSecToStr(T: Cardinal; Str: AnsiString): AnsiString;
function MSecToStr2: AnsiString;
function MSecToStr3: AnsiString;

implementation
uses
	WinAPI, functions, strings, file_sys;

function MSecToStr(T: Cardinal; Str: AnsiString): AnsiString;
var
	h, m, s: Integer;
begin
	s := t mod 60;
	t := t div 60;
	m := t mod 60;
	t := t div 60;
	h := t mod 24;
//	t := t div 24;
	result := Format(Str, [h, m, s]);
end;

function MSecToStr2: AnsiString;
var
	ST: TSystemTime;
begin
	GetLocalTime(ST);
	with ST do
	result := Format('%d0.2-%d0.2-%d0.4 %d0.2.%d0.2.%d0.2', [wDay, wMonth, wYear, wHour, wMinute, wSecond, wMilliseconds]);
end;

function MSecToStr3: AnsiString;
var
	ST: TSystemTime;
begin
	GetLocalTime(ST);
	with ST do
	result := Format('%d0.2.%d0.2.%d0.2', [wHour, wMinute, wSecond, wMilliseconds]);
end;

function GetTimeStamp(): Cardinal;
var
	ST: TSystemTime;
begin
	GetLocalTime(ST);
	with ST do
	result := wMilliseconds + wSecond * 1000 + wMinute * 1000 * 60 +
		wHour * 1000 * 60 * 60;
end;

var
	lf : Text;
	log: boolean = false;
	hdl: TLogHandler = nil;

procedure l_SetHandler(Handler: TLogHandler);
begin
	hdl := Handler;
end;

procedure ll_Write(F: AnsiString; Params: array of const; Cons: Boolean);
begin
	if not log then exit;
	ll_Write(Format(F, Params), cons);
end;

procedure ll_Write(S: AnsiString; Cons: Boolean);
begin
	if not log then exit;
	Writeln(lf, S);
	Flush(lf);
	if cons then
		if (not Assigned(hdl)) or hdl(S) then begin
//			AnsiToOem(@s[1], @s[1]);
			WriteLn('[' + MSecToStr3 + ']: ' + s);
		end;
end;

procedure l_Start(logfile: AnsiString);
begin
	if log then exit;
	logfile := logfile + '\logfile [' + MSecToStr2() + ']';
	while FileExists(logfile + '.log') do
		logfile := logfile + '0';
	logfile := logfile + '.log';
	Assign(lf, logfile);
	try
//		if FileExists(logfile) then
//			Append(lf)
//		else
			Rewrite(lf);
	except
		exit;
	end;
	log := true;
	ll_Write('Log started...');
end;

procedure l_Stop;
begin
	if not log then exit;
	ll_Write('Log stopped...', false);
	Flush(lf);
	Close(lf);
	log := false;
end;

initialization
finalization
	l_Stop;
end.
 