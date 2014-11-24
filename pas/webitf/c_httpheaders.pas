unit c_httpheaders;
interface

type
	PHTTPHeader =^THTTPHeader;
	THTTPHeader = record
		Name      : AnsiString;
		Value     : AnsiString;
	end;
	THTTPHeaders= class
	private
		fData     : array of THTTPHeader;
		Sorted    : Boolean;
		fCount    : Integer;
		Actual    : Integer;
		fPSplitter: AnsiString;
		fPDivider : AnsiString;
		procedure   Sort;
		procedure   setCount(const Value: Integer);
		function    getHeader(Index: Integer): PHTTPHeader;
		procedure   setText(Value: AnsiString);
		function    getData(Key: AnsiString): AnsiString;
	public
		constructor Create(Divider: AnsiString = #13#10; Splitter: AnsiString = ':');
		function    Add(Name, Value: AnsiString): Integer;
		function    IndexOf(Name: PAnsiChar): Integer;
		function    Delete(Names: array of AnsiString): Integer; overload;
		function    Delete(Index: Integer): Integer; overload;
		function    ToString: AnsiString;
		function    Copy(From: THTTPHeaders; Names: array of AnsiString): Integer;
		property    Count: Integer read fCount write setCount;
		property    Header[Index: Integer]: PHTTPHeader read getHeader;
		property    Data[Key: AnsiString]: AnsiString read getData; default;
		property    Text: AnsiString read ToString write setText;

		property    PairDivider : AnsiString read fPDivider write fPDivider;
		property    PairSplitter: AnsiString read fPSplitter write fPSplitter;
	end;

const
	HTTPHDR_SERVER      = 'Server';
	HTTPHDR_LOCATION    = 'Location';
	HTTPHDR_CONTENT_LOC = 'Content-Location';
	HTTPHDR_CONTENT_TYPE= 'Content-Type';
	HTTPHDR_CONTENT_LEN = 'Content-Length';
	HTTPHDR_CONTENT_DIS = 'Content-Disposition';
	HTTPHDR_CONTENT_TE  = 'Content-Transfer-Encoding';
	HTTPHDR_Cookie      = 'Cookie';
	HTTPHDR_CACHE_CTL   = 'Cache-Control';//: max-age=600
	HTTPHDR_CONNECTION  = 'Connection';
	HTTPHDR_TIME        = 'Time';
	HTTPHDR_LAST_MOD    = 'Last-Modified';

implementation
uses
	strings, c_http;

{ THTTPHeaders }

function THTTPHeaders.Add(Name, Value: AnsiString): Integer;
begin
	result := IndexOf(@Name[1]);
	if result < 0 then begin
		result := Count;
		Count  := result + 1;
		fData[result].Name  := Name;
	end;
	fData[result].Value := Value;
end;

function THTTPHeaders.Copy(From: THTTPHeaders; Names: array of AnsiString): Integer;
var
	i, j, k, l, n: Integer;
	e: PAnsiChar;
begin
	n := From.Count;
	result := n;
	j := Length(Names);
	if j <= 0 then begin
		for i := 0 to n - 1 do
			with From.Header[i]^ do
				Add(Name, Value);
	end else begin
		for k := 0 to j - 1 do begin
			e := @Names[k, 1];
			l := From.IndexOf(e);
			if l >= 0 then
				repeat
					with From.Header[l]^ do
						Add(Name, Value);
					inc(l);
					if (l >= n) or (lstrcmpi(@From.Header[l].Name[1], e) <> 0) then
							break

				until false;
		end;
	end;
end;

constructor THTTPHeaders.Create(Divider, Splitter: AnsiString);
begin
	PairDivider := Divider;
	PairSplitter := Splitter;
end;

function THTTPHeaders.Delete(Index: Integer): Integer;
begin
	result := Count - 1;
	while Index < result do begin
		fData[Index] := fData[Index + 1];
		inc(Index);
	end;
end;

function THTTPHeaders.Delete(Names: array of AnsiString): Integer;
var
	j ,k: Integer;
	e: PAnsiChar;
begin
	result := 0;
	j := Length(Names);
	while j > 0 do begin
		dec(j);
		e := @Names[j, 1];
		k := IndexOf(e);
		if k >= 0 then
			repeat
				inc(result);
				Delete(k);
				if (k >= Count) or (lstrcmpi(e, @fData[k].Name[1]) <> 0) then break;
			until false;
	end;
end;

function THTTPHeaders.getData(Key: AnsiString): AnsiString;
var
	i : integer;
begin
	i := IndexOf(@Key[1]);
	if i < 0 then
		result := ''
	else
		result := fData[i].Value;
end;

function THTTPHeaders.getHeader(Index: Integer): PHTTPHeader;
begin
	result := @fData[Index];
end;

function THTTPHeaders.IndexOf(Name: PAnsiChar): Integer;
var
	l, h, n: Integer;
begin
	h := Count - 1;
	if h >= 0 then begin
		if not Sorted then Sort;
		l := 0;
		repeat
			result := (l + h) div 2;
			n := lstrcmpi(Name, @fData[result].Name[1]);
			if n = 0 then exit;
			if n > 0 then
				l := result + 1
			else
				h := result - 1;
		until l > h;
	end;
	result := -1;
end;

procedure THTTPHeaders.setCount(const Value: Integer);
begin
	if fCount <> Value then begin
		fCount := Value;
		if (Actual < Value) or (Actual > Value + $1F) then Actual := Value + $F;
		setLength(fData, Actual);
		Sorted := Value < 2;
	end;
end;

function offset(p1, p2: Pointer): Integer;
begin
	result := Integer(p1) - Integer(p2);
end;

const
	hdr_end : PAnsiChar = #13#10#0;
procedure THTTPHeaders.setText(Value: AnsiString);
var
	i, j, l: Integer;
	p1, p3, p: PAnsiChar;
	v, s: PAnsiChar;
	function Loockup(p: PAnsiChar; var str: PAnsiChar): Boolean;
	var
		t1, t2: PAnsiChar;
	begin
		result := true;
		repeat
			t2 := p;
			while (str^ <> #0) and (str^ <> t2^) do inc(str); // search p[1] or eof

			if str^ = #0 then exit; // eof finded

			t1 := str; // save pat captchure
			while (str^ <> #0) and (str^ = t2^) do begin    // going thru s[i+] = p
				inc(str);
				inc(t2);
			end;

			if t2^ <> #0 then begin // s[i+] != p
				str := t1; // restore captchure
				inc(str); // move forward
				Continue;
			end;
			result := true;
			exit;
		until true;
	end;
label
	fin;
begin
	Value := Value + PairDivider;
	l := Length(Value);
	Count := l div 4;
	i := 0;
	p := @Value[1];
	p1 := p;
	p3 := p;
	v := @PairDivider[1];
	s := @PairSplitter[1];

	while p^ <> #0 do begin
		if p^ = v^ then break;

		if not Loockup(s, p) then goto fin;
		j := offset(p, p1) - 1;
		fData[i].Name := urldecode(trim(system.copy(Value, offset(p1, p3) + 1, j)));

		p1 := p;
		if not Loockup(v, p) then goto fin;
		j := offset(p, p1) - 1;
		fData[i].Value := UTF8Decode(urldecode(trim(system.copy(Value, offset(p1, p3) + 1, j))));
		inc(i);

		p1 := p;
	end;
	fin:
	Count := i;
end;

procedure THTTPHeaders.Sort;
var
	t: THTTPHeader;
	i: Integer;
begin
	repeat
		Sorted := true;
		for i := 0 to Count - 2 do
			if lstrcmpi(@fData[i].Name[1], @fData[i + 1].Name[1]) > 0 then begin
				t := fData[i + 1];
				fData[i + 1] := fData[i];
				fData[i] := t;
				Sorted := false;
			end;
	until Sorted;
end;

function THTTPHeaders.ToString: AnsiString;
var
	i: Integer;
begin
	result := '';
	for i := 0 to Count - 1 do
		result := result + fData[i].Name + PairSplitter + fData[i].Value + PairDivider;
end;

end.
