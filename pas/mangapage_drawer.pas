unit mangapage_drawer;
interface
uses
		WinAPI
	, s_config
	, plate_drawer
	, vcl_button
	, page_drawer
	;

type
	TMangaPage   = class(TPage)
	private
		res        : TConfigNode;
		Updateble  : Boolean;
		Button     : TButton;
		procedure    UpdateInfo;
		procedure    AquireInfo;
		procedure    CheckUpdates(Sender: TObject);
		function     getManga: PPlate;
	public
		constructor  Create(Reader: TReader); override;
		procedure    InitSB; override;
		destructor   Destroy; override;
		procedure    DoClick(X, Y: Integer; B: TMsgButton); override;
		procedure    NavigateTo(From: TRPages); override;
		function     Action(UID: Cardinal): Boolean; override;
		procedure    Draw; override;
		property     Manga: PPlate read getManga;
	end;

implementation
uses
		strings
	, functions
	, file_sys
	, regexp
	, logs
	, sql_constants
	, chapter_drawer
	, opts
	, WinAPI_GDIRenderer
	, sevenzip
	;
{ TMangaPage }

procedure TMangaPage.AquireInfo;
var
	b: TButton;
	src, upd: Integer;
	ssrc, t : AnsiString;
	link    : AnsiString;
	i, j, k : Integer;
	l, n    : Integer;
	descr   : AnsiString;
	f       : TDBFetch;
	nxt     : Boolean;
begin
//	Updateble := true;
	src := 0;
	upd := 0;
	descr := '';
	ssrc  := 'server';
	link  := '';
	if f.Fetch(SQL_FETCHIDL, ['manga', Manga.mID], ['t.src', 't.update']) = 1 then begin
		src := f.Int[0];
		upd := f.Int[1];
		if f.Fetch(SQL_FETCHMANGA, ['titles', Manga.mID], ['t.title']) > 0 then begin
			j := f.Count;
			SetLength(Manga.mTitles, j);
			i := 0;
			while i < j do begin
				Manga.mTitles[i] := DecodeHTMLTags(f.Rows[i, 0]);
				inc(i);
			end;
		end;

		if f.Fetch('select from `%s` j, `%s` m where (m.manga = %d) and (m.jenre = j.id)', ['jenres', 'm_jenres', Manga.mID], ['j.id', 'j.name', 'j.descr']) > 0 then begin
			j := f.Count;
			SetLength(Manga.mJenres, j);
			SetLength(Manga.mJIDS, j);
			i := 0;
			n := 0;
			while i < j do begin
				l := STI(f.Rows[i, 0]);
				nxt := false;
				for k := 0 to n - 1 do
					if Manga.mJIDS[k].id = l then begin
						inc(i);
						nxt := true;
						break;
					end;
				if nxt then continue;
				if l = J_COMPLETED then begin
					Updateble := false;
					if Button <> nil then FreeAndNil(Button);
				end;
				Manga.mJenres[n] := DecodeHTMLTags(f.Rows[i, 1]);
				Manga.mJIDS[n].id  := l;
				Manga.mJIDS[n].desc:= DecodeHTMLTags(f.Rows[i, 2]);
				inc(i);
				inc(n);
			end;
			SetLength(Manga.mJenres, n);
			SetLength(Manga.mJIDS, n);
		end;

		if f.Fetch(SQL_FETCHMANGAL, ['descrs', Manga.mID], ['t.content']) = 1 then descr := DecodeHTMLTags(f[0]);
		if f.Fetch(SQL_FETCHIDL   , ['sources', src], ['t.name']) = 1 then ssrc := f[0];
		if f.Fetch(SQL_FETCHMANGAL, ['links', Manga.mID], ['t.link']) = 1 then link := f[0];
		if f.Fetch(SQL_FETCHMANGAL, [TBL_NAMES[TBL_STATES], Manga.mID], ['t.complete', 't.readed']) = 1 then begin
			SC_STATES[SB_COMPL]  := Cardinal(f.Bool[0]);
			SC_STATES[SB_READED] := Cardinal(f.Bool[1]);
		end else begin
			SC_STATES[SB_COMPL]  := 0;
			SC_STATES[SB_READED] := 0;
		end;
		SC_STATES[SB_SUSP] := Byte(f.Fetch(SQL_FETCHMANGA + ' and (t.jenre = %d)', [TBL_NAMES[TBL_MJENRE], Manga.mID, J_SUSPENDED], ['t.manga']) = 1);
	end;

	Manga.mStatus := upd;
	Manga.mServer := ssrc;
	Manga.mSrc    := src;
	Manga.mLink   := link;
	Manga.mDescr  := descr;
	if Manga.pIcon = nil then
		Manga.pIcon := LoadPreview(Manga.mID, Manga.mLink);
{	if Updateble then begin
		b := TButton.Create(Reader);
		b.Left := 3;
		b.Top  := PV_HEIGHT + RD_TOPPLANE + 3;
		b.Height := 20;
		b.Width := 200;
		b.Caption := 'Проверить обновления';
		b.OnClick := CheckUpdates;
		Button := b;
	end;   }
	Reader.Invalidate;
