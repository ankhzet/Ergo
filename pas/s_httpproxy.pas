unit s_httpproxy;
interface
uses
	winsock1, winsock2, mt_engine;

const
	NE_MAXBUFFSIZE= 1024 * 100; // 100 KB

type
	TClientRequest= class(TMTNamedNode)
	private
		BUFFER      : array [0 .. NE_MAXBUFFSIZE - 1] of AnsiChar;
		fLength     : PInteger;
		fData       : PByte;
		fReqTime    : Cardinal;
		fRecTime    : Cardinal;
		function      SendRequest(S: TSocket; Host, Req: AnsiString): Boolean; virtual;
		function      ParseResponse(S: TSocket): Boolean; virtual;
	public
		constructor   Create; virtual;
		function      Request(Port: Integer; Host, Req: AnsiString; TimeOut: Cardinal = 5000): Boolean;
		property      CntLength: PInteger read fLength;
		property      Data: PByte read fData;
		property      ReqTime: Cardinal read fReqTime;
		property      RecTime: Cardinal read fRecTime;
	end;
	THTTPHeaders  = class
	private
		fData       : array of record
			Header    : AnsiString;
			Data      : AnsiString;
		end;
		fText       : AnsiString;
		fCount      : Integer;
		function      _getHeader(Index: Integer): AnsiString;
		procedure     setCount(const Value: Integer);
		procedure     setText(Value: AnsiString);
		function      getData(Index: Integer): AnsiString;
	public
		function      IndexOf(H: AnsiString): Integer;
		function      GetHeader(H: AnsiString): AnsiString;
		function      Add(Header, Data: AnsiString): Integer;
		property      Count: Integer read fCount write setCount;
		property      Text: AnsiString read fText write setText;
		property      Header[Index: Integer]: AnsiString read _getHeader;
		property      Data[Index: Integer]: AnsiString read getData;
	end;
	THTTPProxy    = class(TClientRequest)
	private
		fTreatm     : AnsiString;
		fCode       : Integer;
		fContent    : PAnsiChar;
		fHdrs       : THTTPHeaders;
		function      SendRequest(S: TSocket; Host, Req: AnsiString): Boolean; override;
		function      ParseResponse(S: TSocket): Boolean; override;
	public
		constructor   Create; override;
		destructor    Destroy; override;
		function      Request(Host, URI: AnsiString; TimeOut: Cardinal = 5000): Boolean;
		property      Headers: THTTPHeaders read fHdrs;
		property      Content: PAnsiChar read fContent;
		property      RespCode: Integer read fCode;
		property      RespTreat: AnsiString read fTreatm;
	end;

	TImageInfo    = record
		FileSize    : Integer;
		FileType    : AnsiString;
		AcceptRanges: Boolean;
	end;

	THTTPImageDldr= class;
	TBreakCallback= function(Downloader: THTTPImageDldr): Boolean of object;
	THTTPImageDldr= class
	private
		fTreatm     : AnsiString;
		fCode       : Integer;
		fResponse   : PByte;
		fHdrs       : THTTPHeaders;
		fDldFrom    : Integer;
		HeadersOnly : Boolean;
		fRecTime    : Cardinal;
		fLength     : Integer;
		fReqTime    : Cardinal;
		fData       : PByte;
		fReqStart   : Cardinal;
		fRecDld     : Cardinal;
		fDOffset    : Integer;
		fHdrsAq     : Boolean;
		fMemAlloc   : Cardinal;

		function      SendRequest(CB: TBreakCallback; S: TSocket; Host, Req: AnsiString): Boolean;
		function      ParseResponse(CB: TBreakCallback; S: TSocket): Boolean;
		function      Request(CB: TBreakCallback; Host, ImgPath: AnsiString; TimeOut: Cardinal = 5000): Boolean;
		function      getDldData: Cardinal;
		function      getDldSpeed: Single;
		function      getDldPercent: Byte;
		procedure     AllocMem(const Value: Cardinal);

		property      Response: PByte read fResponse;
	public
		constructor   Create;
		destructor    Destroy; override;


		function      GetInfo(CB: TBreakCallback; Host, ImgPath: AnsiString; out ImgInfo: TImageInfo; TimeOut: Cardinal = 5000): Boolean;
		function      Download(CB: TBreakCallback; Host, ImgPath: AnsiString; From: Integer; TimeOut: Cardinal = 5000): Boolean;
		procedure     ResetStats;
		property      Headers: THTTPHeaders read fHdrs;
		property      RespCode: Integer read fCode;
		property      RespTreat: AnsiString read fTreatm;
		property      MemAlloc: Cardinal read fMemAlloc write AllocMem;

		property      DataOffset: Integer read fDOffset;
		property      DataSize: Integer read fLength;
		property      Data: PByte read fData;
		property      ReqStart: Cardinal read fReqStart;
		property      ReqDld: Cardinal read fRecDld;
		property      ReqTime: Cardinal read fReqTime;
		property      RecTime: Cardinal read fRecTime;
		property      HdrsAquired: Boolean read fHdrsAq;
		property      DataDownloaded: Cardinal read getDldData;
		property      DownloadSpeed: Single read getDldSpeed;
		property      DownloadPercent: Byte read getDldPercent;
	end;

