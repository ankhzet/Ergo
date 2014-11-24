unit ctl_reader;
interface
uses
	WinAPI,
	c_webmodel,
	strings,
	functions,
	c_http,
	c_buffers,
	c_manga,
	c_jenres,
	opts,
	file_sys,
	sql_constants,
	sql_dbcommon;

type
	TReader = class(TClousureCtl, IPlugin)
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

implementation

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
//	home: IManga;
//	hplug: IPlugin;
	j: TJenres;
//	guid: TGUID;
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
				if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_DESCRS], manga.mID], ['t.content']) > 0 then
					manga.mDescr := f.Rows[0, 0];

				u := '';
(*				hplug := Server.CtlNamed['manga'];
				if hplug <> nil then begin
					CLSIDFromString('{620C53AA-0D41-4FBC-8395-4F8424E893AC}', guid);
					if hplug.QueryInterface(guid, home) <> 0 then
						home := nil;
				end; *)

//				if home <> nil then
					Server.getJenres(j);

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
						Proc.KeyData.Add('j.set', bts(ContainsS(Data[m].Jenre, manga.mjenres) >= 0));
						u := join(#13#10, [u, Proc.Process(e)]);
					end;
				end;
				Proc.KeyData.Add('jenres', u);
				Proc.KeyData.Add('folder', manga.mLink);
				Proc.KeyData.Add('description', (manga.mDescr));
				_cb_outtemlate(Proc.IOBuffer, 'manga');
			end;
			1: begin

			end;
			2, 3: serveChapter(ID = 3, r, Proc);
			4: serveTag(r, Proc);
			5: begin //mm
				Proc.Formatter := _JSON_Formatter;
				ID := sti(array_shift(r));
				if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_MANGAO], id], ['manhwa', 'orig']) = 1 then begin
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
				SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_MANGAO], id]);
				SQLCommand(SQL_INSERT_III, [TBL_NAMES[TBL_MANGAO], id, Byte(u1), Byte(u2)]);
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
	id, page: Integer;
	chap, oldChap, last: Single;
	pages: TStrings;
	manga: TManga;
	procedure Sort(var a: array of AnsiString);
	var
		i: Integer;
		t: AnsiString;
		s: Boolean;
		c: Integer;
	begin
		c := Length(a);
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
	function AquireChapter(ChapterName: AnsiString): Boolean;
	var
		SR: TSearchRec;
		e, a: AnsiString;
		count: Integer;
		procedure Add;
		begin
			if count >= Length(Pages) then
				SetLength(Pages, count * 2);

			Pages[count] := urlencode(SR.Name);
			inc(count);
		end;
	begin
		count := Length(Pages);
		SetLength(Pages, 100);
		a := Format('/%s/%s/', [manga.mLink, ChapterName]);
		Proc.KeyData.Add('root', '/storage' + urlencode(a));

		if FindFirst(OPT_MANGADIR + a + '*', faFiles, SR) = 0 then
			try
				repeat
					if SR.Name[1] = '.' then continue;
					e := LowerCase(ExtractFileExt(SR.Name));
					if Contains(@e[1], graphic_ext) then begin
						Add;
					end;
				until FindNext(SR) <> 0;
			finally
				FindClose(SR);
			end;
		SetLength(Pages, count);

		Sort(Pages);
		result := count <> 0;
	end;
	function LookAhead(Chapter: Single; Forward: Boolean): Single;
	var
		chaps: TStrings;
		path : AnsiString;
		SR   : TSearchRec;
		i, j : Integer;
	begin
		path := Format('%s/%s/*', [OPT_MANGADIR, manga.mLink]);
		if FindFirst(path, faDirectory, SR) = 0 then
			try
				repeat
					if SR.Attr and faDirectory <> faDirectory then continue;
					if sti(SR.Name) = 0 then continue;
					array_push(chaps, SR.Name);
				until FindNext(SR) <> 0;
			finally
				FindClose(SR);
			end;
		Sort(chaps);
		j := Length(chaps);
		if j > 0 then
			last := stf(chaps[j - 1])
		else
			last := Chapter;

		if Forward then
			for i := 0 to j - 1 do
				if stf(chaps[i]) > Chapter then begin
					Chapter := stf(chaps[i]);
					break;
				end else
		else
			for i := j - 1 downto 0 do
				if stf(chaps[i]) < Chapter then begin
					Chapter := stf(chaps[i]);
					break;
				end;

		result := Chapter;
	end;

	function LoadChapter(Chapter: Single): Boolean;
	var
		cName: AnsiString;
	begin
		if trunc(frac(Chapter) * 10) = 0 then
			cName := Format('%d0.4', [trunc(Chapter)])
		else
			cName := Format('%f6.1', [Chapter]);

		result := AquireChapter(cName);
	end;
var
	i: Integer;
	e: AnsiString;
	ahead, look: boolean;
