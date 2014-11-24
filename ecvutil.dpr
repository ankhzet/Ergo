program ecvutil;
uses
	WinAPI, strings, ComTestNs;
{$APPTYPE CONSOLE}



function readln: string;
begin
	system.Readln(result);
end;

var
	s: string;
	i: integer;
	h: THandle;
	c: Cardinal;
begin
//	with TProto.Create do
		try

			while (readln) <> '' do;
		finally
//			Free;
		end;
end.
