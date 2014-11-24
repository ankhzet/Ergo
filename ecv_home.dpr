library ecv_home;
uses
//	FastMM4,
	ShareMem,
	WinAPI,
	c_webmodel,
	c_plugin,
	strings,
	functions,
	c_http,
	c_buffers,
	c_manga,
	opts,
	file_sys,
	sql_dbcommon;

{$R *.res}

type
	TIndex = class(TPlugin, IPlugin)
	public
		function  Name: PAnsiChar; override;
		function  ctlToID(Action: AnsiString): Integer; override;
		procedure serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor); override;

		procedure serveFolder(r: TStrings; Proc: PReqProcessor);
		procedure serveSQL(r: TStrings; Proc: PReqProcessor);
	end;

function TIndex.Name: PAnsiChar;
begin
	result := 'index';
end;

function TIndex.ctlToID(Action: AnsiString): Integer;
begin
	result := stringcase(@Action[1], [
		'index'
	, 'quit'
	, 'static'
	, 'folder'
	, 'log'
	, 'sql'
	]);
end;

procedure TIndex.serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor);
var
	e: AnsiString;
	i: Integer;
begin
	_cb_new(Proc.IOBuffer, 0);
	try
		case ID of
			0: Proc.Redirect('/manga');
			1: begin
				_cb_append(Proc.IOBuffer, 'Reader shutdown.');
				Proc.Redirect('/');
				sleep(200);
//				Stop;
			end;
			2: _cb_outtemlate(Proc.IOBuffer, join('/', r));
			3: serveFolder(r, Proc);
			4: begin
				_cb_append(Proc.IOBuffer, '<h1>Log:</h1>'#13#10);
//				for i := 0 to LogLines.Count - 1 do
//					e := e + Format('<li>[%s] %s<br /></li>'#13#10, [DateTimeToStr(PDateTime(LogLines.Data[i])^), LogLines[i]]);
				_cb_append(Proc.IOBuffer, '<ul>' + e + '</ul>');
			end;
			5: serveSQL(r, Proc);
		end;
	finally
		_cb_end(Proc.IOBuffer);
	end;
end;


procedure TIndex.serveSQL(r: TStrings; Proc: PReqProcessor);
const
	odd: array [boolean] of pchar = ('', ' class="odd"');
var
	f: EDBFetch;
	q, qq, dq: AnsiString;
	s: Cardinal;
	i, j, c, l: integer;
//	t: TTableDump;
	tc: Byte;
begin
//	l := LogLines.Count;
	s := DB_OK;
	repeat
		if Proc.ParamList['action'] = 'delete' then begin
			q := trim(Proc.ParamList['select']);
			if q = '' then break;
			q := 'delete from ' + Proc.ParamList['tables'] + ' where (' + q + ') limit 1';
			s := Server.SQL(q);
			if s = DB_OK then begin
				q := trim(Proc.ParamList['oldquery']);
				Proc.ParamList.Add('query', q);
				Proc.KeyData.Add('request[query]', q);
			end else
				q := '';
		end;

		if Proc.ParamList['action'] = 'execute' then begin
			q := trim(Proc.ParamList['query']);
			if q = '' then break;
		end;
		if q <> '' then
			s := Server.SQL(escapeslashes(q));

		if s <> DB_OK then begin
{			q := _db_stat(s);
			while l < LogLines.Count do begin
				q := join('<br />'#13#10, [q, LogLines[l]]);
				inc(l);
			end;  }
			Proc.KeyData.Add('error', 'SQL Error: ' + q);
		end else begin
{			f.Count := 0;
			tc := 0;
			if DB.Requests <> nil then begin
				FetchRows(DB.Requests, [], f);
				t := PDBSelResult(DB.Requests).Tables;
				tc := PDBSelResult(DB.Requests).TableCnt;
				_db_req_free(DB.Requests);
			end;

			if f.Count > 0 then begin
				dq := '';
				for i := 0 to tc - 1 do
					dq := join('`, `', [dq, t[i].Alias]);
				dq := urlencode('`' + dq + '`') + '&oldquery=' + urlencode(trim(Proc.ParamList['query']));

				c := Length(f.Rows[0]);
				q := '';
				q := q + '<div id="dtcontainer"><table id="datatable"><tr class="header"><td><a>';
				for i := 0 to c - 1 do
					q := join('</a></td><td><a>', [q, f.Collumns[i].Name]);

				q := q + '</a></td>';

				for i := 0 to f.Count - 1 do begin
					qq := '';
					for j := 0 to c - 1 do
						qq := join(') and (', [qq, f.Collumns[j].Name + ' = "' + f.Rows[i, j] + '"']);

					q := join(
						'</tr><tr'
						+ odd[boolean(i mod 2)]
						+ '><td><a class="del" href="/sql?action=delete&tables='
						+ dq + '&select=('
						+ urlencode(UTF8Encode(qq))
						+ ')"></a></td><td>'
					, [q, join('</td><td>', f.Rows[i], false)]);
				end;

				q := q + '</tr><tr class="header"><td><a>';

				for i := 0 to c - 1 do
					q := join('</a></td><td><a>', [q, f.Collumns[i].Name]);

				q := q + '</a></td></tr></table></div>';
			end else
				q := 'SQL Status: OK'; }

			Proc.KeyData.Add('error', q);
		end;

	until true;
	_cb_outtemlate(Proc.IOBuffer, 'sql');
end;


procedure TIndex.serveFolder(r: TStrings; Proc: PReqProcessor);
var
	id: Integer;
	l: AnsiString;
	m: TManga;
begin
	Proc.Formatter := JSON_Formatter;
	id := STI(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Entry ID not specified!');

	l := '';
	if not Server.MangaData(id, m) then
		raise Exception.Create('Manga with specified ID not found');

	l := Format('%s\\%s', [OPT_MANGADIR, m.mLink]);
	if not FileExists(l) then MkDir(l);
	l := l + '\archives';
	if not FileExists(l) then MkDir(l);
	_cb_append(Proc.IOBuffer, '{result: "ok", location: "' + strsafe(l) + '"}');
	l := 'explorer.exe "' + l + '"';
	WinExec(@l[1], SW_SHOWNORMAL);
end;

function ecv_LoadPlugin(Server: IServer): IPlugin;
begin
	OPT_MANGADIR := Server.Config('MANGADIR');
	OPT_DATADIR := Server.Config('DATADIR');
	result := TIndex.Create(Server);
end;

exports
	ecv_LoadPlugin;

begin
	IsMultiThread := true;
end.
