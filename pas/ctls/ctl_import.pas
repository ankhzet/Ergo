unit ctl_import;
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
	sql_constants,
	sql_dbcommon,
	fyzzycomp,
	regexpr;

type
	TImporter = class(TClousureCtl, IPlugin)
	private
		Mangas    : TItemList;
		Filtered  : TItemList;
		Translators:TItemList;

		procedure   Prepare;
		function    ChooseNearest(Pattern: AnsiString): AnsiString;
		function    makeNewPath(Original, MangaDir: AnsiString): AnsiString;
		procedure   DoImport(Path: AnsiString);
		procedure   ProcessSubDir(Path, Target, D: AnsiString);
	public
		constructor Create;
		destructor  Destroy; override;
		function    Name: PAnsiChar; override;
		function    ctlToID(Action: AnsiString): Integer; override;
		procedure   serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor); override;
		procedure   serveImport(r: TStrings; Proc: PReqProcessor);
		procedure   serveArchs(r: TStrings; Proc: PReqProcessor);
		procedure   serveArchive(r: TStrings; Proc: PReqProcessor);
	end;

implementation
uses
	regexp;

constructor TImporter.Create;
var
	f: EDBFetch;
	i: integer;
begin
	inherited;
	Mangas := TItemList.Create;
	Filtered := TItemList.Create;
	Translators := TItemList.Create;
	if Fetch3(@f, SQL_SELECT, [TBL_NAMES[TBL_TRANSL]], ['t.link']) > 0 then
		for i := 0 to f.Count - 1 do
			Translators.Add(LowerCase(ReplaceRegExpr('[^\w\d]+', f.Rows[i, 0], ' ')));
end;

destructor TImporter.Destroy;
begin
	Translators.Free;
	Filtered.Free;
	Mangas.Free;
	inherited;
end;

function TImporter.ctlToID(Action: AnsiString): Integer;
begin
	result := stringcase(@Action[1], [
		'index'
	, 'new'
	, 'archfix'
	, 'archive'
	]);
end;

function TImporter.Name: PAnsiChar;
begin
	result := 'import';
end;

procedure TImporter.serveAction(ID: Integer; r: TStrings; Proc: PReqProcessor);
var
	m, i: integer;
	manga: TManga;
begin
	_cb_new(Proc.IOBuffer, 0);
	try
		case ID of
			0: serveArchs(r, Proc);
			1: serveImport(r, Proc);
			2: begin //archfix
				Proc.Formatter := _JSON_Formatter;
				m := sti(array_shift(r));
				if m <= 0 then
					raise Exception.Create('Manga ID not specified!');
				if not Server.MangaData(m, manga) then
					raise Exception.Create('Aquire failed!');

				i := iMax(Manga.mArchTotal, 0);
				SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_ARCHS], m]);
				SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_ARCHS], m, i]);

				_cb_append(Proc.IOBuffer, '{"result": "ok", "archs": "' + its(i) + aaxx(i, ' архив', ['', 'а', 'ов']) + '"}');
				Server.AquireProgress(PManga(manga.pILItem.Data));
			end;
			3: serveArchive(r, Proc);
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
		while s^ in ['0'..'9'] do inc(s);
		if s^ in ['.', ','] then begin
			s^ := '.';
			inc(s);
			if s^ in ['0'..'9'] then
				while s^ in ['0'..'9'] do inc(s)
			else
				dec(s);
		end;
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

type
	TArray= array [0..999] of AnsiString;

procedure Sort(var a: TArray; c: Integer);
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

const
	exts: array [0..4] of AnsiString = ('jpg', 'jpeg', 'png', 'gif', 'bmp');
