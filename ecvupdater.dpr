program ecvupdater;
{$R *.res}
{ $APPTYPE CONSOLE}

uses
		core_patcher
	, functions
	, EMU_Types
	;

var
	Patcher: TPatcher;
begin
	try
		Patcher := TPatcher.Create;
		try
			case Patcher.Execute of
				PR_INSTALLED   : Message(MSG_INSTALLED, mt_info);
				PR_UPTODATE    : Message(MSG_UPTODATE, mt_info);
				PR_HALTED      : Message(MSG_HALTED, mt_info);
				PR_INSTFAILED  : Message(MSG_INSTFAILED, mt_info);
				PR_IVERSIONFAIL: Message(MSG_IVERSIONFAIL, mt_info);
				PR_BASICREQUIRE: Message(MSG_BASICREQUIRE, mt_info);
			end;
		finally
			Patcher.Free;
		end;
	except
		on e: TObject do
			EMU_Log('Fatal error:\n%s', [Exception(e).Message]);
	end;
end.