implementation
uses
	WinAPI
//	, net_engine
	, functions
	, strings;

{ THTTPHeaders }

function THTTPHeaders.Add(Header, Data: AnsiString): Integer;
begin
	result := Count;
	Count  := result + 1;
	fData[result].Header := Header;
	fData[result].Data   := Data;
	fText  := fText + Header + ': ' + Data + #13#10;
end;

function THTTPHeaders.getData(Index: Integer): AnsiString;
begin
	result := fData[Index].Data;
end;

function THTTPHeaders._getHeader(Index: Integer): AnsiString;
begin
	result := fData[Index].Header;
end;

function THTTPHeaders.getHeader(H: AnsiString): AnsiString;
var
	i: Integer;
begin
	i := IndexOf(H);
	if i < 0 then
		result := ''
	else
		result := fData[i].Data;
end;

function THTTPHeaders.IndexOf(H: AnsiString): Integer;
begin
	result := Count;
	while result > 0 do begin
		dec(result);
		if lstrcmpi(@h[1], @fData[result].Header[1]) = 0 then exit;
	end;
	result := -1;
end;

procedure THTTPHeaders.setCount(const Value: Integer);
begin
	if fCount <> Value then begin
		fCount := Value;
		setLength(fData, Value);
		if fCount = 0 then fText := '';
	end;
end;

function TrimRight(S: AnsiString): AnsiString;
var
	l: Integer;
