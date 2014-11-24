unit c_http;
interface
uses
	c_httpheaders, c_httpstatus, winsock1, regexpr, c_buffers;

const
	BUF_SIZE = 32 * 1024;

type
	TViewFormat = function (Output: AnsiString; Data: Cardinal): AnsiString;
	THTTPMethod = (httpm_unk, httpm_get, httpm_post, httpm_put, httpm_info, httpm_headers, httpm_options);

	PReqProcessor=^TReqProcessor;
	TReqProcessor= object 
		Method     : THTTPMethod;
		Version    : record Hi, Lo: SmallInt end;

		URI        : AnsiString;
		ParamList  : THTTPHeaders;
		ReqHeaders : THTTPHeaders;
		ResHeaders : THTTPHeaders;

		Status     : Cardinal;
		Contents   : AnsiString;

		Request    : array [0..BUF_SIZE] of Char;
		KeyData    : THTTPHeaders;
		TPLRE      : TRegExpr;

		Socket     : TSocket;
		Formatter  : TViewFormat;
		FmtData    : Cardinal;

		IOBuffer   : PCacheBuffer;
		HeadersSent: Boolean;
		procedure    Init;
		procedure    Destroy;
		function     Process(Input: String): String;
		function     KeyReplacer(ARegExpr : TRegExpr): string;

		function     SendResponse: AnsiString;
		procedure    Redirect(Location: AnsiString; Temporaly: Boolean = true);
	end;

	charset= set of char;

