library ecv_reader;
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
	TReader = class(TPlugin, IPlugin)
	private
		fMM, fOS: Boolean;
	public
		function  Name: PAnsiChar; override;
		function  ctlToID(Action: AnsiString): Integer; override;
		procedure serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor); override;
		procedure serveChapter(Cont: Boolean; r: TStrings; Proc: PReqProcessor);
		procedure serveTag(r: TStrings; Proc: PReqProcessor);
		procedure serveProgress(r: TStrings; Proc: PReqProcessor);

		property  ManhwaMode: Boolean read fMM write fMM;
		property  OriginalSize: Boolean read fOS write fOS;
	end;

function TReader.ctlToID(Action: AnsiString): Integer;
begin
	result := stringcase(@Action[1], [
		'index'
	, 'chapters'
	, 'chapter'
	, 'continue'
	, 'tag'
	, 'mm'
	, 'progress'
	]);
end;

function TReader.Name: PAnsiChar;
begin
	result := 'reader';
end;

type
	IManga = interface(IPlugin)
		['{620C53AA-0D41-4FBC-8395-4F8424E893AC}']
		procedure   getJenres(out Jenres: TJenres);
	end;

procedure TReader.serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor);
var
	m, i: integer;
	manga: TManga;
	e, u: AnsiString;
	f: EDBFetch;
	u1, u2: Boolean;
	home: IManga;
	hplug: IPlugin;
	j: TJenres;
	guid: TGUID;
begin
	_cb_new(Proc.IOBuffer, 0);
	try
		case ID of
			0: begin
				m := sti(array_shift(r));
				if m <= 0 then
					raise Exception.Create('Manga ID not specified!');

				if not Server.MangaData(m, manga) then
					raise Exception.Create('Aquire failed!');

				ProcessTemplate(AcceptInclude('jenre.tpl'), e);

				Proc.KeyData.Add('id', its(manga.mID));
				Proc.KeyData.Add('id:wide', its(manga.mID, 0, 6));
				Proc.KeyData.Add('manga.title', array_shift(manga.mTitles));
				if Length(manga.mTitles) > 0 then
					Proc.KeyData.Add('subtitles'
					, '<span><span>' +
						join('</span><button class="tdel">-</button></span><br /><span><span>', manga.mTitles) +
						'</span><button class="tdel">-</button></span>'
					);
				if Fetch(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_DESCRS], manga.mID], ['t.content']) > 0 then
					manga.mDescr := f.Rows[0, 0];

				u := '';
				hplug := Server.CtlNamed['manga'];
				if hplug <> nil then begin
					CLSIDFromString('{620C53AA-0D41-4FBC-8395-4F8424E893AC}', guid);
					if hplug.QueryInterface(guid, home) <> 0 then
						home := nil;
				end;

				if home <> nil then
					home.getJenres(j);
				with j do begin
					i := 0;
					m := 0;
					while i < Count do begin
						inc(m);
						if not Data[m].Valid then continue;
						inc(i);
						Proc.KeyData.Add('j.id', its(m));
						Proc.KeyData.Add('j.title', Data[m].Jenre);
						Proc.KeyData.Add('j.desc', Data[m].Descr);
						Proc.KeyData.Add('j.set', bts(ContainsS(Data[m].Jenre, manga.mjenres)));
						u := join(#13#10, [u, Proc.Process(e)]);
					end;
				end;
				Proc.KeyData.Add('jenres', u);
				Proc.KeyData.Add('description', (manga.mDescr));
				_cb_outtemlate(Proc.IOBuffer, 'manga');
			end;
			1: begin

			end;
			2, 3: serveChapter(ID = 3, r, Proc);
			4: serveTag(r, Proc);
			5: begin //mm
				ID := sti(array_shift(r));
				if Fetch(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_MANGAO], id], ['manhwa', 'orig']) = 1 then begin
					u1 := STB(f.Rows[0, 0]);
					u2 := STB(f.Rows[0, 1]);
				end else begin
					u1 := false;
					u2 := false;
				end;
				case sti(Proc.ParamList['param']) of
					1: begin
						u1 := not u1;
						u2 := u1 and u1;
					end;
					else u2 := u1 and not u2;
				end;
				SQL(SQL_DELETEMANGAL, [TBL_NAMES[TBL_MANGAO], id]);
				SQL(SQL_INSERT_III, [TBL_NAMES[TBL_MANGAO], id, Byte(u1), Byte(u2)]);
			end;
			6: serveProgress(r, Proc);
		end;
	finally
		_cb_end(Proc.IoBuffer);
	end;
