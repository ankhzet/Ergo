unit core_updater;
interface

type
	TVersion = record
		VLow, VHi: Byte;
	end;
	TPatcher = class
	private
		fHalted: Boolean;
	protected
		function CompareVersions(v1, v2: TVersion): Integer;
		function AppPresent: Boolean;
		function AppRunning: Boolean;
		function InstalledVersion(out Version: TVersion): Boolean;
		function Install: Boolean;
		property Halted: Boolean read fHalted;
	public
		function Execute: Cardinal;
		function Version: TVersion;
	end;

const
	AppVersion: TVersion = (VLow: 1; VHi: 1);

	PR_INSTALLED    = $00000000;
	PR_UPTODATE     = $00000001;
	PR_HALTED       = $00000002;
	PR_INSTFAILED   = $00000004;
	PR_IVERSIONFAIL = $00000008;
	PV_BASICREQUIRE = $00000010;

implementation
uses
	functions;

const
	VersionZero: TVersion = (VLow: 0; VHi: 0);

{ TPatcher }

function TPatcher.AppPresent: Boolean;
begin

end;

function TPatcher.AppRunning: Boolean;
begin

end;

function TPatcher.Install: Boolean;
begin

end;

function TPatcher.InstalledVersion(out Version: TVersion): Boolean;
begin

end;

function TPatcher.CompareVersions(v1, v2: TVersion): Integer;
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
	vi: TVersion;
label
	caninstall;
begin
	if AppPresent then
		if InstalledVersion(vi) then
			if CompareVersions(Version, vi) > 0 then begin
				while AppRunning do
					if Halted then begin
						result := PR_HALTED;
						exit;
					end;

				goto caninstall;
			end else
				result := PR_UPTODATE
		else
			result := PR_IVERSIONFAIL
	else
		if CompareVersions(Version, VersionZero) > 0 then
			result := PV_BASICREQUIRE
		else
			goto caninstall;

	exit;
caninstall:
	if Install then
		result := PR_INSTALLED
	else
		result := PR_INSTFAILED;
end;

function TPatcher.Version: TVersion;
begin
	result := AppVersion;
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