unit ctl_index;
interface
uses
	WinAPI,
	c_webmodel,
	strings,
	functions,
	c_http,
	c_buffers,
	c_manga,
	opts,
	file_sys,
	sql_dbsqladapter,
	sql_database,
	sql_constants,
	sql_dbcommon;

type
	TIndex = class(TClousureCtl, IPlugin)
	public
		function  Name: PAnsiChar; override;
		function  ctlToID(Action: AnsiString): Integer; override;
		procedure serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor); override;

		procedure serveFolder(r: TStrings; Proc: PReqProcessor);
		procedure serveSQL(r: TStrings; Proc: PReqProcessor);
		procedure serveStatistics(r: TStrings; Proc: PReqProcessor);
	end;

implementation
uses
	internettime, c_interactive_lists;

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
	, 'statistics'
	]);
end;

procedure TIndex.serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor);
var
	e: AnsiString;
begin
	_cb_new(Proc.IOBuffer, 0);
	try
		case ID of
			0: Proc.Redirect('/manga');
			1: begin
				_cb_append(Proc.IOBuffer, 'Reader shutdown.');
				Proc.Redirect('/');
				sleep(200);
				Server.Stop;
			end;
			2: _cb_outtemlate(Proc.IOBuffer, join('/', r));
			3: serveFolder(r, Proc);
			4: begin
				_cb_append(Proc.IOBuffer, '<h1>Log:</h1>'#13#10);
				e := join('</li><li>',
					explode(#13#10,
						Server.FetchLog(0)
					)
				);
				_cb_append(Proc.IOBuffer, '<ul><li>' + e + '</li></ul>');
			end;
			5: serveSQL(r, Proc);
			6: serveStatistics(r, Proc);
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
	t: TTableDump;
	tc: Byte;
begin
	l := Server.LogLines;
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
			q := _db_stat(s);
			q := q + '<br />' + join('<br />'#13#10, explode(#13#10, Server.FetchLog(l)));
			Proc.KeyData.Add('error', 'SQL Error: ' + q);
		end else begin
			f.Count := 0;
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
				q := 'SQL Status: OK';

			Proc.KeyData.Add('error', q);
		end;

	until true;
	_cb_outtemlate(Proc.IOBuffer, 'sql');
end;


procedure TIndex.serveFolder(r: TStrings; Proc: PReqProcessor);
var
	id, chap: Integer;
	l: AnsiString;
	m: TManga;
begin
	Proc.Formatter := _JSON_Formatter;
	l := array_shift(r);
	id := STI(l);
	if id <= 0 then
		if trim(l) = '' then
			raise Exception.Create('Entry ID not specified!')
		else begin
			l := Format('%s\\%s\\archives', [OPT_MANGADIR, l]);
			if not FileExists(l) then
				raise Exception.Create('Folder not found o_O');

			_cb_append(Proc.IOBuffer, '{"result": "ok", "location": "' + strsafe(l) + '"}');
			l := 'explorer.exe "' + l + '"';
			WinExec(@l[1], SW_MAXIMIZE);
			exit;
		end;

	chap := sti(array_shift(r));

	l := '';
	if not Server.MangaData(id, m) then
		raise Exception.Create('Manga with specified ID not found');

	l := Format('%s\\%s', [OPT_MANGADIR, m.mLink]);
	if not FileExists(l) then MkDir(l);
	if chap <= 0 then begin
		l := l + '\archives';
		if not FileExists(l) then MkDir(l);
	end else begin
		l := l + '\' + its(chap, 0, SIZE_CHPNAME);
		if not FileExists(l) then
			raise Exception.Create('Chapter not found o_O');
	end;
	_cb_append(Proc.IOBuffer, '{"result": "ok", "location": "' + strsafe(l) + '"}');
	l := 'explorer.exe "' + l + '"';
	WinExec(@l[1], SW_MAX);
end;

procedure TIndex.serveStatistics(r: TStrings; Proc: PReqProcessor);
var
	ml: PIList;
	m : PILItem;
	o, e, s, i, j, b, c, u, n: Integer;
	_c, _r, _s, _n, g: AnsiString;
	tc: array [32..255] of TStrings;
	tr: array [32..255] of TStrings;
	ts: array [32..255] of TStrings;
	tn: array [32..255] of TStrings;
begin
	o := 0;
	e := 0;
	s := 0;
	c := 0;
	n := 0;
	ml := Server.GetList;
	if _il_armor(ml) then
		try
			m := ml.Head;
			while m <> nil do begin
				with (PManga(m.Data)) ^ do begin
					g := mTitles[0];
					b := Byte(CharLowerA(@g[1])^);
					inc(c);
					u := e + o + s;
					i := Length(mJIDS);
					while i > 0 do begin
						dec(i);
						case mJIDS[i].id of
							J_READED   : begin
								array_push(tr[b], g);
								inc(e);
							end;
							J_COMPLETED   : begin
								array_push(tc[b], g);
								inc(o);
							end;
							J_SUSPENDED   : begin
								array_push(ts[b], g);
								inc(s);
							end;
						end;
					end;
					if u = e + o + s then begin
						array_push(tn[b], g);
						inc(n);
					end;
				end;
				m := m.Prev;
			end;
		finally
			_il_release(ml);
		end;

	for b := 32 to 255 do begin
		i := Length(tr[b]);
		if i > 0 then
			while i > 0 do begin
				dec(i);
				j := ContainsS(tr[b][i], tc[b]);
				if j >= 0 then begin
					while j < Length(tc[b]) - 1 do begin
						tc[b][j] := tc[b][j + 1];
						inc(j);
					end;
					SetLength(tc[b], j);
				end;
			end;
	end;

	_r := '';
	_c := '';
	_s := '';
	_n := '';
	for i := 32 to 255 do
		if Length(tc[i]) > 0 then
			_c := _c + '<li class="alpha">' + UpperCase(chr(i)) + '</li><li><a>' + join('</a></li><li><a>', tc[i]) + '</a></li>';
	for i := 32 to 255 do
		if Length(tr[i]) > 0 then
			_r := _r + '<li class="alpha">' + UpperCase(chr(i)) + '</li><li><a>' + join('</a></li><li><a>', tr[i]) + '</a></li>';
	for i := 32 to 255 do
		if Length(ts[i]) > 0 then
			_s := _s + '<li class="alpha">' + UpperCase(chr(i)) + '</li><li><a>' + join('</a></li><li><a>', ts[i]) + '</a></li>';
	for i := 32 to 255 do
		if Length(tn[i]) > 0 then
			_n := _n + '<li class="alpha">' + UpperCase(chr(i)) + '</li><li><a>' + join('</a></li><li><a>', tn[i]) + '</a></li>';

	Proc.KeyData.Add('complete', ITS(o) + '<br/><div class="archs"><ul class="possibles">' + _c + '</ul></div>');
	Proc.KeyData.Add('readed', ITS(e) + '<br/><div class="archs"><ul class="possibles">' + _r + '</ul></div>');
	Proc.KeyData.Add('suspended', ITS(s) + '<br/><div class="archs"><ul class="possibles">' + _s + '</ul></div>');
	Proc.KeyData.Add('ongoing', ITS(n) + '<br/><div class="archs"><ul class="possibles">' + _n + '</ul></div>');
	Proc.KeyData.Add('total', ITS(c));
	_cb_outtemlate(Proc.IOBuffer, 'stats');
end;

end.
