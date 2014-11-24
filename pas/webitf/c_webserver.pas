unit c_webserver;
interface
uses
	WinAPI,
	winsock1,
	winsock2,
	functions,
	strings,
	EMU_Types,
	c_interactive_lists,
	c_workers,
	c_http,
	c_httpheaders,
	c_httpstatus,
	c_mimemagic,
	c_server,
	RegExpr;

const
	MAX_PROCS = 16;

type
	TWebInterface = class;

	PListenerData =^TListenerData;
	TListenerData = object(TWorkerData)
		ICount      : Integer;
		Sockets     : array [Byte] of TSocket;
		Address     : array [Byte] of TSockAddr;
		WebInterface: TWebInterface;
		InQueue     : PIList;
		Active      : THandle;
		function      isActive: Boolean;
	end;

	PQueuerData   =^TQueuerData;
	TQueuerData   = object(TWorkerData)
		WebInterface: TWebInterface;
	end;

	PWebProcessor =^TWebProcessor;
	TWebProcessor = object(TWorkerData)
		Server      : TWebInterface;
		Ready,HasJob: THandle;
		Data        : TReqProcessor;
	end;

	TWebInterface = class(TReqServer)
	private
		wsa       : WSAData;
		queuer    : TQueuerData;
		fTerminating: Boolean;
		fProcs    : array [0..MAX_PROCS-1] of TWebProcessor;
		fReadies  : array [0..MAX_PROCS-1] of THandle;
		function    ProcessRequest(Processor: PReqProcessor): Boolean;
		function    getTerminated: Boolean;
		procedure   InitProcessors;
	protected
		listener  : TListenerData;
	public
		constructor Create; override;
		destructor  Destroy; override;
		procedure   Stop; override;

		procedure   startListenThread;

		procedure   ProcessQuery(Proc: PReqProcessor);

		property    Terminated: Boolean read getTerminated;
		property    Terminating: Boolean read fTerminating;
	end;

implementation
uses
	file_sys, streams, opts, c_buffers;

procedure InitAddr(Addr: PSOCKADDR; IP: AnsiString; Port: Word);
begin
	with Addr^ do begin
		sin_family      := PF_INET;
		sin_addr.S_addr := inet_addr(@IP[1]);
		sin_port        := htons(Port);
		FillChar(sin_zero, SizeOf(sin_zero), 0);
	end;
end;

const
	ERR_WSA_STARTUP   = $00000001;
	ERR_LISTENER_BIND = $00000002;

procedure Error(Code: Cardinal);
var
	s, e: AnsiString;
begin
	case Code of
		ERR_WSA_STARTUP  : s := 'Can''t startup WSA library.';
		ERR_LISTENER_BIND: s := 'Can''t bind listener socket.';
	end;
	s := s + #13#10#13#10 + SysErrorMessage(WSAGetLastError);
	e := s;
//	AnsiToOemBuff(@s[1], @e[1], Length(s));
//	writeln('Exception: ', e);
	raise Exception.Create(s);
end;

{ TListenerData }

function TListenerData.isActive: Boolean;
begin
	result := WaitForSingleObject(Active, 0) = WAIT_OBJECT_0;
end;

{ TWebInterface }

function FilterProc(CallerId, crnil: PWSABuf; ss, gs: PQOS; CalleeID, cenil: PWSABuf; g: PGroup; CallbackData: DWORD): Integer; stdcall;
begin
	result := CF_Accept;
end;

function t_Queuer(Data: PWorkerData): Boolean; forward;

function t_Listener(Data: PWorkerData): Boolean;
var
	d     : PListenerData absolute Data;
	FDSet : TFDSet;
	tdelta: TTimeVal;
	i,bind: Integer;
	procedure HandleConn(Socket: Integer);
	var
		Addr: TSockAddr;
		Sock: TSocket;
		Len : Integer;
	begin
		Len := SizeOf(TSockAddr);
		Sock:= winsock2.WSAAccept(d.Sockets[Socket], @Addr, @Len, FilterProc, DWord(d));
		if Sock <> WSAECONNREFUSED then
			if _il_append(d.InQueue, Cardinal(Sock)) = nil then
				EMU_Log('conn chunk not generated!');
	end;