procedure TImporter.ProcessSubDir(Path, Target, D: AnsiString);
var
	c, n: Integer;
	u: Integer;
	a, r: TArray;
	j   : TArray;
	SR  : TSearchRec;
	S, e: AnsiString;
	t   : AnsiString;
	F   : File;
	procedure MoveToSpec(Spec: AnsiString; FileName: AnsiString);
	var
		i: Integer;
	begin
		i := 0;
		repeat
			inc(i);
			s := Format('%s%s\\%s-%s_%d0.2.%s', [path, Spec, target, ModuleFromFileName(FileName), i, ExtractFileExt(FileName)]);
		until not FileExists(s);
		Assign(F, D + '\' + FileName);
		{$I-}

		Rename(F, String(s));
		if IOResult <> 0 then
			Server.Log('Error: can''t rename [%s] to [%s]: already exists or same name...', [FileName, ExtractFileName(s)]);
		{$I+}
	end;
begin
	Server.Log('Process [%s]...', [ExtractFileName(D)]);
	c := 0;
	n := 0;
	u := 0;
	try
		if FindFirst(D + '\*', faFiles, SR) = 0 then
			repeat
				if SR.Attr and faDirectory = faDirectory then continue;

				t := LowerCase(SR.Name);
				e := ExtractFileExt(t);
				if not Contains(@e[1], graphic_ext) then begin
					j[u] := t;
					inc(u);
					Continue;
				end;

				if pos('credit', t) > 0 {re_match(@t[1], '^.*credit.*$')} then begin
					r[n] := SR.Name;
					inc(n);
					Continue;
				end;
				a[c] := SR.Name;
				inc(c);
			until FindNext(SR) <> 0
		else begin
			{$I-}
			RmDir(D);
			if IOResult <> 0 then
				Server.Log('Error: no files, remove failed.', [])
			else
				Server.Log('Error: no files, directory removed.', []);
			{$I+}
		end;
	finally
		FindClose(SR);
	end;

	if c > 1 then Sort(a, c);

	if c = 0 then begin
		try
			if FindFirst(D + '\*', faDirectory, SR) = 0 then
				repeat
					if SR.Name[1] = '.' then continue;
					if SR.Name = 'credits' then continue;
					if SR.Name = 'junk' then continue;
					if SR.Attr and faDirectory = 0 then
						MoveToSpec(SD_JUNK, SR.Name)
					else begin
						ProcessSubDir(path, Target, D + '\' + SR.Name);
						{$I-}
						RmDir(D + '\' + SR.Name);
						{$I+}
					end;
				until FindNext(SR) <> 0;
		finally
			FindClose(SR);
		end;
		exit;
	end;
	while c > 0 do begin
		dec(c);
		s := Format('%d0.4.%s', [c + 1, ExtractFileExt(a[c])]);
		Assign(F, D + '\' + a[c]);
		{$I-}
		Rename(F, String(Path + Target + '\' + s));
		if IOResult <> 0 then
			Server.Log('Error: can''t rename [%s] to [%s]: already exists or same name...', [a[c], s]);
		{$I+}
	end;

	while n > 0 do begin
		dec(n);
		MoveToSpec(SD_CREDITS, r[n]);
	end;
	while u > 0 do begin
		dec(u);
		MoveToSpec(SD_JUNK, j[u]);
	end;
end;

function SensetiveRename(PathA, PathB, DirName: AnsiString; out NewName: AnsiString): Integer;
const
	RE_PATT = '(((v(ol(ume)?)?)|(s(eason)?))(\d+(\.\d+)?)|(\[[^\]]*\]))';
var
	c, b: PAnsiChar;
	Chapter: Single;
	f: file;
begin
	result := -1;

	NewName := ReplaceRegExpr(RE_PATT, LowerCase(DirName), '');

	NewName := StringReplace(NewName, 'extra', '.5', true);
	c := @NewName[1];
	while not ((c^ = #0) or (c^ in ['0'..'9'])) do inc(c);
	if c^ = #0 then exit;

	b := c;
	while c^ in ['0'..'9'] do inc(c);
	if c^ in ['.', ',', '~'] then begin
		c^ := '.';
		inc(c);
		while c^ in ['0'..'9'] do inc(c);
	end;

	NewName := copy(b, 1, Cardinal(c) - Cardinal(b));
	Chapter := STF(NewName);
	if trunc(frac(Chapter) * 10) = 0 then
		NewName := Format('%d.4', [trunc(Chapter)])
	else
		NewName := Format('%f6.1', [Chapter]);

	Assign(F, patha + DirName);
	{$I-}
		Rename(F, pathb + NewName);
		result := IOResult;
	{$I+}
end;

procedure TImporter.DoImport(Path: AnsiString);
var
	c, r: Integer;
	a: TArray;
	s: AnsiString;
	SR: TSearchRec;
begin
	if path[Length(path)] <> '\' then path := path + '\';
	if pos(':', path) = 0 then path := OPT_MANGADIR + path;
	{$I-}
	for r := 0 to Length(SDIRS) - 1 do
		if not FileExists(path + SDIRS[r]) then
			MkDir(PChar(path + SDIRS[r]));

	{$I+}

	c := 0;
		try
			if FindFirst(path + SD_ARCHIVE + '\*', faDirectory, SR) = 0 then
				repeat
					if SR.Name[1] = '.' then continue;
					if SR.Attr and faDirectory = 0 then continue;

					r := SensetiveRename(path + SD_ARCHIVE + '\', path, SR.Name, s);
					if r in [0, 2, 145] then begin
						a[c] := s;
						inc(c);
					end else
						Server.Log('Error: can''t rename [%s] to [%s]: dir exists or same name...', [SD_ARCHIVE + '\' + SR.Name, s]);

				until FindNext(SR) <> 0
			else begin
				Server.Log('Archive subdirectory: no subdirectories.', []);
			end;
		finally
			FindClose(SR);
		end;

	if c > 1 then Sort(a, c);

	while c > 0 do begin
		dec(c);
		ProcessSubDir(path, a[c], path + a[c]);
	end;
	Server.Log(' -- done...', []);
end;

procedure TImporter.serveImport(r: TStrings; Proc: PReqProcessor);
var
	id: Integer;
	manga: TManga;
	function getChaps: Integer;
	var
		s: AnsiString;
		R: TSearchRec;
	begin
		result := 0;
		s := Format('%s\\%s', [OPT_MANGADIR, Manga.mLink]);
		if FindFirst(s + '\*', faDirectory, R) = 0 then
			try
				repeat
					if R.Name[1] = '.' then continue;
					if Contains(@R.Name[1], SDIRS) then continue;
					if R.Attr and faDirectory <> 0 then inc(result);
				until FindNext(R) <> 0;
			finally
				FindClose(R);
			end;
	end;
var
	i, j, k: Integer;
	f: eDBFetch;
	path: AnsiString;
begin
	id := sti(array_shift(r));
	if id <= 0 then
		raise Exception.Create('Manga ID not specified!');

	if not Server.MangaData(id, manga) then
		exit;

	path := Format('%s\\%s', [OPT_MANGADIR, Manga.mLink]);

	Proc.Formatter := nil;

	j := getChaps;
	try
		DoImport(path);
	except
		Server.Log('CTL::Reader ::serveImport DoImport failed', []);
	end;
	i := getChaps - j;
	_cb_append(Proc.IOBuffer, '{"err": 0, "imported": "' + its(i) + '"}');
	if i > 0 then begin
		if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID], ['t.archives']) > 0 then
			k := STI(f.Rows[0, 0])
		else
			k := 0;
		j := iMin(Manga.mArchTotal, i + k);
		if j > 0 then begin
			SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID]);
			SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_ARCHS], Manga.mID, j])
		end;
		Server.ListModified;
	end;
end;

function FindFolder(Root: String; var Folder: String): Boolean;
var
	l: Integer;
begin
	result := true;
	Root := LowerCase(Root);
	repeat
		l := Length(Folder);
		if l = 0 then exit;

		if Folder[l] in ['\', '/'] then delete(Folder, l, 1);
		if FileExists(Folder) then exit;
		Folder := ExtractFileDir(Folder);
	until Root = LowerCase(Folder);

	result := false;
end;

function TImporter.ChooseNearest(Pattern: AnsiString): AnsiString;
var
	i: Integer;
	j: Integer;
	S: TStats;
	t: String;
	procedure Sort(List: TItemList);
	var
		i: Integer;
		t: AnsiString;
		c: Cardinal;
		s: Boolean;
	begin
		repeat
			s := true;
			for i := 0 to List.Count - 2 do
				if lstrcmpi(PChar(List[i]), PChar(List[i + 1])) < 0 then begin
					t := List[i];
					List[i] := List[i + 1];
					List[i + 1] := t;

					c := List.Data[i];
					List.Data[i] := List.Data[i + 1];
					List.Data[i + 1] := c;

					s := False;
				end;
		until s;
	end;
begin
	result := '';

	if Mangas.Count <= 0 then exit;

	t := Trim(ExtractFileName(Pattern));
	j := -1;
	if t <> '' then begin
		i := Mangas.Add(t);

		j := FyzzyAnalyze(Mangas, i, 1, S);

		Mangas.Delete(i);
	end;

	Filtered.Count := 0;

	if t <> '' then begin
		for i := 0 to Mangas.Count - 1 do
			if S[i].R > 0 then begin
				t := FTS(S[i].R, 0, 3) + ' | ' + Mangas[i];//Format('%f.3 | %s', [S[i].R, Mangas[i]]);
				Filtered.Add(t);
				if j = i then
					result := t;
			end;
		Sort(Filtered);
	end;

	if Filtered.Count = 0 then
		for i := 0 to Mangas.Count - 1 do
			Filtered.Add(Mangas[i]);
end;

var
	SavePatt  : AnsiString = '{%root%}\{%manga%}\archives\{%file%}';

function clearfix(s: AnsiString): AnsiString;
var
	j: Integer;
begin
	result := s;
	j := pos('|', result);
	if j > 0 then
		delete(result, 1, j + 1);
end;

function TImporter.makeNewPath(Original, MangaDir: String): AnsiString;
begin
	result := ReplaceRegExpr('{%root%}', SavePatt, OPT_MANGADIR);
	result := ReplaceRegExpr('{%manga%}', result, MangaDir);
	result := ReplaceRegExpr('{%file%}' , result, ExtractFileName(Original));
end;

procedure TImporter.Prepare;
	procedure SearchDirs(Dir: String);
	var
		R: TSearchRec;
	begin
		if FindFirst(Dir + '\*', faDirectory, R) = 0 then
			repeat
				if R.Name[1] = '.' then continue;
				if R.Attr and faDirectory = 0 then continue;
				Mangas.Add(R.Name);
			until FindNext(R) <> 0;
	end;
begin
	SavePatt := Server.Config('savepattern.manga');

	Mangas.Count := 0;
	SearchDirs(OPT_MANGADIR);
end;

procedure TImporter.serveArchs(r: TStrings; Proc: PReqProcessor);
type
	TOrigin = record
		Source: TStrings;
		Origin: AnsiString;
		List  : TItemList;
	end;
	TOrigins= array [0..512] of TOrigin;
var
	i, j, k: Integer;
	sr: TSearchRec;
	s, c, mm, mi,
	e, f,
	t1, t2, t3, t4,
	look, z, z1,
	_cfixed: AnsiString;
	o: TOrigins;
	oc: Integer;
	re: TRegExpr;
	t: PAnsiChar;
	dbf: EDBFetch;
	tm1, tm2, tm3, tm4: Cardinal;
	function haso(origin: AnsiString): Integer;
	begin
		result := oc;
		while result > 0 do begin
			dec(result);
			if origin = o[result].Origin then exit;
		end;
		result := -1;
	end;
begin
	if Proc.ParamList['action'] = 'delete' then begin
		t1 := trim(Proc.ParamList['dir']);
		if t1 <> '' then
			SQLCommand(SQL_DELETE + ' where t.`directory` = "%s"', [TBL_NAMES[TBL_IMPORTS], escapeslashes(t1)]);
		Proc.Redirect('/import');
		exit;
	end;

	if Proc.ParamList['action'] = 'add' then begin
		t1 := trim(Proc.ParamList['dir']);
		if t1 <> '' then
			SQLCommand(SQL_INSERT_IS, [TBL_NAMES[TBL_IMPORTS], 0, escapeslashes(t1)]);
		Proc.Redirect('/import');
		exit;
	end;

	Prepare;

	oc := 0;
	s := '';
	e := '';
		tm2 := GetTickCount;
		tm4 := 0;
	if Fetch3(@dbf, SQL_SELECT, [TBL_NAMES[TBL_IMPORTS]], ['t.directory']) > 0 then begin
		t2 := '';

		re := TRegExpr.Create;
		t3 := join('|', explode(#13#10, Translators.Text));
		t3 := '(' + ReplaceRegExpr('[^\w\d\|]', t3, '.?') + ')';
		if t3 = '()' then t3 := '';
		re.Expression := join('|', ['(\[[^\]]+\]','\{[^\}]+\}','(vo?l?|ch?|tom.?|glava.?)\d+(\.\d+)*)','(  )+', t3]);
		re.ModifierStr := 'isr';

		try
			for i := 0 to dbf.Count - 1 do begin
				look := dbf.Rows[i, 0];
				Server.Log('Fetching [%s]...', [look]);
				tm1 := GetTickCount;

				if FindFirst(look + '\*', faAnyFile, SR) = 0 then
					repeat
						if sr.Attr and faDirectory <> 0 then continue;
						f := SR.Name;
						c := '.' +ExtractFileExt(f);
						j := pos(LowerCase(c), '.rar.zip.tar.tg.7z.arj.cab');
						if j = 0 then continue;
						delete(f, pos(c, f), maxint);
						t := @f[1];
						while t^ <> #0 do begin
							if (t^ = '-') or (t^ = '_') then t^ := ' ';
							inc(t);
						end;
						f := trim(re.Replace(f, ''));

						tm3 := GetTickCount;
						c := clearfix(ChooseNearest(f));
						inc(tm4, GetTickCount - tm3);
						k := haso(c);
						if k < 0 then begin
							k := oc;
							o[k].Origin := c;
							o[k].List := TItemList.Create;
							o[k].Source := nil;
							inc(oc);
						end;
						array_push(o[k].Source, look + '\' + SR.Name);
						with o[k].List do
							for j := 0 to Filtered.Count - 1 do begin
								_cfixed := clearfix(Filtered[j]);
								if IndexOf(_cfixed) < 0 then
									Add(_cfixed);
							end;

					until FindNext(SR) <> 0;

				Server.Log('Time taken: %dmsec...', [GetTickCount - tm1]);

				if t2 <> ' 'then
					t2 := t2 + '</li>'#13#10'<li>';
				t2 := t2 + '<a class="del pull left" href="/import?action=delete&dir=' + urlencode(look) + '"></a> &nbsp;' + look;
			end;
		finally
			re.Free;
		end;

		mm := '';

		for j := 0 to Mangas.Count - 1 do
			mm := mm + ', "' + urlencode(Mangas[j]) + '"';

		Fetch3(@dbf, SQL_SELECT, [TBL_NAMES[TBL_LINKS]], ['t.manga', 't.link']);

		t4 := '';
		z := '';
		mi := '';
		for i := 0 to oc - 1 do
			with o[i] do begin
				t1 := '';
				for j := 0 to Length(Source) - 1 do
					t1 := join('", "', [t1, urlencode(UTF8Encode(Source[j]))]);

				if e <> '' then e := e + ','#13#10'	';
				e := e + '["' + t1 + '"]';

				if t4 <> '' then t4 := t4 + ', ';
				t4 := t4 + '"' + strsafe(Origin) + '"';

				z1 := '';
				for j := 0 to List.Count - 1 do
					z1 := join(', ', [z1, its(Mangas.IndexOf(List[j]) + 1)]);

				z := join(', ', [z, '[' + z1 + ']']);

				z1 := '-1';
				for j := 0 to dbf.Count - 1 do
					if lstrcmpi(@dbf.Rows[j, 1][1], @Origin[1]) = 0 then begin
						z1 := dbf.Rows[j, 0];
						break;
					end;
				mi := join(', ', [mi, z1]);

				List.Free;
			end;
	end else
		t2 := 'none yet.';

				Server.Log('Total time to fetch: %dmsec (%dmsec for ::ChooseNearest())...', [GetTickCount - tm2, tm4]);

	Proc.KeyData.Add('fileslist', e);
	Proc.KeyData.Add('matches', z);
	Proc.KeyData.Add('mangas', mm);
	Proc.KeyData.Add('mangaids', mi);
	Proc.KeyData.Add('dirs', t2);
	Proc.KeyData.Add('origins', t4);
	_cb_outtemlate(Proc.IOBuffer, 'importarchs');
end;

procedure TImporter.serveArchive(r: TStrings; Proc: PReqProcessor);
var
	src, dst: AnsiString;
begin
	Proc.Formatter := _JSON_Formatter;
	src := trim(Proc.ParamList['source']);
	dst := makeNewPath(src, trim(Proc.ParamList['target']));

	if FileExists(dst) then
		raise Exception.Create(strsafe(dst + '\nFile exists'))
//		if Replace then
//			DeleteFile(PChar(dst))
//		else
//			if MessageBox(Handle, 'Файл существует, заменить?', '', MB_YESNO) <> ID_YES then
//				exit
//			else
//				DeleteFile(NewPath);
	else
//		raise Exception.Create(strsafe(src + '\nFile don''t exists'));
	;
	if MoveFile(PChar(src), PChar(dst)) then begin
		_cb_append(Proc.IOBuffer, '{"result": "ok", "msg": ""}');
		Server.ListModified;
	end else
		raise Exception.Create(strsafe(src + '\n' + SysErrorMessage(GetLastError)));
end;

end.