begin
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');

	chap := stf(array_shift(r));
	oldChap := chap;
	page := sti(array_shift(r));
	if chap <= 0 then chap := 1;
	if page <= 0 then page := 1;
	ahead := false;
	if Cont then
		if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_PROGRE], id], ['c', 'p']) = 1 then begin
			chap := STI(f.Rows[0, 0]);
			page := STI(f.Rows[0, 1]);
			ahead := true;
		end;

	if Server.MangaData(id, manga) then begin
		look := Proc.ParamList['delta'] <> '';
		if look then begin
			ahead := sti(Proc.ParamList['delta']) > 0;
			chap := LookAhead(chap, ahead);
		end;

		if chap <= 0 then
			raise Exception.Create('Chapter ID not specified!');

		if Look and (oldChap = chap) then
			chap := chap + (Byte(ahead) * 2 - 1)
		else
		if (not LoadChapter(chap)) and Cont then begin
			oldChap := LookAhead(chap, ahead);
			if oldChap <> chap then
				if LoadChapter(oldChap) then begin
					chap := oldChap;
					oldChap := -1;
				end else begin
					oldChap := LookAhead(chap, not ahead);
					if oldChap <> chap then
						if LoadChapter(oldChap) then begin
							chap := oldChap;
							oldChap := -1;
						end else begin

						end
					else;
				end
			else begin
				oldChap := LookAhead(chap, not ahead);
				if LoadChapter(oldChap) then ;
			end;
		end;

		if abs(oldChap - chap) > 0.0001 then begin
			Proc.Redirect(Format('/reader/chapter/%d/%f.1/%f.1#page%d', [id, chap, last, page]));
			exit;
		end;
	end;

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

	if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_MANGAO], id], ['manhwa', 'orig']) = 1 then begin
		fMM := STB(f.Rows[0, 0]);
		fOS := STB(f.Rows[0, 0]);
	end else begin
		fMM := false;
		fOS := false;
	end;

	Proc.KeyData.Add('pages', e);
	Proc.KeyData.Add('id', its(id)) ;
	Proc.KeyData.Add('manga', '["' + join('", "', manga.mTitles) + '"]') ;
	Proc.KeyData.Add('jenres', '["' + join('", "', manga.mJenres) + '"]');
	Proc.KeyData.Add('chapter', fts(chap)) ;
	Proc.KeyData.Add('page', its(page)) ;
	Proc.KeyData.Add('manhwa', bts(ManhwaMode)) ;
	Proc.KeyData.Add('originalsize', bts(OriginalSize)) ;

	_cb_outtemlate(Proc.IOBuffer, 'chapter');

	SQLCommand('delete from progress where manga = %d', [id]);
	SQLCommand('insert into progress values (%d, %f4.1, %d)', [id, Chap, Page]);
	SQLCommand('delete from m_hist where manga = %d', [id]);
	SQLCommand('insert into m_hist values (%d, %d)', [id, UTCSecconds]);
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

	SQLCommand('delete from progress where manga = %d', [id]);
	SQLCommand('insert into progress values (%d, %d, %d)', [id, Chap, Page]);
	SQLCommand('delete from m_hist where manga = %d', [id]);
	SQLCommand('insert into m_hist values (%d, %d)', [id, i]);
	Server.ListModified;
	_cb_append(Proc.IOBuffer, '{res: "ok", manga: ' + its(id) + ', ts: ' + its(i) + '}');
end;

procedure TReader.serveTag(r: TStrings; Proc: PReqProcessor);
var
	id, jenre: Integer;
	jenreSet : Boolean;
	c : AnsiString;
	m : TManga;
	j : TJenres;
	jenreDesc: PJenreDesc;
	jenreTitle: AnsiString;
	addedJenre: PJenreDescB;
begin
	Proc.Formatter := nil;
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');
	jenre := sti(array_shift(r));
	if jenre <= 0 then
		raise Exception.Create('Jenre ID not specified!');

	jenreSet := sti(Proc.ParamList['set']) = 0;

	c := Format(SQL_DELETE + ' where (t.manga = %d) and (t.jenre = %d)', [TBL_NAMES[TBL_MJENRE], id, jenre]);
	if jenreSet then
		c := join(';', [c, Format(SQL_INSERT_II, [TBL_NAMES[TBL_MJENRE], id, jenre])]);

	if SQLCommand(c, []) <> DB_OK then
		_cb_append(Proc.IOBuffer, '{"error": "SQL command execution failed o_O"}')
	else begin
		Server.getJenres(j);
		jenreDesc := jd_hasJenre(@j, jenre);
		if jenreDesc <> nil then
			jenreTitle := jenreDesc.Jenre;

		Server.MangaData(id, m);
		addedJenre := ja_toggleJenre(m.mJIDS, jenre, jenreSet);
		if jenreSet then addedJenre.desc := jenreTitle;
		array_include(m.mJenres, jenreTitle, jenreSet);

		Server.SetMangaData(id, @m);
		_cb_append(Proc.IOBuffer, '{"manga": ' + its(id) + ', "jenre": ' + its(jenre) + ', "state": ' + its(Byte(jenreSet)) +'}');
		Server.ListModified;
	end;
end;

end.