begin
	l := Length(S);
	while (l > 0) and (S[l] in [#9, #10, #13, #32]) do dec(l);
	SetString(result, PAnsiChar(@S[1]), l);
end;

procedure THTTPHeaders.setText(Value: AnsiString);
var
	i, l: Integer;
	c   : AnsiChar;
	head: array [Boolean] of AnsiString;
	onh : Boolean;
begin
	if fText <> Value then begin
		fText := '';
		Value := TrimRight(Value) + #13#10;
		Count := 0;
		l     := Length(Value);
		i     := 1;
		onh   := true;
		while i <= l do begin
			c := Value[i];
			case c of
				#13, #0: begin
					inc(i);
					Add(head[true], head[false]);
					head[false] := '';
					head[true]  := '';
					onh         := true;
				end;
				':': begin
					if onh and (Value[i + 1] = ' ') then inc(i);
					onh := false;
				end;
				else
					head[onh] := head[onh] + c;
			end;
			inc(i);
		end;
	end;
end;

{ TClientRequest }

constructor TClientRequest.Create;
begin
	fLength:= @BUFFER[0];
	fData  := @BUFFER[4];
end;

function TClientRequest.Request(Port: Integer; Host, Req: AnsiString; TimeOut: Cardinal): Boolean;
var
	T   : TSocket;
	A, S: TSockAddr;
	C   : Boolean;
	v   : Integer;
	d   : Cardinal;
	e   : PHostEnt;
begin
	result := false;
	e := winsock1.gethostbyname(PAnsiChar(@host[1]));
	if e = nil then
		raise Exception.Create('Cant resolve server addres: ' + SysErrorMessage(WSAGetLastError));

	with A do begin
		sin_family      := PF_INET;
		sin_addr.S_addr := INADDR_ANY;
		sin_port        := htons(0);
		FillChar(sin_zero, SizeOf(sin_zero), 0);
	end;
	with S do begin
		sin_family      := PF_INET;
		sin_addr.S_addr := inet_addr(inet_ntoa(PInAddr(e.h_addr_list^)^));
		sin_port        := htons(Port);
		FillChar(sin_zero, SizeOf(sin_zero), 0);
	end;

	T := winsock2.WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, 0);
	try
		if winsock1.bind(T, A, SizeOf(A)) = SOCKET_ERROR then
			raise Exception.Create('Client socket bind failed: ' + SysErrorMessage(WSAGetLastError));

		d := GetTickCount;
		repeat
			v := winsock2.WSAConnect(T, S, SizeOf(S), nil, nil, nil, nil);
			C := v <> SOCKET_ERROR;
			sleep(5);
		until C or ((TimeOut <> 0 ) and (GetTickCount - d > TimeOut));
		if C then
			try
				fReqTime := GetTickCount - d;
				result := SendRequest(T, Host, Req);
			finally
				winsock1.shutdown(T, SD_BOTH);
			end
		else
			raise Exception.Create('Connection failed: ' + SysErrorMessage(WSAGetLastError));
	finally
		winsock1.closesocket(T);
	end;
end;

function TClientRequest.SendRequest(S: TSocket; Host, Req: AnsiString): Boolean;
var
	l: Integer;
begin
	l := Length(Req) + 1;
	result := (winsock1.send(S, Req[1], l, 0) = l) and ParseResponse(S);
end;

function TClientRequest.ParseResponse(S: TSocket): Boolean;
const
	max_timeout= 5000;
var
	i, l: Integer;
	t: TFDSet;
	u: TTimeVal;
	c, r: Cardinal;
	B: PByte;
begin
	l := 0;
	u.tv_sec := 0;
	u.tv_usec:= 10;
	t.fd_array[0] := S;
	c := GetTickCount;
	r := c;
	b := Data;
	repeat
		t.fd_count := 1;
		if winsock1.select(0, @t, nil, nil, @u) <> 0 then
			if __WSAFDIsSet(S, t) then begin
				i := winsock1.recv(S, b^, 8000, 0);
				if i > 0 then begin
					inc(l, i);
					inc(Cardinal(b), i);
				end else
					break;
				c := GetTickCount;
			end else
		else
			sleep(0);

		if GetTickCount - c > max_timeout then break;
	until false;
	fRecTime := GetTickCount - r;
	inc(fReqTime, fRecTime);
	CntLength^ := l;
	result := l > 0;
end;

{ THTTPProxy }

constructor THTTPProxy.Create;
begin
	inherited Create;
	fHdrs := THTTPHeaders.Create;
end;

destructor THTTPProxy.Destroy;
begin
	fHdrs.Free;
	inherited;
end;

function THTTPProxy.Request(Host, URI: AnsiString; TimeOut: Cardinal): Boolean;
begin
	result := inherited Request(80, Host, URI, TimeOut);
end;

function THTTPProxy.SendRequest(S: TSocket; Host, Req: AnsiString): Boolean;
begin
	Headers.Count := 0;
	Headers.Add('Host', Host);
	Headers.Add('Connection', 'close');
	Headers.Add('Accept', 'text/html, text/xml, */*');
	Headers.Add('Accept-encoding', 'utf-8, windows-cp1251, *');

	Req := 'GET ' + Req + ' HTTP/1.1'#13#10 + Headers.Text + #13#10;

	result := inherited SendRequest(S, Host, Req) and ((RespCode - 100) in [100, 202]);
end;

function THTTPProxy.ParseResponse(S: TSocket): Boolean;
var
	i, j, k, l: Integer;
	d: PAnsiChar;
	t: WideString;
	u: PWideChar;
begin
	fCode        := 0;
	fTreatm      := '';
	Headers.Text := '';
	fContent     := nil;

	result := inherited ParseResponse(S);
	if not result then exit;

	d := PAnsiChar(Data);
	l := CntLength^;
	d[l] := #0;

	i := pos(' ', d) - 1;
	j := i;
	while (j < l) and (d[j + 1] <> ' ') do inc(j);
	k := j + 2;
	while (k < l) and (d[k + 1] <> #13) do inc(k);
	Val(copy(d, i + 2, j - i), fCode, i);
	fTreatm := copy(d, j + 3, k - j - 1);
	i := pos(AnsiString(#13#10#13#10), d);
	Headers.Text := copy(d, k + 4, i - k - 4);
	inc(i, 3);
	j := Headers.IndexOf('Transfer-Encoding');
	if (j >= 0) and Contains(@Headers.Data[j][1], ['chunked']) then inc(i, 6);
	j := Headers.IndexOf('charset');
	if j < 0 then
		j := Headers.IndexOf('Content-Type');
	fContent := PAnsiChar(Cardinal(Data) + i);
	if j > 0 then
		if pos('utf-8', LowerCase(Headers.Data[j])) > 0 then begin
//			inc(Cardinal(fContent), 3);
//			inc(i, 3);
			setLength(t, (l - i) * 3);
			j := MultiByteToWideChar(CP_UTF8, 0, PansiChar(fContent), Integer(l - i), @t[1], Integer((l - i) * 3));
	t[j + 1] := #0;
	t[j + 2] := #0;
	u := @t[1];
	while u^ <> #0 do begin
		if u^ = '\' then begin
			inc(u);
			if u^ <> 'u' then continue;
			inc(u);
			k := HTC(copy(u, 1, 4));
			dec(u, 2);
			u^ := WideChar(k);
			inc(u);
			move(PByte(Cardinal(u) + 10)^, u^, j);
			dec(j, 5);
		end else begin
			inc(u);
			dec(j);
		end;
	end;
			fContent := PAnsiChar(AnsiString(t));
		end;
end;

{ THTTPImageDldr }

procedure THTTPImageDldr.AllocMem(const Value: Cardinal);
begin
	if fMemAlloc <> Value then begin
		fResponse := ReallocMemory(fResponse, Value);
		fMemAlloc := Value;
	end;
end;

constructor THTTPImageDldr.Create;
begin
	inherited;
	fHdrs     := THTTPHeaders.Create;
	fLength   := 0;
	fResponse := nil;
	MemAlloc  := 500 * 1024;
end;

destructor THTTPImageDldr.Destroy;
begin
	FreeMemory(fResponse);
	fHdrs.Free;
	inherited;
end;

const max_timeout = 60000;

function THTTPImageDldr.ParseResponse(CB: TBreakCallback; S: TSocket): Boolean;
var
	i   : Integer;
	t   : TFDSet;
	u   : TTimeVal;
	c   : Cardinal;
	B   : PByte;
	max : Integer;
	procedure ParseHeaders;
	var
		i, j, k: Integer;
		d: AnsiString;
	begin
		d := PAnsiChar(fResponse);
		i := pos(AnsiString(' '), d) + 1;
		j := i;
		while (j < fRecDld) and (d[j + 1] <> ' ') do inc(j);
		k := j + 2;
		while (k < fRecDld) and (d[k + 1] <> #13) do inc(k);
		Val(copy(d, i, j - i + 1), fCode, i);
		fTreatm := copy(d, j + 2, k - j - 1);
		i := pos(AnsiString(#13#10#13#10), d);
		Headers.Text := copy(d, k + 3, i - k - 3);

		fDOffset := i + 3;
		j := Headers.IndexOf('Content-Length');
		if j >= 0 then
			fLength := STI(Headers.Data[j])
		else
			fLength := fRecDld - (i + 4);

		if not HeadersOnly then
			MemAlloc := DataSize + 100 * 1024;
		fData := PByte(Cardinal(fResponse) + fDOffset);
		b := PByte(Cardinal(fResponse) + fRecDld);

		fHdrsAq := true;
	end;
begin
	fCode        := 0;
	fTreatm      := '';
	Headers.Text := '';
	fData        := nil;
	fLength      := 0;
	fDOffset     := 0;
	MemAlloc     := 500 * 1024;  // 500 KB

	u.tv_sec := 0; u.tv_usec:= 100; t.fd_array[0] := S;

	fReqStart := GetTickCount;
	fRecDld   := 0;
	c := fReqStart;
	b := fResponse;
	max := (Byte(not HeadersOnly) * 63 + 1) * 1024;  // 1 or 64 KB

	repeat
		t.fd_count := 1;
		if winsock1.select(0, @t, nil, nil, @u) <> 0 then begin
//			if __WSAFDIsSet(S, t) then begin
				i := winsock1.recv(S, b^, max, 0);
				if i > 0 then begin
					inc(fRecDld, i);
					inc(Cardinal(b), i);
				end else
					break;
				c := GetTickCount;
				if (fRecDld >= 1024) and not HdrsAquired then begin
					ParseHeaders;
					if HeadersOnly then break;
				end;
				if HdrsAquired and (ReqDld - DataOffset >= DataSize) then break;
//			end else
		end else
			if Assigned(CB) and not CB(Self) then break;

		if GetTickCount - c > max_timeout then break;
		sleep(1);
	until false;
	fRecTime := GetTickCount - fReqStart;
	inc(fReqTime, fRecTime);
	if not HdrsAquired then ParseHeaders;
	result := fRecDld > 0;
end;

function THTTPImageDldr.Request(CB: TBreakCallback; Host, ImgPath: AnsiString; TimeOut: Cardinal): Boolean;
var
	T   : TSocket;
	A, S: TSockAddr;
	C   : Boolean;
	v   : Integer;
	d   : Cardinal;
	e   : PHostEnt;
begin
	fHdrsAq:= false;
	result := false;
	try
		e := winsock1.gethostbyname(@host[1]);
	except
		raise Exception.Create('Cant resolve server addres: '+ SysErrorMessage(WSAGetLastError));
	end;
	if e = nil then
		raise Exception.Create('Cant resolve server addres: '+ SysErrorMessage(WSAGetLastError));

	with A do begin
		sin_family      := PF_INET;
		sin_addr.S_addr := INADDR_ANY;
		sin_port        := htons(0);
		FillChar(sin_zero, SizeOf(sin_zero), 0);
	end;
	with S do begin
		sin_family      := PF_INET;
		sin_addr.S_addr := inet_addr(inet_ntoa(PInAddr(e.h_addr_list^)^));
		sin_port        := htons(80);
		FillChar(sin_zero, SizeOf(sin_zero), 0);
	end;

	T := winsock2.WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, 0);
	try
		if winsock1.bind(T, A, SizeOf(A)) = SOCKET_ERROR then
			raise Exception.Create('Client socket bind failed: '+ SysErrorMessage(WSAGetLastError));

		d := GetTickCount;
		repeat
			v := winsock2.WSAConnect(T, S, SizeOf(S), nil, nil, nil, nil);
			C := v <> SOCKET_ERROR;
			sleep(10);
		until C or ((TimeOut <> 0 ) and (GetTickCount - d > TimeOut));
		if C then
			try
				fReqTime := GetTickCount - d;
				result := SendRequest(CB, T, Host, ImgPath);
			finally
				winsock1.shutdown(T, SD_BOTH);
			end
		else
			Exception.Create('Connection failed: '+ SysErrorMessage(WSAGetLastError));
	finally
		winsock1.closesocket(T);
	end;
end;

procedure THTTPImageDldr.ResetStats;
begin
	fRecDld := 0;
end;

function THTTPImageDldr.Download(CB: TBreakCallback; Host, ImgPath: AnsiString; From: Integer; TimeOut: Cardinal = 5000): Boolean;
begin
	fDldFrom    := From;
	HeadersOnly := false;
	result      := Request(CB, Host, ImgPath, TimeOut);
end;

function THTTPImageDldr.getDldData: Cardinal;
begin
	if HdrsAquired then
		result := ReqDld - DataOffset
	else
		result := 0;
end;

function THTTPImageDldr.getDldPercent: Byte;
begin
	if HdrsAquired then
		result := Round(((ReqDld - DataOffset) / DataSize) * 100)
	else
		result := 0;
end;

function THTTPImageDldr.getDldSpeed: Single;
begin
	if GetTickCount - ReqStart > 0 then
		result := ReqDld / (GetTickCount - ReqStart)
	else
		result := 0;
end;

function THTTPImageDldr.GetInfo(CB: TBreakCallback; Host, ImgPath: AnsiString; out ImgInfo: TImageInfo; TimeOut: Cardinal): Boolean;
begin
	fDldFrom   := 0;
	HeadersOnly:= True;
	result     := Request(CB, Host, ImgPath, TimeOut);
	if result then begin
		ImgInfo.FileSize    := STI(Headers.Data[Headers.IndexOf('Content-Length')]);
		ImgInfo.FileType    := Headers.Data[Headers.IndexOf('Content-Type')];
		ImgInfo.AcceptRanges:= Headers.IndexOf('Accept-Ranges') >= 0;
	end;
end;

function THTTPImageDldr.SendRequest(CB: TBreakCallback; S: TSocket; Host, Req: AnsiString): Boolean;
var
	l: Integer;
begin
	Headers.Text := '';
	Headers.Add('Host', Host);
	Headers.Add('Accept', 'image/jpg, image/png, image/gif, image/x-xnitmap, text/html, */*');
	Headers.Add('Cache-Control', 'no-cache');
	Headers.Add('Connection', 'Keep-Alive');

	if fDldFrom > 0 then
		Headers.Add('Range', 'bytes=' + ITS(fDldFrom) + '-');

	l := 1;
	while (l < Length(Host)) and (Host[l] <> '.') do inc(l);
	if l < Length(Host) - 5 then
		Headers.Add('Referer', 'http://' + copy(Host, l + 1, MaxInt))
	else
		Headers.Add('Referer', 'http://' + Host);
	Req := 'GET ' + Req + ' HTTP/1.1'#13#10 + Headers.Text + #13#10;

	FillChar(fResponse^, MemAlloc, 0);

	l := Length(Req) + 1;
	result := (winsock1.send(S, Req[1], l, 0) = l) and (ParseResponse(CB, S) and (RespCode in [200, 206]));
end;

end.
