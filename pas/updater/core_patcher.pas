unit core_patcher;
interface

type
	TMsgType = (mt_info, mt_confirm, mt_error);
	TAppVersion = record
		VLow, VHi: Byte;
	end;
	TPatcher = class
	private
		fHalted: Boolean;
	protected
		function CompareVersions(v1, v2: TAppVersion): Integer;
		function AppPresent: Boolean;
		function AppRunning: Boolean;
		function InstalledVersion(out Version: TAppVersion): Boolean;
		function Install: Boolean;
		property Halted: Boolean read fHalted;
	public
		function Execute: Cardinal;
		function Version: TAppVersion;
	end;

const
	VersionZero    : TAppVersion = (VLow: 0; VHi: 0);

	SIZE_VCHUNK    = SizeOf(TAppVersion);

	BACKUP_DIR      = 'backup\';
	BaseAppExeName  = 'ergo.exe';

	PR_INSTALLED    = $00000000;
	PR_UPTODATE     = $00000001;
	PR_HALTED       = $00000002;
	PR_INSTFAILED   = $00000004;
	PR_IVERSIONFAIL = $00000008;
	PR_BASICREQUIRE = $00000010;

resourcestring
	APP_TITLE          = 'Ergo manga reader autopatcher';

	MSG_INSTALLED      = 'Patch succesfuly installed';
	MSG_UPTODATE       = 'Application is already up-to-date';
	MSG_HALTED         = 'Installation halted by user';
	MSG_INSTFAILED     = 'Installation failed';
	MSG_IVERSIONFAIL   = 'Can''t aquire installed application version';
	MSG_BASICREQUIRE   = 'This patch requires some previous version to be already installed';

	ERR_UPDATE_FAILED  = 'Update file [%s] failed!';
	LOG_WRITED         = 'Writed [%s]...';
	ERR_FILE_NOT_FOUND = 'File [%s] not found in package!';
	ERR_DESC_NOT_FOUND = 'Description file not found in patch package!';
	ERR_DESC_NOT_READ  = 'Description file can''t be read!';
	ERR_DESC_NOT_PARSE = 'Description file can''t be parsed!';
	ERR_APP_RUNNING    = 'Application is running. Close the application and press "YES".'#13#10'Continue patch process?';

const
	PATCH_DESCRIPTOR = 'descript.ion';

function Message(AMsg: AnsiString; AType: TMsgType): Integer;
function BaseAppName: AnsiString;

implementation
uses
		WinAPI
	, EMU_Types
	, functions
	, strings
	, file_sys
	, streams
	, packages
	, s_config
	, s_engine
	;

function Message(AMsg: AnsiString; AType: TMsgType): Integer;
begin
	case AType of
		mt_confirm: result := MessageBox(GetDesktopWindow, PChar(AMsg), PChar(APP_TITLE), MB_YESNO or MB_ICONQUESTION);
		mt_error  : result := MessageBox(GetDesktopWindow, PChar(AMsg), PChar(APP_TITLE), MB_OK or MB_ICONERROR);
		else        result := MessageBox(GetDesktopWindow, PChar(AMsg), PChar(APP_TITLE), MB_OK or MB_ICONINFORMATION);
	end;
end;

function BaseAppName: AnsiString;
begin
	result := Format('%s\\%s', [CoreDir, BaseAppExeName]);
end;

{ TPatcher }

function TPatcher.Version: TAppVersion;
var
	s: TStream;
	p: Cardinal;
