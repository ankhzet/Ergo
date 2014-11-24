unit c_server;
interface
uses
	c_webmodel
	, c_httpheaders
	, c_http
	, c_manga
	, c_jenres
	, sql_dbcommon
	, sql_constants
	, strings
	, c_interactive_lists
	;

type
	TReqServer  = class(TInterfacedObject, IServer)
	private
		fActual   : Integer;
		fSubCount : Integer;
		fSubCtls  : array of TClousureCtl;
		Sorted    : Boolean;
		ctlTTls   : THTTPHeaders;
		procedure   setSubCount(const Value: Integer);
		procedure   Sort;
		function    getCTL(Index: Integer): IPlugin;
		function    getCtlNamed(Name: PAnsiChar): IPlugin;
		procedure   AquireJenres;
	protected
		LogList   : TItemList;
		Mangas    : PIList;
		KnownJenres: TJenres;
		mangaNew, mangaFiltered: array of Boolean;
		fjenres, links: EDBFetch;
		progress: TTStrings;
		function    RegisterPlugin(Plugin: TClousureCtl): Integer;
		function    LogHdl(Msg: PAnsiChar): Boolean;
	public
		Titles    : TItemList;
		j_not     : TJenreFilter;
		j_yes     : TJenreFilter;
		Unfinished: Boolean;
		Modified  : Boolean;
		Modifying : Boolean;

		constructor Create; virtual;
		destructor  Destroy; override;
		function    LoadPlugins: Integer; virtual;
		procedure   ServeRequest(Proc: PReqProcessor);
		function    IndexOf(Ctl: PAnsiChar): Integer;

		function    Config(Key: PAnsiChar): PAnsiChar;
		procedure   ListModified;
		function    MangaData(ID: Integer; var Data: TManga): Boolean;
		function    SetMangaData(ID: Integer; Data: PManga): Boolean;
		procedure   AquireProgress(Manga: PManga);
		procedure   LoadMangaList;
		function    GetList: PIList;
		procedure   getFilters(out yes, no: TJenreFilter);
		procedure   setFilters(out yes, no: TJenreFilter);
		procedure   getJenres(out Jenres: TJenres);
		function    SQL(Query: AnsiString): Cardinal;
		function    Fetch(f: PDBFetch; SQL: AnsiString; Colls: array of AnsiString): Integer;
		procedure   Log(Msg: AnsiString; Params: array of const);
		function    FetchLog(FromId: Integer; ToId: Integer = 0): PAnsiChar;
		function    LogLines: Integer;
		procedure   Stop; virtual;

		property    Controllers: Integer read fSubCount write setSubCount;
		property    Ctl[Index: Integer]: IPlugin read getCTL; default;
		property    CtlNamed[Name: PAnsiChar]: IPlugin read getCtlNamed;
	end;



implementation
uses
	WinAPI
	, c_mimemagic
	, functions
	, c_buffers
	, file_sys
	, EMU_Types
	, opts
	, s_config
	, internettime
	;

{ TReqServer }

function HTML_Formatter(Output: AnsiString; Data: Cardinal): AnsiString;
var
	n, s: AnsiString;
begin
	n := AcceptInclude('index.tpl');
	if n <> '' then
		if ProcessTemplate(n, s) then begin
			with PReqProcessor(Data)^ do begin
				KeyData.Add('content', Output);
				result := TPLRE.ReplaceEx(s, KeyReplacer);
			end;
			exit;
		end;

	raise Exception.Create('<div id="message" class="error"><span><span>Template "%s" not found!</span></span></div>', [n])
end;

procedure TReqServer.ServeRequest(Proc: PReqProcessor);
var
	i, j: Integer;
	u, e: AnsiString;
	r, o: TStrings;