end;

procedure TMangaPage.CheckUpdates(Sender: TObject);
begin
//	Reader.Sync.Sync(Manga.mID);
end;

constructor TMangaPage.Create(Reader: TReader);
begin
	inherited;
	res := TConfigNode.Create('');
	Button := nil;
end;

destructor TMangaPage.Destroy;
begin
	res.Free;
	inherited;
end;

procedure TMangaPage.DoClick(X, Y: Integer; B: TMsgButton);
begin
//	Reader.ActivePage := rp_chapter;
end;

{procedure DT(DC: HDC; T: AnsiString; X, Y, X2, Y2, F: Integer);
var
	R: TRect;
begin
	R.Left := X;
	R.Top := Y;
	R.Right := X2;
	R.Bottom := Y2;
	DrawText(DC, @T[1], Length(T), R, F);
end;  }

procedure TMangaPage.Draw;
var
	DC: HDC;
	i, y: Integer;
	procedure GroupBox(X, Y, W, H: Integer; C, S: AnsiString);
	var
		R: TRect;
	begin

		Canvas.SetBrush(GetStockObject(NULL_BRUSH));
		Canvas.SetPen(GetStockObject(BLACK_PEN));
		inc(Y, RD_TOPPLANE);
		Canvas.RoundRect(X + 2, y + 5, X + W - 2, Y + H - 2, 2, 2);

		if C <> '' then begin
			R.Left := X + 10;
			R.Top := Y - 1;
			R.Right := X + W - 10;
			R.Bottom := Y + 16;
			DrawText(DC, @C[1], Length(C), R, DT_CALCRECT);
			Canvas.SetBrush(BG);
			Canvas.SetPen(GetStockObject(NULL_PEN));
			Canvas.Rectangle(R.Left - 1, R.Top, R.Right + 1, R.Bottom);
			DrawText(DC, @C[1], Length(C), R, DT_LEFT or DT_TOP);
		end;

		R.Left := X + 10;
		R.Top := Y + 12;
		R.Right := X + W - 10;
		R.Bottom := Y + H - 8;
		DrawText(DC, @S[1], Length(S), R, DT_LEFT or DT_TOP or DT_WORDBREAK);
	end;
begin
	if Manga = nil then exit;
	DC := Canvas.DC;
	i := Length(Manga.mTitles) * 12 + 18;
	y := PV_HEIGHT - i;