begin
	try
		s := TFileStream.Create('ecvPatch[to v1.0].exe'{ParamStr(0){}, fmOpen);
		try
			s.Position := s.Size - SizeOf(Cardinal);
			s.Read(@p, SizeOf(Cardinal));
			s.Position := s.Size - SizeOf(Cardinal) - p - SIZE_VCHUNK;
			s.Read(@result, SIZE_VCHUNK);// = SIZE_VCHUNK;
		finally
			s.Free;
		end;
	except
		result.VLow := 0;
		result.VHi := 0;
	end;
end;

function TPatcher.AppPresent: Boolean;
begin
	result := FileExists(BaseAppName);
end;

function TPatcher.AppRunning: Boolean;
var
	Handle: THandle;
	event : AnsiString;
begin
	event := LowerCase(join('_', Explode('\', BaseAppName)));
	Handle := OpenEvent(EVENT_ALL_ACCESS, false, PChar(event));
	result := Handle <> 0;
	if result then
		CloseHandle(Handle)
	else
		CreateEvent(nil, false, false, PChar(event));
end;

function TPatcher.Install: Boolean;
var
	P: TPackage;
	f: TFile;
	s: AnsiString;
	c: TConfigNode;
	n: TConfigNode;
	procedure RemoveFiles(n: TConfigNode);
	var
		c: TString;
	begin
		c := TString(n.Childs);
		while c <> nil do begin
			Message('remove :: ' + c.Value, mt_info);
			c := TString(c.Prev);
		end;
	end;
	procedure AddFiles(n: TConfigNode);
	var
		c: TString;
		r: TStrings;
		f: TFolder;
		e: TFile absolute f;
		t1, t2: AnsiString;
		i: Integer;
		function WriteContent: Boolean;
		var
			s: TStream;
		begin
			result := false;
			try
				AssumeDirExists(ExtractFileDir(t1));
				s := TFileStream.Create(t1, fmCreateAlways);
				try
					result := e.LoadData(p) and (s.Write(e.Data, e.Size) = s.Size);
				finally
					s.Free;
				end;
			except

			end;
		end;
	begin
		c := TString(n.Childs);
		while c <> nil do begin
			f := TFolder(p[p.IndexOf(0)]);

			r := explode('\', c.Value);
			repeat
				t1:= array_shift(r);
				i := f.IndexOf(t1);
				if i >= 0 then
					f := TFolder(p[f[i]]);
			until Length(r) <= 0;

			if e <> nil then begin
				t1 := CoreDir + c.Value;
				if FileExists(t1) then begin
					t2 := CoreDir + BACKUP_DIR;
					AssumeDirExists(t2 + ExtractFileDir(c.Value));
					MoveFile(PChar(t1), PChar(t2 + c.Value));
				end;

				if not WriteContent then
					raise Exception.Create(ERR_UPDATE_FAILED, [c.Value]);

				EMU_Log(LOG_WRITED, [c.Value]);
			end else
				raise Exception.Create(ERR_FILE_NOT_FOUND, [c.Value]);

			c := TString(c.Next);
		end;
	end;
begin
	result := false;
	try
//		asm int 3 end;

		P := TPackage.Create('ecvPatch[to v1.0].exe'{ParamStr(0){}, BaseAppExeName);
		try
			f := TFile(p[p.IndexOf(PATCH_DESCRIPTOR)]);
			if f = nil then
				raise Exception.Create(ERR_DESC_NOT_FOUND);

			AssumeDirExists(CoreDir + BACKUP_DIR);

			if not f.LoadData(P) then
				raise Exception.Create(ERR_DESC_NOT_READ);

			SetString(s, PChar(f.Data), f.Size);

			c := TConfigNode.Create('patch');
			try
				if not c.ReadFromString(s) then
					raise Exception.Create(ERR_DESC_NOT_PARSE);

				n := TConfigNode(c.Get('remove'));
				if (n <> nil) and (n.Childs <> nil) then
					RemoveFiles(n);

				n := TConfigNode(c.Get('add'));
				if (n <> nil) and (n.Childs <> nil) then
					AddFiles(n);
			finally
				c.Free;
			end;
			result := true;
		finally
			P.Free;
		end;
	except
	end;
end;

function TPatcher.InstalledVersion(out Version: TAppVersion): Boolean;
var
	s: TStream;
begin
	try
		s := TFileStream.Create(BaseAppName, fmOpen);
		try
			s.Position := s.Size - SIZE_VCHUNK;
			result := s.Read(@Version, SIZE_VCHUNK) = SIZE_VCHUNK;
		finally
			s.Free;
		end;
	except
		result := false;
	end;
end;

function TPatcher.CompareVersions(v1, v2: TAppVersion): Integer;
	function sign(v: Integer): Smallint;
	begin
		if v = 0 then
			result := 0
		else
			result := v div abs(v);
	end;
begin
	result := sign(PWord(@v1)^ - PWord(@v2)^);
end;

function TPatcher.Execute: Cardinal;
var
	vi, vp: TAppVersion;
label
	caninstall;
begin
	vp := Version;
	if AppPresent then
		if InstalledVersion(vi) then begin
//			Message(Format('Installed: %d\.%d, patch: %d\.%d', [vi.VHi, vi.VLow, vp.VHi, vp.VLow]), mt_info);
			if CompareVersions(vp, vi) > 0 then begin
				while AppRunning do
					if Message(ERR_APP_RUNNING, mt_confirm) = IDNO then begin
						result := PR_HALTED;
						exit;
					end;

				goto caninstall;
			end else
				result := PR_UPTODATE
		end else
			result := PR_IVERSIONFAIL
	else
//		if CompareVersions(vp, VersionZero) > 0 then
//			result := PR_BASICREQUIRE
//		else
			goto caninstall;

	exit;
caninstall:
	if Install then
		result := PR_INSTALLED
	else
		result := PR_INSTFAILED;
end;

end.

(*
Update process:
	1. Check installed application version
	2. Check remote application version
	3. Compare versions
		if remote > local:
			3.1 Download patcher
			3.2 Launch pather
			3.3 Terminate updater (application itself, cause updater is built-in)
		else
			3.4 Nop

Patch process:
	1. Check application existance in installation directory
		if exist:
			1.1 Check application version
			1.2 Compare versions
				if patcher > local
					1.2.1 Check if application is running
						if running
							1.2.1.1 Wait for application closed or cancel path process
					1.2.2 Install patch
				else
					1.2.3 Report version is already up-to-date
		else
			1.3 Check patch version
				if version > 0
					1.3.1 Report "basic installation required"
				else
					1.3.2 Install patch