begin
	with Proc^ do begin
		Status := 200;
		ResHeaders.Add(HTTPHDR_CONTENT_TYPE, MIME_HTML_CODE);
		Formatter := HTML_Formatter;
		FmtData := Cardinal(Proc);

		try
			Proc.IOBuffer := nil;
			_cb_init(Proc.IOBuffer, Proc);
			try
				r := Explode('/', URI);
				if length(r) > 0 then begin
					if r[0] = '' then array_shift(r);
					i := IndexOf(@r[0, 1]);
					if i < 0 then
						u := 'index'
					else
						u := array_shift(r);
				end;
				i := IndexOf(@u[1]);

				if i >= 0 then begin
						with TClousureCtl(fSubCtls[i]), ParamList do
							for j := 0 to Count - 1 do
								with Header[j]^ do
									KeyData.Add('request[' + Name + ']', Value);

						if u = 'index' then u := '';

						j := length(r);
						e := '';
						if j > 0 then begin
							o := strSplit(#1, join(#1, r));
							while j > 0 do begin
								e := ctlTTls[u + join('', o)];
								if e <> '' then break;
								array_pop(o);
								dec(j);
							end;
						end;

						if e = '' then
							u := ctlTTls[u]
						else
							u := e;

					fSubCtls[i].Action(r, Proc);
					KeyData.Add('title', format(u, [KeyData['subtitle']]));
				end else
					Status := 404;
			finally
				_cb_end(Proc.IOBuffer);
			end;
		except
			Status := 500;
		end;
	end;
end;

function TReqServer.IndexOf(Ctl: PAnsiChar): Integer;
var
	l, h, c: Integer;
begin
	h := Controllers - 1;
	if h >= 0 then begin
		l := 0;
		if not Sorted then Sort;
		repeat
			result := (l + h) div 2;
			c := lstrcmpi(Ctl, fSubCtls[result].Name);
			if c = 0 then exit;
			if c > 0 then
				l := result + 1
			else
				h := result - 1;
		until l > h;
	end;
	result := -1;
end;

procedure TReqServer.setSubCount(const Value: Integer);
begin
	if fSubCount <> Value then begin
		fSubCount := (Value div 4 + Byte(Value mod 4 <> 0)) * 4;
		if fSubCount <> fActual then begin
			fActual := fSubCount;
			setLength(fSubCtls, fActual);
		end;
		Sorted := Value < 2;
		fSubCount := Value;
	end;
end;

procedure TReqServer.Sort;
var
	i: Integer;
	t: TClousureCtl;
begin
	repeat
		Sorted := true;
		for i := 0 to Controllers - 2 do
			if lstrcmpi(fSubCtls[i].Name, fSubCtls[i + 1].Name) > 0 then begin
				t := fSubCtls[i];
				fSubCtls[i] := fSubCtls[i + 1];
				fSubCtls[i + 1] := t;
				Sorted := false;
			end;
	until Sorted;
end;

function TReqServer.RegisterPlugin(Plugin: TClousureCtl): Integer;
begin
	result := IndexOf(plugin.Name);
	if result < 0 then begin
		result := Controllers;
		Controllers := result + 1;
		fSubCtls[result] := plugin;
	end;
	if fSubCtls[result] <> plugin then begin
		fSubCtls[result] := nil;
		fSubCtls[result] := plugin;
	end;
	fSubCtls[result].Server := Self;
end;

constructor TReqServer.Create;
var
	f, j : EDBFetch;
	i, id: Integer;
begin
	inherited;
	LogList := TItemList.Create;
	SetLogHandler(LogHdl);

	Controllers := 0;
	ctlTTls := THTTPHeaders.Create;
	if Fetch3(@f, SQL_SELECT, [TBL_NAMES[TBL_PAGES]], ['t.root', 't.title']) > 0 then
		for i := 0 to f.Count - 1 do
			ctlTTls.Add(f.Rows[i, 0], f.Rows[i, 1]);

	Titles := TItemList.Create;
	Mangas := _il_new;

	j_not := [];
	j_yes := [];
	for i := 0 to Fetch3(@j, SQL_SELECT, [TBL_NAMES[TBL_FILTER]], ['t.id', 't.include']) - 1 do begin
		id := STI(j.Rows[i, 0]);
		if STB(j.Rows[i, 1]) then Include(j_yes, id) else Include(j_not, id);
	end;

	AquireJenres;

	Modified := true;
	Modifying := false;
end;

procedure _rel_manga(Item: PILItem; Data: Pointer; var Continue: Boolean);
begin
	Dispose(PManga(Item.Data));
end;

destructor TReqServer.Destroy;
var
	i: Integer;
begin
	_il_free(mangas, _rel_manga);
	Titles.Free;

	ctlTTls.Free;
	for i := 0 to Controllers - 1 do
		fSubCtls[i] := nil;
	LogList.Free;
	inherited;
end;

function TReqServer.getCTL(Index: Integer): IPlugin;
begin
	result := fSubCtls[index];
end;

function TReqServer.getCtlNamed(Name: PAnsiChar): IPlugin;
var
	i : integer;
begin
	i := IndexOf(Name);
	if i >= 0 then
		result := fSubCtls[i]
	else
		result := nil;
end;

function TReqServer.LoadPlugins: Integer;
begin
	result := 0;
end;

function TReqServer.Config(Key: PAnsiChar): PAnsiChar;
begin
	result := PChar(s_config.Config[Key]);
end;

function TReqServer.MangaData(ID: Integer; var Data: TManga): Boolean;
var
	m: PILItem;
begin
	if _il_armor(Mangas) then
		try
			m := Mangas.Head;
			while m <> nil do begin
				if PManga(M.Data).mID = id then begin
					Data := PManga(M.Data)^;
					Data.mTitles := Explode('-:-', join('-:-', PManga(M.Data).mTitles));
					Data.mJenres := Explode('-:-', join('-:-', PManga(M.Data).mJenres));
					result := true;
					exit;
				end;
				m := m.Prev;
			end;
		finally
			_il_release(Mangas);
		end;
	result := false;
end;

function TReqServer.SetMangaData(ID: Integer; Data: PManga): Boolean;
var
	m: PILItem;
begin
	if _il_armor(Mangas) then
		try
			m := Mangas.Head;
			while m <> nil do begin
				if PManga(M.Data).mID = id then begin
					PManga(M.Data)^ := Data^;
					PManga(M.Data).mTitles := Explode('-:-', join('-:-', Data.mTitles));
					PManga(M.Data).mJenres := Explode('-:-', join('-:-', Data.mJenres));
					result := true;
					exit;
				end;
				m := m.Prev;
			end;
		finally
			_il_release(Mangas);
		end;
	result := false;
end;

procedure TReqServer.LoadMangaList;
	function ApplyFilters(mID: Integer): Boolean;
	var
		i, j, e: Integer;
	begin
		result := j_yes <> [];
		e  := 0;
		for i := 0 to fjenres.Count - 1 do
			if STI(fjenres.Rows[i, 0]) = mID then begin
				j := STI(fjenres.Rows[i, 1]);
				if j in j_not then begin
					result := false;
					exit;
				end;

				if result then inc(e, Byte(j in j_yes));
			end;

		result := (not result) or (e > 0);
	end;

var
	ttl: EDBFetch;
	p: PManga;
	t1, t2, t3: Cardinal;
	mIDs, readOrder, mangaOrder, orderedIDs: TInts;
	orderedMangas, unorderedMangas: Integer;
	orderOffset, totalMangas: Integer;
	i, j, mOrder, mID: Integer;
	mangaTitles: array of TStrings;
	mangaLinks: TStrings;
	title: AnsiString;

begin
	mIDs := nil;
	readOrder := nil;
	mangaOrder := nil;
	if Modifying or not Modified then exit;

	Modifying := true;
	t1 := GetTickCount;
	t2 := t1;

	progress.Pick(Format(SQL_SELECT, [TBL_NAMES[TBL_PROGRE]]), 'manga,c,p');

	Fetch3(@links, SQL_SELECT, [TBL_NAMES[TBL_LINKS]], ['t.manga', 't.link']);
	Fetch3(@ttl, 'select from `%s` t', [TBL_NAMES[TBL_TITLES]], ['t.manga', 't.title']);
	AquireJenres;

	mIDs := DBPick(format(SQL_SELECT, [TBL_NAMES[TBL_MANGA]]), 'id');
	totalMangas := Length(mIDs);

	readOrder := DBPick(format(SQL_SELECT, [TBL_NAMES[TBL_MHIST]]), 'manga', 'lastread reverse');
	mangaOrder:= flipInts(readOrder, orderOffset);
	orderedMangas := Length(readOrder);
	unorderedMangas := 0;

	setLength(mangaNew, totalMangas);
	setLength(mangaFiltered, totalMangas);
	setLength(mangaLinks, totalMangas);
	setLength(mangaTitles, totalMangas);
	setLength(orderedIDs, totalMangas);

	if totalMangas > 0 then begin
		t2 := GetTickCount;
		EMU_Log('LML: DBfetch took %d msec', [t2 - t1]);
		for i := 0 to totalMangas - 1 do begin
			mID := mIDs[i];
			mOrder := mangaOrder[mID - orderOffset];

			mangaNew[mOrder] := mOrder < 0;
			if mangaNew[mOrder] then begin
				mOrder := orderedMangas + unorderedMangas;
				inc(unorderedMangas);
			end;

			orderedIDs[mOrder] := mID;
			SetLength(mangaTitles[mOrder], 0);

			for j := 0 to ttl.Count - 1 do
				if sti(ttl.Rows[j, 0]) = mID then begin
					title := ttl.Rows[j, 1];
					if (Length(mangaTitles[mOrder]) = 0) or not isCyrylic(title) then
						array_push(mangaTitles[mOrder], title)
					else
						array_unshift(mangaTitles[mOrder], title);
				end;
			mangaFiltered[mOrder] := ApplyFilters(mID);
		end;
	end;
	t3 := GetTickCount;
	EMU_Log('LML: List fetch took %d msec', [t3 - t2]);
	totalMangas := orderedMangas + unorderedMangas;

	i := totalMangas;
	while i > 0 do begin
		dec(i);
		mID := orderedIDs[i];
		if mID <= 0 then continue;
		j := links.Count;
		mangaLinks[i] := '';
		while j > 0 do begin
			dec(j);
			if STI(links.Rows[j, 0]) = mID then begin
				mangaLinks[i] := links.Rows[j, 1];
				break;
			end;
		end;
		if mangaLinks[i] = '' then
			for j := 0 to length(mangaTitles[i]) - 1 do
				if not isCyrylic(mangaTitles[i][j]) then begin
					mangaLinks[i] := LowerCase(makepath(mangaTitles[i][j]));
					break;
				end;
	end;

	t2 := GetTickCount;
	EMU_Log('LML: List sort took %d msec', [t2 - t3]);

	if Mangas.Head <> nil then begin
		_il_armor(Mangas);
		try
			while Mangas.Head <> nil do
				_il_remove(Mangas, Mangas.Head, true);
		finally
			_il_release(Mangas);
		end;
	end;

	t3 := GetTickCount;
	EMU_Log('LML: List cleanup took %d msec', [t3 - t2]);

	i := totalMangas;
	while i > 0 do begin
		dec(i);
		mID := orderedIDs[i];
		if (mID <= 0) then continue;
		new(p);
		p.mID := mID;
		p.mTitles := mangaTitles[i];
		p.mNew := mangaNew[i];
		p.mLink := mangaLinks[i];
		p.Filtered := mangaFiltered[i];
		AquireProgress(p);
		p.pILItem := _il_append(Mangas, Cardinal(p));
	end;
	t2 := GetTickCount;
	EMU_Log('LML: List build took %d msec', [t2 - t3]);

	EMU_Log('LML: Total %d msec', [t2 - t1]);
	Modified := false;
	Modifying := false;
end;

function FindPreview(ID: Word; SubDir: AnsiString): AnsiString;
begin
	result := Format('%s\\previews\\%d.6', [OPT_DATADIR, id]);
	result := ExistFileWithExt(result, graphic_ext);
	if result = '' then begin
		result := Format('%s\\%s\\0001\\0001', [OPT_MANGADIR, SubDir]);
		result := ExistFileWithExt(result, graphic_ext);
	end;
end;

procedure TReqServer.AquireProgress(Manga: PManga);
var
	s, e: AnsiString;
	i, j, a, k, l: Integer;
	R: TSearchRec;
	nxt: Boolean;
	jr, jc, js: Boolean;

	jm: TInts;
begin

	for i := 0 to Length(Manga.mTitles) - 1 do begin
		e := Trim(Manga.mTitles[i]);
		if e = '' then continue;
		if Titles.IndexOf(e) < 0 then Titles.Add(e, Manga.mID);
	end;

	jr := false;
	jc := false;
	js := false;
	jm := DBPick(format(SQL_FETCHMANGA, [TBL_NAMES[TBL_MJENRE], Manga.mID]), 'jenre');
	j := Length(jm);
	if j > 0 then begin

		SetLength(Manga.mJenres, j);
		SetLength(Manga.mJIDS, j);
		i := 0;
		a := 0;
		while i < j do begin
			l := jm[i];

			case l of
			J_READED   : jr := true;
			J_COMPLETED: jc := true;
			J_SUSPENDED: js := true;
			end;

			nxt := false;
			for k := 0 to a - 1 do
				if Manga.mJIDS[k].id = l then begin
					inc(i);
					nxt := true;
					break;
				end;
			if nxt then continue;

			with KnownJenres.Data[l] do begin
				Manga.mJenres[a]   := Jenre;
				Manga.mJIDS[a].id  := l;
				Manga.mJIDS[a].desc:= Descr;
			end;
			inc(i);
			inc(a);
		end;
		SetLength(Manga.mJenres, a);
		SetLength(Manga.mJIDS, a);
	end;

	Manga.rReaded    := jr;
	Manga.mComplete  := jc;
	Manga.rSuspended := js;

	if manga.mLink = '' then
		for i := 0 to Length(manga.mTitles) - 1 do
			if not isCyrylic(manga.mTitles[i]) then
				manga.mLink := LowerCase(makepath(manga.mTitles[i]));

	Manga.mChaps := 0;
	if FileExists(Format('%s\\%s', [OPT_MANGADIR, Manga.mLink])) then
		s := Manga.mLink
	else
		s := ITS(Manga.mID, 0, 6);

	if Manga.pIcon = '' then
		Manga.pIcon := FindPreview(Manga.mID, s);

	Manga.rChapter := 0.0;
	Manga.pChapter := 0.0;
	Manga.pPage    := 1;
	a := Manga.mID;
	if length(progress.ValuesOf(a, 0)) > 0 then begin
		Manga.pChapter:= progress.IntOf(a, 0);// STF(progress[0][a][0]);
		Manga.pPage   := progress.IntOf(a, 1);//STI(progress[1][a][0]);
	end;
{	l := 0;
	h := progress.Count - 1;
	if h >= 0 then
		repeat
			i := (l + h) div 2;
			j := STI(progress.Rows[i, 0]);
			if a = j then begin
				Manga.rChapter2:= STF(progress.Rows[i, 1]);
				Manga.rPage    := STI(progress.Rows[i, 2]);
				break;
			end;
			if a > j then
				l := i + 1
			else
				h := i - 1;
		until l > h;  }

	if Manga.Filtered then begin
		a := 0;
		s := Format('%s\\%s', [OPT_MANGADIR, s]);
		if FindFirst(s + '\*', faAnyFile, R) = 0 then
			try
				repeat
					if R.Name[1] = '.' then continue;
					if Contains(@R.Name[1], SDIRS) then continue;
					if R.Attr and faDirectory <> 0 then begin
						inc(Manga.mChaps);
						Manga.rChapter := max(Manga.rChapter, stf(R.Name));
					end;
				until FindNext(R) <> 0;
			finally
				FindClose(R);
			end;

		if FindFirst(s + '\' + SD_ARCHIVE + '\*', faAnyFile, R) = 0 then
			try
				repeat
					if R.Attr and faDirectory <> 0 then continue;
					e := ExtractFileExt(R.Name);
					if Contains(@e[1], ARCHS) then  inc(a);
				until FindNext(R) <> 0;
			finally
				FindClose(R);
			end;
	end;

	jm := DBPick(Format(SQL_FETCHMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID]), 'archives');
	if Length(jm) > 0 then
		i := imax(jm[0], 0)
	else
		i := 0;

	Manga.mArchTotal := a;
	if i < a then
		Manga.mArchives := a - i
	else
		Manga.mArchives := 0;

	if Manga.mChaps > 0 then
		Manga.pChapter := min(Manga.pChapter, Manga.rChapter);

	if Unfinished and (Manga.rChapter >= Manga.mChaps) then
		_il_remove(Mangas, Manga.pILItem, true);
end;

procedure TReqServer.getFilters(out yes, no: TJenreFilter);
begin
	yes := j_yes;
	no := j_not;
end;

function TReqServer.GetList: PIList;
begin
	result := Mangas;
end;

procedure TReqServer.setFilters(out yes, no: TJenreFilter);
begin
	j_yes := yes;
	j_not := no;
end;

function TReqServer.SQL(Query: AnsiString): Cardinal;
begin
	result := SQLCommand(Query);
end;

function TReqServer.Fetch(f: PDBFetch; SQL: AnsiString; Colls: array of AnsiString): Integer;
begin
	result := Fetch3(f, SQL, [], Colls);
end;

procedure TReqServer.ListModified;
begin
	Modified := true;
end;

procedure TReqServer.Log(Msg: AnsiString; Params: array of const);
begin
	EMU_Log(Format(Msg, Params));
end;

procedure TReqServer.Stop;
begin

end;

function TReqServer.FetchLog(FromId, ToId: Integer): PAnsiChar;
var
	e: AnsiString;
begin
	e := '';
	if ToId <= 0 then ToId := LogList.Count;
	while FromId < ToId do begin
		e := join(#13#10, [e, format('[%s] %s', [DateTimeToStr(PDateTime(LogList.Data[FromId])^), LogList[FromId]])]);
		inc(FromId);
	end;
	result := PChar(e);
end;

function TReqServer.LogLines: Integer;
begin
	result := LogList.Count;
end;

function TReqServer.LogHdl(Msg: PAnsiChar): Boolean;
var
	p: PDateTime;
begin
	result := true;
	new(p);
	p^ := GetTime;
	LogList.Add(Msg, Cardinal(p));
end;

procedure TReqServer.AquireJenres;
var
	m: EDBFetch;
	i, id: Integer;
	jmJenres: TTStrings;
begin
	jmJenres.Pick(Format(SQL_SELECT, [TBL_NAMES[TBL_JENRES]]), 'id,name,descr', 'name');

	FillChar(KnownJenres, SizeOf(KnownJenres), 0);
	KnownJenres.Count := jmJenres.Entries;

	if jmJenres.Entries > 0 then
		for i := 0 to jmJenres.Entries - 1 do begin
			id := jmJenres.Hash[i];
			with KnownJenres.Data[id] do
				if not Valid then begin
					Jenre := jmJenres.ValuesOf(id, 0)[0];
					Descr := jmJenres.ValuesOf(id, 1)[0];//jmJenres[1][id - jmOffset][0];
					Mangas:= Fetch3(@m, SQL_SELECT + ' where t.jenre = %d', [TBL_NAMES[TBL_MJENRE], id], ['t.manga']);
					Valid := true;
				end;
		end;
end;

procedure TReqServer.getJenres(out Jenres: TJenres);
begin
	Jenres := KnownJenres;
end;

end.
