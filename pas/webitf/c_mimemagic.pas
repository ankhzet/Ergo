unit c_mimemagic;
interface

type
	PByteArray = ^TByteArray;
	TByteArray = array [0..0] of Byte;
	TMIMEEntry = record
		MIME     : AnsiString;
		Magic    : PAnsiChar;
		Offs     : ShortInt;
	end;

const
	MIME_HTML_CODE= 'text/html';
	MIME_MAXENTRY = 12;
	MIME_Table    : array[0..MIME_MAXENTRY-1] of TMIMEEntry = (
		(MIME: MIME_HTML_CODE; Magic: 'htm'; Offs: -2;),
		(MIME: MIME_HTML_CODE; Magic: 'html'; Offs: -2;),
		(MIME: MIME_HTML_CODE; Magic: 'tpl'; Offs: -2;),
		(MIME: 'text/plain'; Magic: 'txt'; Offs: -2;),
		(MIME: 'application/executable'; Magic: 'MZP'; Offs: 0;),
		(MIME: 'image/xicon'; Magic: 'ico'; Offs: -2;),
		(MIME: 'image/png'; Magic: '‰PNG'; Offs: 0;),
		(MIME: 'image/jpeg'; Magic: 'JFIF'; Offs: 6;),
		(MIME: 'image/bmp'; Magic: 'bmp'; Offs: -2;),
		(MIME: 'text/css'; Magic: 'css'; Offs: -2;),
		(MIME: 'application/javascript'; Magic: 'js'; Offs: -2;),
		(MIME: 'application/octetstream'; Magic: '*'; Offs: -2;)
	);

function MIMEMagic(FileName: AnsiString; SrcBuffer: PByteArray; Len: Integer): Integer;

implementation
uses
	strings
	;

function MIMEMagic(FileName: AnsiString; SrcBuffer: PByteArray; Len: Integer): Integer;
var
	i, j: Integer;
	e: PAnsiChar;
	p1, p2: PAnsiChar;
begin
	j := Length(FileName);
	i := j;
	while (i > 1) and (FileName[i] <> '.') do dec(i);
	if i >= 1 then
		e := @FileName[i + 1]
	else
		e := '';

	if Len <= 0 then
		if e <> '' then
			for result := 0 to MIME_MAXENTRY - 1 do
				with MIME_Table[result] do
					if Offs = -2 then
						if lstrcmpi(e, Magic) = 0 then
							exit
						else
					else
		else
	else
		for result := 0 to MIME_MAXENTRY - 1 do
			with MIME_Table[result] do
				if Offs = -2 then
					if lstrcmpi(e, Magic) = 0 then
						exit
					else
				else
					if Offs + Length(Magic) <= Len then begin
						p1 := Magic;
						p2 := PAnsiChar(@SrcBuffer[Offs]);
						while p1^ <> #0 do
							if p1^ <> p2^ then
								break
							else begin
								inc(p1);
								inc(p2);
							end;
						if p1^ = #0 then
							exit;
					end;

	result := MIME_MAXENTRY - 1;
end;

end.