end;

function Greater(A, B: AnsiString): Boolean;
var
	p1, p2: PAnsiChar;
	i1, i2: Single;
	type tchars= set of AnsiChar;
	function search(var s: PAnsiChar; c: TChars): boolean;
	begin
		while (s^ <> #0) do
			if (s^ in c) then
				break
			else
				inc(s);
		result := s^ <> #0;
	end;
	function readFloat(var s: PAnsiChar): Single;
	var
		t: PAnsiChar;
	begin
		t := s;
		while s^ in ['0'..'9', '.'] do inc(s);
		result := STF(copy(t, 0, Cardinal(s) - Cardinal(t)));
	end;
begin
	result := false;
	p1 := PAnsiChar(UpperCase(A));
	p2 := PAnsiChar(UpperCase(B));

	while search(p1, ['0'..'9']) do
		if search(p2, ['0'..'9']) then begin
			i1 := readFloat(p1);
			i2 := readFloat(p2);
			if abs(i1 - i2) > 0.00001 then begin
				result := i1 > i2;
				exit;
			end;
		end else
			break;
end;

procedure TReader.serveChapter(Cont: Boolean; r: TStrings; Proc: PReqProcessor);
var
	f: EDBFetch;
	id, chap, page: Integer;
	pages: TStrings;
	manga: TManga;
	procedure AquireChapter;
	var
		SR: TSearchRec;
		e, a: AnsiString;
		p: Integer;
		procedure Add;
		begin
			if p >= Length(Pages) then
				SetLength(Pages, p * 2);

			Pages[p] := urlencode(SR.Name);
			inc(p);
		end;
		procedure Sort(var a: array of AnsiString; c: Integer);
		var
			i: Integer;
			t: AnsiString;
			s: Boolean;
		begin
			repeat
				s := true;
				for i := 0 to c - 2 do
					if Greater(a[i], a[i + 1]) then begin
						t := a[i + 1];
						a[i + 1] := a[i];
						a[i] := t;
						s := false;
					end;
			until s;
		end;
	begin
		p := Length(Pages);
		SetLength(Pages, 100);
		try
			a := Format('/%s/%d.4/', [manga.mLink, chap]);
			if FindFirst(OPT_MANGADIR + a + '*', faFiles, SR) = 0 then
				repeat
					if SR.Name[1] = '.' then continue;
					e := LowerCase(ExtractFileExt(SR.Name));
					if Contains(@e[1], graphic_ext) then begin
						Add;
					end;
				until FindNext(SR) <> 0;

			Proc.KeyData.Add('root', '/storage' + urlencode(a));
		finally
			FindClose(SR);
		end;
		SetLength(Pages, p);
		Sort(Pages, p);
	end;
var
	i: Integer;
	e: AnsiString;
begin
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');

	chap := sti(array_shift(r));
	page := sti(array_shift(r));
	if chap <= 0 then chap := 1;
	if page <= 0 then page := 1;
	if Cont then
		if Fetch(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_PROGRE], id], ['c', 'p']) = 1 then begin
			chap := STI(f.Rows[0, 0]);
			page := STI(f.Rows[0, 1]);
		end;

	if chap <= 0 then
		raise Exception.Create('Chapter ID not specified!');

	if Fetch(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_MANGAO], id], ['manhwa', 'orig']) = 1 then begin
		fMM := STB(f.Rows[0, 0]);
		fOS := STB(f.Rows[0, 0]);
	end else begin
		fMM := false;
		fOS := false;
	end;

	if Server.MangaData(id, manga) then
		AquireChapter;

	if Length(manga.mTitles) > 0 then
		e := manga.mTitles[0]
	else
		e := '';
	Proc.KeyData.Add('subtitle', e);

	e := '';
	for i := 0 to Length(pages) - 1 do
		e := join(','#13#10, [e, '			"' + pages[i] + '"']);

	for i := 0 to Length(manga.mTitles) - 1 do
		manga.mTitles[i] := strsafe(manga.mTitles[i]);

	Proc.KeyData.Add('pages', e);
	Proc.KeyData.Add('id', its(id)) ;
	Proc.KeyData.Add('manga', '["' + join('", "', manga.mTitles) + '"]') ;
	Proc.KeyData.Add('jenres', '["' + join('", "', manga.mJenres) + '"]');
	Proc.KeyData.Add('chapter', its(chap)) ;
	Proc.KeyData.Add('page', its(page)) ;
	Proc.KeyData.Add('manhwa', bts(ManhwaMode)) ;
	Proc.KeyData.Add('originalsize', bts(OriginalSize)) ;

	_cb_outtemlate(Proc.IOBuffer, 'chapter');

	SQL('delete from progress where manga = %d', [id]);
	SQL('insert into progress values (%d, %d, %d)', [id, Chap, Page]);
	SQL('delete from m_hist where manga = %d', [id]);
	SQL('insert into m_hist values (%d, %d)', [id, UTCSecconds]);
	Server.ListModified;
end;

procedure TReader.serveProgress(r: TStrings; Proc: PReqProcessor);
var
	id, chap, page: Integer;
	i: Integer;
begin
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');

	chap := sti(array_shift(r));
	page := sti(array_shift(r));
	if chap <= 0 then chap := 1;
	if page <= 0 then page := 1;

	if chap <= 0 then
		raise Exception.Create('Chapter ID not specified!');

	i := UTCSecconds;

	SQL('delete from progress where manga = %d', [id]);
	SQL('insert into progress values (%d, %d, %d)', [id, Chap, Page]);
	SQL('delete from m_hist where manga = %d', [id]);
	SQL('insert into m_hist values (%d, %d)', [id, i]);
	Server.ListModified;
	_cb_append(Proc.IOBuffer, '{res: "ok", manga: ' + its(id) + ', ts: ' + its(i) + '}');
end;

procedure TReader.serveTag(r: TStrings; Proc: PReqProcessor);
var
	id, jenre: Integer;
	s : Boolean;
	c : AnsiString;
	m : TManga;
begin
	Proc.Formatter := nil;
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');
	jenre := sti(array_shift(r));
	if jenre <= 0 then
		raise Exception.Create('Jenre ID not specified!');

	s := sti(Proc.ParamList['set']) = 0;

	c := Format(SQL_DELETE + ' where (t.manga = %d) and (t.jenre = %d)', [TBL_NAMES[TBL_MJENRE], id, jenre]);
	if s then
		c := join(';', [c, Format(SQL_INSERT_II, [TBL_NAMES[TBL_MJENRE], id, jenre])]);

	if SQL(c, []) <> DB_OK then
		_cb_append(Proc.IOBuffer, '{error: "SQL command execution failed o_O"}')
	else begin
		_cb_append(Proc.IOBuffer, '{manga: ' + its(id) + ', jenre: ' + its(jenre) + ', state: ' + its(Byte(s)) +'}');
		Server.ListModified;
	end;
end;

function ecv_LoadPlugin(Server: IServer): IPlugin;
begin
	OPT_MANGADIR := Server.Config('MANGADIR');
	OPT_DATADIR := Server.Config('DATADIR');
	result := TReader.Create(Server);
end;

exports
	ecv_LoadPlugin;

begin
	IsMultiThread := true;
end.