begin
	SetEvent(d.Active);
	try
		WSASetLastError(0);
		i := d.ICount;
		bind := i;
		while i > 0 do begin
			dec(i);
			d.Sockets[i] := winsock2.WSASocket(AF_INET, SOCK_STREAM, 0, nil, 0, 0);
			if winsock1.bind(d.Sockets[i], d.Address[i], SizeOf(TSockAddr)) = SOCKET_ERROR then
				dec(bind);
			winsock1.listen(d.Sockets[i], SOMAXCONN);
		end;

		if bind <= 0 then
			Error(ERR_LISTENER_BIND);

		tdelta.tv_sec := 0;
		tdelta.tv_usec:= 50;
		try
			BeginWorkerThread(t_Queuer, @d.WebInterface.queuer);

			while not d.Terminated do begin
				i := d.ICount;
				while i > 0 do begin
					dec(i);
					FDSet.fd_array[i] := d.Sockets[i];
				end;
				FDSet.fd_count := d.ICount;
				i := Select(0, @FDSet, nil, nil, @tdelta);
				if i > 0 then begin
					i := d.ICount;
					while i > 0 do begin
						dec(i);
						if __WSAFDIsSet(d.Sockets[i], FDSet) then HandleConn(i);
					end;
				end;
			end;

			result := true;
		finally
			i := d.ICount;
			while i > 0 do begin
				dec(i);
				winsock1.shutdown(d.Sockets[i], SD_BOTH);
				winsock1.closesocket(d.Sockets[i]);
			end;
		end;
	except
		d.WebInterface.Stop;
		raise;
	end;
	d.WebInterface.Stop;
end;

constructor TWebInterface.Create;
begin
	inherited;
	fTerminating := false;
	WSAStartup($0202, wsa);

	with listener do begin
		WebInterface := Self;
		InQueue      := _il_new;
		Terminated   := false;
		fillchar(Sockets, SizeOf(Sockets), 0);
		fillchar(Address, SizeOf(Address), 0);
		InitAddr(@Address[0], WEB_ITF_LOCL, WEB_ITF_PORT);
		InitAddr(@Address[1], WEB_ITF_IP, WEB_ITF_PORT);
		ICount := 2;
		Active := CreateEvent(nil, false, false, nil);
	end;

	InitProcessors;

	queuer.Terminated := false;
	queuer.WebInterface := Self;
end;

destructor TWebInterface.Destroy;
var
	i: Integer;
begin
	queuer.Terminate;
	listener.Terminate;
	for i := 0 to max_procs - 1 do
		fProcs[i].Terminate;
	WSACleanup;
	inherited;
end;

procedure TWebInterface.Stop;
begin
	fTerminating := true;
end;