function offset(p1, p2: Pointer): Integer;
function makeRelativeUri(FileName: AnsiString): AnsiString;
function AcceptInclude(BaseFile: AnsiString): AnsiString;
function ProcessTemplate(FileName: AnsiString; out Contents: AnsiString): Boolean;
function TransferFile(Proc: PReqProcessor; FileName: AnsiString): Boolean;
function urldecode(str: ansistring): ansistring;
function urlencode(str: Ansistring): AnsiString;
function urlcompile(uri, params, anchor: AnsiString): AnsiString;
function strsafe(s: AnsiString; escape: charset = ['''', '"']): AnsiString;
function makepath(s: AnsiString): AnsiString;
function htmlspecialchars(s: AnsiString): AnsiString;

const
	_JSON_Formatter: TViewFormat = nil;

implementation
uses
	WinAPI, functions, strings, file_sys, streams, c_mimemagic, EMU_Types,
	internettime;

procedure TReqProcessor.Destroy;
begin
	TPLRE.Free;
	KeyData.Free;
	ParamList.Free;
	ReqHeaders.Free;
	ResHeaders.Free;
end;

procedure TReqProcessor.Init;
begin
	KeyData := THTTPHeaders.Create;
	ParamList := THTTPHeaders.Create('&', '=');
	ReqHeaders := THTTPHeaders.Create;
	ResHeaders := THTTPHeaders.Create;
	TPLRE := TRegExpr.Create;
	TPLRE.ModifierStr := 'isr';
	TPLRE.Expression := '\{\%([^\%]+)\%\}';
//	SetLength(Request, BUF_SIZE + 1);
end;

function TReqProcessor.KeyReplacer(ARegExpr: TRegExpr): string;
begin
	result := ARegExpr.Match[1];
	if result <> '' then
		result := KeyData[result]
	else
		result := '';
end;

function TReqProcessor.Process(Input: String): String;
begin
	result := TPLRE.ReplaceEx(Input, KeyReplacer);
end;

procedure TReqProcessor.Redirect(Location: AnsiString; Temporaly: Boolean);
begin
	ResHeaders.Add(HTTPHDR_LOCATION, Location);
	Status := 301 + Byte(Temporaly);
	SendResponse;
end;

function TReqProcessor.SendResponse: AnsiString;
const
	HTTP_RESPONSE: PAnsiChar = 'HTTP/1.1 %d %s\n';
begin
	result := Format(HTTP_RESPONSE, [Status, CodeStr(Status)]);
	ResHeaders.Delete([HTTPHDR_CONTENT_LEN]);
	if ResHeaders.Count > 0 then result := result + ResHeaders.ToString;
	result := result + #13#10 + Contents;
	winsock1.send(Socket, result[1], Length(result), 0);
end;

(*
	!@$%^&*()-_=+[]{}\|;:' "   , <   . >   /? `   ~#
	!@$%^&*()-_=+[]{}/|;:' %22 , %3C . %3E /? %60 ~#

	" < > `
*)

const
	encodeset: set of ansichar = [
		'/', ' ', '_', '.', '[', ']', '-'
	, '(', ')', ':', '{', '}', '=', '*', '@', '^'
	, '0'..'9', 'a'..'z', 'A'..'Z'
	];
	//['\', '/', '!', '+', ' ', '&', '?', '#', '"', '<', '>', '`', '¹', 'à'..'ÿ', 'À'..'ß',
	//	'³', '²', '¿', '¯', 'º', 'ª', '¸', '¨'];

function urldecode(str: ansistring): ansistring;
var
	p1, p2: PChar;
	l: Integer;
begin
	l := length(str);
	if l <= 0 then begin
		result := '';
		exit;
	end;

	setlength(result, l);
	p1 := @str[1];
	p2 := @result[1];
	while p1 ^ <> #0 do begin
		if p1^ = '%' then begin
			p2^ := chr(HTC(copy(p1, 2, 2)));
			inc(p1, 2);
		end else
{			if p1^ = '+' then
				p2^ := ' '
			else }
				p2^ := p1^;
		inc(p2);
		inc(p1);
	end;
	setlength(result, cardinal(p2) - cardinal(@result[1]));
end;

function urlencode(str: Ansistring): AnsiString;
var
	l: Integer;
	p1, p2: PAnsiChar;
	s: ansistring;
begin
	l := Length(str) + 1;
	str := str + ' ';
	str[l] := #0;
	setLength(result, l * 3);
	p1 := @str[1];
	p2 := @result[1];
	while p1^ <> #0 do begin
		if (p1^ in encodeset) then
			p2^ := p1^
		else begin
			p2^ := '%';
			inc(p2);
			s := ITSPow(ord(p1^), 16, 2);
			p2^ := s[1];
			inc(p2);
			p2^ := s[2];
		end;
		inc(p1);
		inc(p2);
	end;
	setLength(result, Cardinal(p2) - Cardinal(@result[1]));
end;

function urlcompile(uri, params, anchor: AnsiString): AnsiString;
begin
	result := uri;
	if params <> '' then result := '?' + params;
	if anchor <> '' then result := '#' + anchor;
end;

const
	inc_ext : array[0..1] of PAnsiChar = ('htm', 'html');
	inc_path: array[0..2] of PAnsiChar = ('/www', '/html', '/data');

function AcceptInclude(BaseFile: AnsiString): AnsiString;
var
	c, p: AnsiString;
	i, j: Integer;
begin
	if pos(':', BaseFile) > 0 then begin
		if FileExists(BaseFile) then
			result := BaseFile
		else
			if ExtractFileExt(BaseFile) = '' then
				result := ExistFileWithExt(BaseFile, inc_ext)
			else
				result := '';

		exit;
	end;

	c := join('/', strSplit('\', CoreDir));
	repeat
		i := pos('//', c);
		if i > 0 then
			delete(c, i, 1);
	until i <= 0;
	i := Length(c);
	if (i > 0) and (c[i] = '/') then delete(c, i, 1);

	if (Length(BaseFile) <= 0) or (BaseFile[1] <> '/') then BaseFile := '/' + BaseFile;
	result := '';
	for j := 0 to length(inc_path) - 1 do begin
		p := inc_path[j];
		result := c + p + BaseFile;
		if FileExists(result) then break;
		result := ExistFileWithExt(result, inc_ext);
		if result <> '' then exit;
	end;
end;

function makeRelativeUri(FileName: AnsiString): AnsiString;
var
	c: AnsiString;
begin
	c := CoreDir + 'www';
	if pos(c, FileName) = 1 then
		result := copy(FileName, Length(c) + 1, MaxInt)
	else
		result := FileName;
	if (Length(result) <= 0) or (result[1] <> '/') then result := '/' + result;
end;

function offset(p1, p2: Pointer): Integer;
begin
	result := Integer(p1) - Integer(p2);
end;

function strsafe(s: AnsiString; escape: charset): AnsiString;
var
	l: Integer;
	p1, p2: PAnsiChar;
begin
	l := Length(s);
	setLength(result, l * 2);
	if l = 0 then exit;
	p1 := @s[1];
	p2 := @result[1];
	while p1^ <> #0 do begin
		if p1^ in escape then begin
			p2^ := '\';
			inc(p2);
		end;
		p2^ := p1^;
		inc(p1);
		inc(p2);
	end;

	setLength(result, offset(p2, @result[1]));
end;

function makepath(s: AnsiString): AnsiString;
var
	l: Integer;
	p1, p2: PAnsiChar;
begin
	l := Length(s);
	setLength(result, l * 2);
	if l = 0 then exit;
	p1 := @s[1];
	p2 := @result[1];
	while p1^ <> #0 do begin
		if pos(p1^, '?*:"\<|>/') = 0 then
			p2^ := p1^;
		inc(p1);
		inc(p2);
	end;

	setLength(result, offset(p2, @result[1]));
end;

const
	hsc_lt : PAnsiChar = '&lt;'#0;
	hsc_gt : PAnsiChar = '&gt;'#0;
	hsc_amp: PAnsiChar = '&amp;'#0;

function htmlspecialchars(s: AnsiString): AnsiString;
var
	l: Integer;
	p1, p2, p: PAnsiChar;
begin
	l := Length(s);
	setLength(result, l * 5);
	if l = 0 then exit;
	p1 := @s[1];
	p2 := @result[1];
	while p1^ <> #0 do begin
		case p1^ of
//		#13: p := '\n'#0;
//		#10: p := #0;
		'<': p := hsc_lt;
		'>': p := hsc_gt;
		'&': p := hsc_amp;
		else p := nil;
		end;

		if p <> nil then
			while p^ <> #0 do begin
				p2^ := p^;
				inc(p);
				inc(p2);
			end
		else begin
			p2^ := p1^;
			inc(p2);
		end;
		inc(p1);
	end;

	setLength(result, offset(p2, @result[1]));
end;

{
	0 - source is empty
	1 - source is plain text
	2 - source is scripted
}
const
	nsi_opentag : PAnsiChar = '{%inc{';
	nsi_closetag: PAnsiChar = '}}';

function Preprocess(contents: AnsiString; out res: AnsiString): Integer;
var
	c: AnsiString;
	t: array [byte] of ansistring;
	s: array [byte] of ansistring;
	c1, c2: Integer;
	i, j  : Integer;
	k     : Integer;
	p1    : PAnsiChar;
	p3, p4: PAnsiChar;
	p5    : PAnsiChar;
	p7    : PAnsiChar;
	o1, o2: Integer;
label
	l1, l2;
begin
	res := '';
	result := 0;
	if contents = '' then exit;
	result := 1;
	c := contents + '{%inc{}}'#0;
	p1 := @c[1];
	p5 := p1;
	c1 := 0;
	c2 := 0;
	o1 := Length(nsi_opentag);
	o2 := Length(nsi_closetag);
	k  := 0;
	repeat
	l1:
		while (p1^ <> nsi_opentag^) and (p1^ <> #0) do inc(p1);
		if p1^ = nsi_opentag^ then begin
			inc(p1);
			p7 := nsi_opentag;
			inc(p7);
			while p7^ <> #0 do
				if p1^ <> p7^ then goto l1 else begin
					inc(p1);
					inc(p7);
				end;
			p3 := p1;
			repeat
				l2:
				while (p1^ <> nsi_closetag^) and (p1^ <> #0) do inc(p1);
				if p1^ = nsi_closetag^ then begin
					p4 := p1;
					inc(p1);

					p7 := nsi_closetag;
					inc(p7);
					while p7^ <> #0 do
						if p1^ <> p7^ then goto l2 else begin
							inc(p1);
							inc(p7);
						end;

					inc(p1);
					i := offset(p3, p5);
					j := offset(p4, p3);

					t[c1] := (copy(contents, k + 1, i - k - o1));
					inc(c1);

					s[c2] := (copy(contents, i + 1, j));
					inc(c2);
					k := i + j + o2;
					break;
				end;
			until p1^ = #0;
		end;
	until p1^ = #0;

	if (c2 > 1) or ((c2 > 0) and (s[0] <> '')) then begin
		i := 0;
		j := 0;
		while i < c2 do begin
			if t[j] <> '' then
				res := res + t[j];
			if s[i] <> '' then
				if ProcessTemplate(AcceptInclude('/' + s[i] + '.tpl'), {c, }contents) then
					res := res + contents
				else
					res := res + '<!-- [' + s[i] + '] template must be here, but preprocess failed -->';
			inc(i);
			inc(j);
		end;
		result := 2;
	end;
end;

function ProcessTemplate(FileName: AnsiString; out Contents: AnsiString): Boolean;
var
	f: TStream;
	e: AnsiString;
begin
	result := false;
	try
		f := TFileStream.Create(FileName, fmOpen);
		try
			SetLength(Contents, f.Size);
			result := (f.Size = 0) or (f.Read(@Contents[1], f.Size) = f.Size);
		finally
			f.Free;
		end;
	except
		exit;
	end;

	if #239#187#191 = copy(Contents, 1, 3) then delete(Contents, 1, 3);
	Contents := UTF8Decode(Contents);
	if result and (Preprocess(Contents, e) = 2) then
		Contents := e;
end;

function TransferFile(Proc: PReqProcessor; FileName: AnsiString): Boolean;
const
	HTTP_RESPONSE: PAnsiChar = 'HTTP/1.1 %d %s\n';
	Chunk_Buf_Len= 100 * 1024;
var
	S: TStream;
	T, N: AnsiString;
	i, l, b, j: Integer;
	t1, t2: TDateTime;
begin
	N := ExtractFileName(FileName);
	OutputDebugString(PAnsiChar(Format('Request [%s]...', [N])));
	result := FileExists(FileName);
	if result then
		with Proc^ do
			try
				winsock1.shutdown(Socket, SD_RECEIVE);
				t2 := FileGetTime(FileName);

				t := ReqHeaders['if-modified-since'];
				if t <> '' then begin
					t1 := InternetTimeStrToDateTime(t);
					t1 := t1 - t2;
					if abs(t1) < 10e-5 then begin
						OutputDebugString(PAnsiChar(Format('Cached [%s]...', [N])));
						Status := 304; // not modified
						ResHeaders.Add(HTTPHDR_CONTENT_LEN, '0');
						t := Format(HTTP_RESPONSE, [Status, CodeStr(Status)]);
						if ResHeaders.Count > 0 then t := t + ResHeaders.ToString;
						t := t + #13#10;
						i := Length(t);
						result := winsock1.send(Socket, t[1], i, 0) = i;
						exit;
					end;
				end;

				try
					S := TFileStream.Create(FileName, fmOpen);
				except
					Status := 404;
					exit;
				end;

				try
					OutputDebugString(PAnsiChar(Format('transfer [%s]...', [N])));
					l := S.Size;

					Status := 200;

					if l > 0 then begin
						b := imin(l, 1024);
						setLength(t, b);
						if S.Read(@t[1], b) <> b then
							raise Exception.Create('Read operation failed!');
						i := MIMEMagic(FileName, @t[1], b);
					end else
						i := MIMEMagic(FileName, nil, 0);
					ResHeaders.Add(HTTPHDR_CONTENT_LOC, 'http://localhost:2012' + Proc.URI);
					ResHeaders.Add(HTTPHDR_CONTENT_DIS, 'inline; filename=' + N);
					ResHeaders.Add(HTTPHDR_CONTENT_TYPE, MIME_Table[i].MIME + '; name=' + N);
					ResHeaders.Add(HTTPHDR_CONTENT_TE, '8bit');

					ResHeaders.Add(HTTPHDR_TIME, DateTimeToInternetStr(GetTime));
					ResHeaders.Add(HTTPHDR_LAST_MOD, DateTimeToInternetStr(t2));
					ResHeaders.Add(HTTPHDR_CACHE_CTL, 'max-age=' + its(60 * 60 * 24 * 30));

					ResHeaders.Add(HTTPHDR_CONTENT_LEN, its(l));
					ResHeaders.Add(HTTPHDR_CONNECTION, 'Close');
					t := Format(HTTP_RESPONSE, [Status, CodeStr(Status)]) + ResHeaders.ToString + #13#10;
					i := Length(t);
					i := i - winsock1.send(Socket, t[1], i, 0);
					if i = 0 then begin
						i := l;
						S.Position := 0;
						setLength(t, Chunk_Buf_Len);
						while i > 0 do begin
							b := imin(Chunk_Buf_Len, i);
							if S.Read(@t[1], b) <> b then
								raise Exception.Create('Read operation failed!');

//							l := 0;
							j := winsock1.send(Socket, t[1], b, 0);
							if j < 0 then
								raise Exception.Create('Send operation failed: client disconnected!');

{							repeat
								inc(l, j);
								if l >= b then break;
								sleep(100);
								j := winsock1.send(Socket, t[l + 1], b - l, 0);
							until j <= 0; }
							dec(i, b);
						end;
					end;
				finally
					S.Free;
				end;
		except
			result := false;
		end;
	if result then
		OutputDebugString(PAnsiChar(Format('c_http::Transfer [%s] done', [N])));
end;

end.
