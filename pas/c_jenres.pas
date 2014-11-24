unit c_jenres;
interface

type
	PJenreDesc  = ^TJenreDesc;
	TJenreDesc  = record
		Valid     : Boolean;
		Jenre     : AnsiString;
		Descr     : AnsiString;
		Mangas    : Integer;
	end;
	PJenres     =^TJenres;
	TJenres     = record
		Count     : Integer;
		Data      : array [Byte] of TJenreDesc;
	end;

	PJenreDescB =^TJenreDescB;
	TJenreDescB = record
		id: Integer;
		desc: AnsiString;
	end;

	TJenresArray= array of TJenreDescB;

function jd_hasJenre(jd: PJenres; jenreID: Integer): PJenreDesc;

function ja_hasJenre(ja: TJenresArray; jenreID: Integer): PJenreDescB;
function ja_toggleJenre(var ja: TJenresArray; jenreID: Integer; toggleOn: Boolean): PJenreDescB;

implementation

function jd_hasJenre(jd: PJenres; jenreID: Integer): PJenreDesc;
begin
	if jd.Data[jenreID].Valid then
		result := @jd.Data[jenreID]
	else
		result := nil;
end;


function ja_hasJenre(ja: TJenresArray; jenreID: Integer): PJenreDescB;
var
	i: Integer;
begin
	i := length(ja);
	while i > 0 do begin
		dec(i);
		if ja[i].id = jenreID then begin
			result := @ja[i];
			exit;
		end;
	end;
	result := nil;
end;

function ja_toggleJenre(var ja: TJenresArray; jenreID: Integer; toggleOn: Boolean): PJenreDescB;
var
	index: Integer;
begin
	result := ja_hasJenre(ja, jenreID);
	if toggleOn then begin
		if result <> nil then exit; // already toggled on
		index := Length(ja);
		setLength(ja, index + 1);
		result := @ja[index];
		result.id := jenreID;
	end else begin
		if result = nil then exit; // already toggled off
		index := Length(ja);
		result^ := ja[index];
		setLength(ja, index - 1);
		result := nil;
	end;
end;

end.