function TWebInterface.ProcessRequest(Processor: PReqProcessor): Boolean;
var
	i: Integer;
	R, e: AnsiString;
	C: PAnsiChar;
	procedure skip; begin while c^ in [' ', '	'] do inc(c); end;
	function getMethod: THTTPMethod;
	var
		s: AnsiString;
	begin
		s := '';
		while c^ in ['a'..'z', 'A'..'Z'] do begin s := s + c^; inc(c); end;
		Skip;
		case UpCase(s[2]) of
			'E': if UpCase(s[3]) = 'T' then result := httpm_get else result := httpm_headers;
			'O': result := httpm_post;
			'U': result := httpm_put;
			'N': result := httpm_info;
			'P': result := httpm_options;
			else result := httpm_get;
		end;
	end;
	function parseURI: AnsiString;
	begin
		result := '';
		while c^ <> ' ' do begin
			result := result + c^;
			inc(c);
		end;
		result := result;
		Skip;
	end;
	procedure parseVersion(var Hi, Lo: SmallInt);
	const
		http_sign : PAnsiChar = 'http/'#0;
	var
		p: PAnsiChar;
		r: AnsiString;
		t: Integer;
	begin
		hi := -1;
		lo := -1;

		p := http_sign;
		while (c^ <> #0) and (p^ = LowerCase(c^)) do begin
			inc(p);
			inc(c);
		end;
		if p^ <> #0 then exit;

		r := '';
		while c^ in ['0'..'9'] do begin
			r := r + c^;
			inc(c);
		end;
		Val(r, hi, t);
		if c^ <> '.' then exit;
		inc(c);
		r := '';
		while c^ in ['0'..'9'] do begin
			r := r + c^;
			inc(c);
		end;
		Val(r, lo, t);
		if c^ = #13 then inc(c);
		if c^ = #10 then inc(c);
	end;
var
	t: TStrings;
begin
	result := true;
	with Processor^ do begin
		Status := 404;
		Contents := '';
		ResHeaders.Count := 0;
		ReqHeaders.Count := 0;
		ParamList.Count := 0;
		ResHeaders.Add(HTTPHDR_SERVER, 'Clone 1.01');
		ResHeaders.Copy(ReqHeaders, [HTTPHDR_Cookie]);
		try
			c := PAnsiChar(@Request[0]);
			Method := getMethod;
			uri := parseURI;
			if (uri = '') or (uri[1] <> '/') then uri := '/' + uri;
			if uri[system.length(uri)] = '/' then uri := uri + 'index';
			i := pos('?', uri);
			if i > 0 then begin
				r := copy(uri, i + 1, maxint);
				delete(uri, i, maxint);
			end;

			URI := urldecode(URI);

			with Version do begin
				parseVersion(hi, lo);
				if (hi < 1) or (Lo < 1) then
					Status := 505
				else begin
					ReqHeaders.Text := PAnsiChar(Cardinal(@Request[0]) + offset(c, @Request[0]));
					i := STI(ReqHeaders[HTTPHDR_CONTENT_LEN]);
					if i > 0 then begin
						c := @Request[0];
						inc(c, pos(#13#10#13#10, c) + 3);
						SetString(e, c, i);
					end;
					c := @e[1];
					if c <> nil then
						while c^ <> #0 do begin
							if c^ = '+' then c^ := ' ';
							inc(c);
						end;
					ParamList.Text := join('&', [r, e]);

					case Method of
						httpm_unk : Status := 405;
						httpm_get,
						httpm_post: begin
							KeyData.Count := 0;
							KeyData.Add('server[uri]', uri);
							with ParamList do
								for i := 0 to Count - 1 do
									with Header[i]^ do
										KeyData.Add('request[' + Name + ']', Value);

							t := strSplit('/', Uri);
							if t[0] = '' then array_shift(t);
							if pos(LowerCase(ExtractFileExt(t[length(t) - 1])),
								'.png.ico.jpg.jpeg.gif.tiff.xml.bmp.wbmp.pdf.css.js.html'
								) > 0 then begin
								if t[0] = 'data' then t[0] := OPT_DATADIR else
								if t[0] = 'storage' then t[0] := OPT_MANGADIR;

								e := join('/', t);
								if pos(':', t[0]) = 0 then
									e := AcceptInclude(e);

								if TransferFile(Processor, e) then
									Status := 200
								else
									Status := 404;
							end else
								ServeRequest(Processor);
						end;
						httpm_put : ;
						httpm_info: begin
							_cb_append(Processor.IOBuffer, 'info');
						end;
						httpm_headers: begin
							_cb_append(Processor.IOBuffer, 'header');
						end;
						httpm_options: begin
							_cb_append(Processor.IOBuffer, 'options');
						end;
					end;
				end;
			end;
		except
			result := false;
			Status := 500;
		end;

		if (Status - 400) in [004, 005, 100] then begin
			result := false;
			IOBuffer := nil;
			_cb_init(IOBuffer, Processor);
			try
				try
					_cb_outtemlate(IOBuffer, 'errdoc/e' + its(Status));
					result := true;
				except
					Status := 500;
				end;

				if not result then begin
					e := Format('%d - %s', [Status, CodeStr(Status)]);
					_cb_append(IOBuffer, Format(
						'<html>\n <head>\n  <title>%s</title>\n </head>\n <body>\n  <h1>%s</h1>\n  <p /><small><i>%s</i></small>\n </body></html>'
						, [e, e, 'Clone HTTP server v1.01']
					));
					result := true;
				end;
			finally
				_cb_end(IOBuffer);
				Contents := Process(Contents);
				SendResponse;
			end;
		end;
	end;
end;

function TWebInterface.getTerminated: Boolean;
begin
	result := listener.Terminated and queuer.Terminated;
end;

procedure TWebInterface.ProcessQuery(Proc: PReqProcessor);
var
	l, i, j, k: Integer;
	p: pchar;
	t: TFDSet;
	u: TTimeVal;
begin
	l := 0;
	i := winsock1.recv(Proc.Socket, proc.request[l], BUF_SIZE, 0);
	if i > 0 then inc(l, i);
	Proc.Request[l] := #0;

	p := @Proc.request[0];
	if p <> nil then
		i := Pos('content-length: ', lowercase(p))
	else
		i := 0;

	if i > 0 then begin
		k := pos(#13#10#13#10, p);
		inc(p, i + 15);
		val(p, j, i);
		dec(j, l - (k + 3));
		if i > 0 then begin
			t.fd_array[0] := Proc.Socket;
			u.tv_sec := 0;
			u.tv_usec:= 100;
			t.fd_count := 1;
			while j > 0 do
				if winsock1.select(0, @t, nil, nil, @u) <> 0 then begin
					i := winsock1.recv(Proc.Socket, proc.request[l], BUF_SIZE, 0);
					if i < 0 then
						break
					else begin
						inc(l, i);
						dec(j, i);
					end;
				end;
			proc.request[l] := #0;
		end;
	end;


	if l > 0 then
		ProcessRequest(Proc);
end;

procedure TWebInterface.startListenThread;
begin
	BeginWorkerThread(t_Listener, @listener);
end;

function t_Processor(Data: PWorkerData): Boolean;
var
	d: PWebProcessor absolute Data;
begin
	result := true;
	with d^ do
		try
			SetEvent(Ready);
			ResetEvent(HasJob);
			while not Terminated do
				if WaitForSingleObject(HasJob, 1) = WAIT_OBJECT_0 then
					try
						Server.ProcessQuery(@Data);
						SetEvent(Ready);
					finally
						shutdown(Data.Socket, SD_BOTH);
						closesocket(Data.Socket);
					end;
		except
			result := false;
		end;
end;

procedure TWebInterface.InitProcessors;
var
	i: Integer;
	function InitProcessor(idx: Integer): Boolean;
	begin
		result := true;
		try
			fProcs[i].Data.Init;
			fProcs[i].Server := Self;

			fProcs[i].Ready := CreateEvent(nil, false, false, nil);
			fProcs[i].HasJob:= CreateEvent(nil, false, false, nil);
			fReadies[idx] := fProcs[i].Ready;
			BeginWorkerThread(t_Processor, @fProcs[i]);
		except
			result := false
		end;
	end;
begin
	for i := 0 to MAX_PROCS - 1 do
		if not InitProcessor(i) then break;
end;

function t_Queuer(Data: PWorkerData): Boolean;
var
	d: PQueuerData absolute Data;
	j: Cardinal;
//	f: PWebProcessor;
begin
	result := true;
	with d.WebInterface do
		try
			while (listener.InQueue = nil) and not d.Terminated do
				sleep(10);

			while not d.Terminated do
				if WaitForSingleObject(listener.InQueue.Semaphore, 100) = WAIT_OBJECT_0 then begin
					try
						with listener.InQueue^ do
						repeat
							if listener.InQueue.Head = nil then break;
							j := WaitForMultipleObjects(MAX_PROCS, @fReadies[0], false, 0);

							if j = (j and $3F) then
								with fProcs[j] do begin
{									new(f);
									f.Server := d.WebInterface;
									f.Data.Init;
									f.Data.Socket := TSocket(Head.Data);
									try
										BeginWorkerThread(t_Processor, f);
									finally
									end; }
									Data.Socket := TSocket(Head.Data);
									_il_remove(listener.InQueue, Head, true);
									SetEvent(HasJob);
								end
							else
								break;
						until Head = nil;
					finally
						_il_release(listener.InQueue);
					end;
					sleep(1);
				end;
		except
			result := false;
		end;
end;

end.