{$IFDEF FATRTL}
	if Manga.pIcon <> nil then
		with Manga.pIcon do
			WinAPI_GDIRenderer.Canvas.DrawBitmap(Manga.pIcon.Handle, 4, RD_TOPPLANE + 7, Width, Height, PV_WIDTH - 8, PV_HEIGHT - 11);
{$ENDIF}
	GroupBox(       0, 0, PV_WIDTH, PV_HEIGHT, 'Превью: ', '');
	GroupBox(PV_WIDTH, 0, Width - PV_WIDTH, i, 'Название: ', strJoin(#13#10, Manga.mTitles));
	GroupBox(PV_WIDTH, i, Width - PV_WIDTH, y, 'Теги: ', strJoin(', ', Manga.mJenres));
	i := PV_HEIGHT;
//	if Updateble then inc(i, 25);
	GroupBox(       0, i, Width, Height - RD_TOPPLANE - i, 'Описание: ', Manga.mDescr);
end;

procedure TMangaPage.InitSB;
begin
	Reader.AddSB(SB_VIEW  , al_top, al_last);
	Reader.AddSB(SB_EXPLOR, al_top, al_last);
	Reader.AddSB(SB_IMPORT, al_top, al_last);
//	Reader.AddSB(SB_UPD   , al_top, al_last);
	Reader.AddSB(SB_READED, al_top, al_last);
	Reader.AddSB(SB_SUSP  , al_top, al_last);
	Reader.AddSB(SB_COMPL , al_top, al_last);
end;

procedure TMangaPage.UpdateInfo;
var
	i, id, j: Integer;
	link, s : AnsiString;
	m, t : TConfigNode;
	f    : TDBFetch;
begin
	id := Manga.mID;
	ll_Write('-- retriving #%d.3 "%s"', [id, Manga.mTitles[0]]);

	i := 0;
	if Request('{a=updates;d=' + its(id) + ';}', res) then begin
		i := res.Int['d'];
		if f.Fetch('select from manga m where (m.id = %d) and (m.update = %d) limit 1;', [id, i], ['m.id']) = 0 then
			i := 0
		else
			ll_Write('-- up to date...', []);
	end;

	if i = 0 then
	if Request('{a=manga;d=' + its(id) + ';}', res) then begin
		m := TConfigNode(res.Find('d').Childs);

		SQLCommand(SQL_DELETEID   , ['manga', id]);
		SQLCommand(SQL_DELETEMANGA, ['links', id]);
		SQLCommand(SQL_DELETEMANGA, ['titles', id]);
		SQLCommand(SQL_DELETEMANGA, ['m_jenres', id]);
		SQLCommand(SQL_DELETEMANGA, ['descrs', id]);

		SQLCommand('insert into `%s` values (%d, %d, 1);', ['manga', id, m.Int['src']]);
		SQLCommand('insert into `%s` values (%d, 0, 0);', [TBL_NAMES[TBL_STATES], id]);
		SQLCommand(SQL_INSERT_IS, ['links', id, m['link']]);

		t := TConfigNode(m.Find('alts').Childs);
		while t <> nil do begin
			if t.Name <> '#' then
				for s in Explode(#13#10, t.Name) do
					if Trim(s) <> '' then
						SQLCommand(SQL_INSERT_IS, ['titles', id, Trim(s)]);
			t := TConfigNode(t.Next);
		end;
		t := TConfigNode(m.Find('jenr').Childs);
//		l_Write(m.Find('jenr').ToString());
		while t <> nil do begin
			if t.Name <> '#' then
				for s in Explode(#13#10, t.Name) do
					if f.Fetch('select from jenres j where j.name = "%s" limit 1;', [Trim(s)], ['j.id']) = 1 then
						SQLCommand(SQL_INSERT_II, ['m_jenres', id, f.Int[0]])
					else begin
						i := f.Fetch('select from jenres j', ['id']);
						if i > 0 then begin
							j := STI(f.Rows[i - 1][0]) - 1;
							repeat
								inc(j);
								i := f.Fetch('select from jenres j where j.id > %d', [j], ['id']);
							until i <= 0;
							inc(j);
						end else
							j := 1;
						SQLCommand(SQL_INSERT_ISS, ['jenres', j, Trim(s), Trim(s)]);
						SQLCommand(SQL_INSERT_II, ['m_jenres', id, j])
					end;

			t := TConfigNode(t.Next);
		end;

		SQLCommand(SQL_INSERT_IS, ['descrs', id, m['desc']]);
		ll_Write('-- updated...', []);
	end;
end;

function TMangaPage.getManga: PPlate;
begin
	result := @Reader.Plates.Data[Reader.Selected];
end;

procedure TMangaPage.NavigateTo(From: TRPages);
begin
	Title := Manga.mTitles[0];
	if Manga.mStatus = 0 then UpdateInfo;
	AquireInfo;
end;

function Greater(A, B: AnsiString): Boolean;
var
	p1, p2, p3: PAnsiChar;
	i1, i2: Single;
begin
	p1 := PAnsiChar(UpperCase(A));
	p2 := PAnsiChar(UpperCase(B));
	while p1^ <> #0 do begin
		if (p1^ in ['0'..'9']) and (p2^ in ['0'..'9']) then begin
			i1 := 0;
			i2 := 0;
			p3 := p1;
			while p1^ in ['0'..'9'] do inc(p1);
			if p1^ = ',' then p1^ := '.';
			if p1^ = '.' then begin
				inc(p1);
				while p1^ in ['0'..'9'] do inc(p1);
			end;
			i1 := STF(copy(p3, 0, Cardinal(p1) - Cardinal(p3)));

			p3 := p2;
			while p2^ in ['0'..'9'] do inc(p2);
			if p2^ = ',' then p2^ := '.';
			if p2^ = '.' then begin
				inc(p2);
				while p2^ in ['0'..'9'] do inc(p2);
			end;
			i2 := STF(copy(p3, 0, Cardinal(p2) - Cardinal(p3)));
			if abs(i1 - i2) > 0.00001 then exit(i1 > i2);
		end else
			if p1^ = p2^ then begin
				inc(p1);
				inc(p2);
			end else
				exit(p1^ > p2^);

	end;
	result := false;
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
procedure ProcessSubDir(Path, Target, D: AnsiString);
var
	c, n: Integer;
	i, u: Integer;
	a, r: TArray;
	j   : TArray;
	SR  : TSearchRec;
	S, e: AnsiString;
	t   : AnsiString;
	b   : boolean;
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
			ll_write('Error: can''t rename [%s] to [%s]: already exists or same name...', [FileName, ExtractFileName(s)]);
		{$I+}
	end;
begin
	ll_write('Process [%s]...', [ExtractFileName(D)]);
	c := 0;
	n := 0;
	u := 0;
	try
		if FindFirst(D + '\*', faFiles, SR) = 0 then
			repeat
				t := LowerCase(SR.Name);
				b := false;
				e := ExtractFileExt(t);
				for s in exts do
					if s = e then begin
						b := true;
						break;
					end;
				if not b then begin
					j[u] := t;
					inc(u);
					Continue;
				end;
				if re_match(@t[1], '^.*credit.*$') then begin
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
				ll_write('Error: no files, remove failed.')
			else
				ll_write('Error: no files, directory removed.');
			{$I+}
		end;
	finally
		FindClose(SR);
	end;

	if c > 1 then Sort(a, c) else begin
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
			ll_write('Error: can''t rename [%s] to [%s]: already exists or same name...', [a[c], s]);
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

procedure DoImport(Path: AnsiString);
var
	c, r: Integer;
	a: TArray;
	s: AnsiString;
	SR: TSearchRec;
	F: File;
begin
	if path[Length(path)] <> '\' then path := path + '\';
	if pos(':', path) = 0 then path := OPT_MANGADIR + path;
	for s in SDIRS do
		if not FileExists(path + s) then MkDir(path + s);

	try
		if FindFirst(path + SD_ARCHIVE + '\*', faDirectory, SR) = 0 then
			repeat
				if SR.Name[1] = '.' then continue;
				if SR.Attr and faDirectory = 0 then continue;
				Assign(F, path + SD_ARCHIVE + '\' + SR.Name);
				{$I-}
				Rename(F, String(path + SR.Name));
				if IOResult <> 0 then
					ll_write('Error: can''t rename [%s] to [%s]: dir exists or same name...', [SD_ARCHIVE + '\' + SR.Name, SR.Name]);
				{$I+}
			until FindNext(SR) <> 0
		else begin
			ll_write('Archive subdirectory: no subdirectories.');
		end;
	finally
		FindClose(SR);
	end;

	c := 0;
	try
		if FindFirst(path + '*', faDirectory, SR) = 0 then
			repeat
				if SR.Name[1] = '.' then continue;
				if Contains(@SR.Name[1], SDIRS) then continue;
				if SR.Attr and faDirectory = 0 then continue;
				a[c] := SR.Name;
				inc(c);
			until FindNext(SR) <> 0
		else begin
			ll_write('Error: no subdirectories.');
			exit;
		end;
	finally
		FindClose(SR);
	end;

	if c > 1 then Sort(a, c);
	while c > 0 do begin
		dec(c);
		s := ITS(c + 1, 0, SIZE_CHPNAME);
		if a[c] = s then continue;
		Assign(F, path + a[c]);
		{$I-}
		Rename(F, String(path + s));
		r := IOResult;
		if not (r in [0, 2, 145]) then begin
			ll_write('Error: can''t rename [%s] to [%s]: dir exists or same name: %s...', [a[c], s, SysErrorMessage(r)]);
			exit;
		end;
		{$I+}
		ProcessSubDir(path, s, path + s);
	end;
	ll_write(' -- done...');
end;

function TMangaPage.Action(UID: Cardinal): Boolean;
var
	l: AnsiString;
	f: TDBFetch;
	i, j, k: Cardinal;
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
begin
	result := true;
	case UID of
		SB_FIXARC: begin
			j := iMax(Manga.mArchTotal, 0);
			SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID]);
			SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_ARCHS], Manga.mID, j])
		end;
		SB_IMPORT: begin
			j := getChaps;
			DoImport(Format('%s\\%s', [OPT_MANGADIR, Manga.mLink]));
			i := getChaps - j;
			if i > 0 then begin
				if f.Fetch(SQL_FETCHMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID], ['t.archives']) > 0 then
					k := f.Int[0]
				else
					k := 0;
				j := iMin(Manga.mArchTotal, i + k);
				if j > 0 then begin
					SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_ARCHS], Manga.mID]);
					SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_ARCHS], Manga.mID, j])
				end;
			end;
		end;
		SB_CLOSE: begin
			i := Manga.mID;
			Reader.ActivePage := rp_home;
			Reader.Selected := Reader.Plates.Order[Reader.Plates.IndexOf(i)];
		end;
		SB_VIEW : begin
			TChapterPage(Reader.Pages[rp_chapter]).Init(Manga.mID, false);
			Reader.ActivePage := rp_chapter;
		end;
		SB_UPD  : begin
			if f.Fetch('select from `%s` m, `%s` l where (m.id = %d) and (l.manga = m.id) limit 1',
				['manga', 'links', Manga.mID],
				['m.src', 'l.link']
			) = 1 then begin
				Request('{a=load;d{link="' + f[1] + '";src=' + f[0] + ';all=true;};};', res);
			end else
				ll_Write('-- wtf? oO Can''t resolve manga SRC and LINK');

			SQLCommand(SQL_DELETEID, [TBL_NAMES[TBL_MANGA], manga.mID]);
			SQLCommand('insert into `%s` values (%d, %d, 0);', [TBL_NAMES[TBL_MANGA], manga.mID, manga.mSrc]);
			UpdateInfo;
			AquireInfo;
		end;
		SB_COMPL, SB_READED: begin
			i := 0;
			j := 0;
			if f.Fetch(SQL_FETCHMANGAL,
				[TBL_NAMES[TBL_STATES], Manga.mID],
				['t.complete', 't.readed']
			) = 1 then begin
				i := Cardinal(f.Bool[0]);
				j := Cardinal(f.Bool[1]);
			end;
			if UID = SB_COMPL then begin
				if i <> 0 then i := 0 else i := 1;
				if i = 0 then j := 0;
			end else begin
				if j <> 0 then j := 0 else j := 1;
				if j = 1 then i := 1;
			end;

			SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_STATES], manga.mID]);
			SQLCommand(SQL_INSERT + ' (%d, %d, %d);', [TBL_NAMES[TBL_STATES], manga.mID, i, j ]);

			SQLCommand(SQL_DELETEMANGA + ' and ((t.jenre = %d) or (t.jenre = %d))', [TBL_NAMES[TBL_MJENRE], manga.mID, J_READED, J_COMPLETED]);
			if j <> 0 then SQLCommand(SQL_INSERT + ' (%d, %d);', [TBL_NAMES[TBL_MJENRE], manga.mID, J_READED]);
			if i <> 0 then SQLCommand(SQL_INSERT + ' (%d, %d);', [TBL_NAMES[TBL_MJENRE], manga.mID, J_COMPLETED]);
			SC_STATES[SB_COMPL]  := i;
			SC_STATES[SB_READED] := j;
			AquireInfo;
		end;
		SB_SUSP: begin
			SQLCommand(SQL_DELETEMANGA + ' and (t.jenre = %d)', [TBL_NAMES[TBL_MJENRE], manga.mID, J_SUSPENDED]);
			if SC_STATES[SB_SUSP] = 1 then
				SQLCommand(SQL_INSERT + ' (%d, %d);', [TBL_NAMES[TBL_MJENRE], manga.mID, J_SUSPENDED]);
			AquireInfo;
		end;
		SB_EXPLOR: begin
			l := Format('%s\\%s', [OPT_MANGADIR, Manga.mLink]);
			if not FileExists(l) then MkDir(l);
			l := l + '\archives';
			if not FileExists(l) then MkDir(l);
			l := 'explorer.exe "' + l + '"';
			WinExec(@l[1], SW_SHOWNORMAL)
		end;
		else result := false;
	end;
end;

end.
