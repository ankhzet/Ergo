unit homepage_drawer;
interface
uses
		WinAPI
	, strings
	, vcl_control
	, vcl_messages
	, vcl_edit
	, page_drawer
	, plate_drawer
	, sql_constants
	, s_config
	, threads
	;

type
	TFilters     = (f_jenres, f_status);
	TFilter      = set of TFilters;
	TJenreFilter = set of Byte;
	TJenres      = record
		Count      : Integer;
		Data       : array [Byte] of record
			Valid    : Boolean;
			Jenre    : AnsiString;
			Descr    : AnsiString;
			Mangas   : Integer;
		end;
	end;

	THomePage    = class;
	TMangaAquirer= class(TThread)
	private
		fReader    : TReader;
		fHomePage  : THomePage;
	public
		sel        : Integer;
		constructor Create(Reader: TReader; HomePage: THomePage);
		procedure   Execute; override;
		property    Reader: TReader read fReader;
		property    HomePage: THomePage read fHomePage;
	end;

	THomePage    = class(TPage)
	private
		fScrollY   : Integer;
		dScroll    : TPoint;
		fScrollX   : Integer;
		fScrollable: Integer;
		eFilter    : TEdit;
		Titles     : TItemList;
		j_not      : TJenreFilter;
		j_yes      : TJenreFilter;
		Unfinished : Boolean;
		jenres     : TJenres;
		fFilterPanel:Boolean;
		HoverID    : Integer;
		BYES, BNOT : HBRUSH;
		b1, b3     : HBRUSH;
		procedure    UpdateScrolls;
		procedure    MakeTitle;
		procedure    ApplyTitleFilter(Filter: AnsiString);
		procedure    setFP(const Value: Boolean);
	protected
		procedure    DoClick(X, Y: Integer; B: TMsgButton); override;
		procedure    DoDown(X, Y: Integer; B: TMsgButton); override;
		procedure    DoUp(X, Y: Integer; B: TMsgButton); override;
		procedure    DoMove(X, Y: Integer); override;
		procedure    OnKey(var M: TWMKey); override;
		procedure    InitSB; override;
		procedure    EChanged(Sender: TObject);
		function     MXToChB(X, Y: Integer): Integer;
		procedure    StopAquirer;
	public
		Aquirer    : TMangaAquirer;
		constructor  Create(Reader: TReader); override;
		destructor   Destroy; override;
		procedure    Draw; override;
		procedure    LoadMangaList(Node: TConfigNode);
		procedure    NavigateTo(From: TRPages); override;
		procedure    NavigateFrom(Show: TRPages); override;
		function     Action(UID: Cardinal): Boolean; override;
		procedure    Size(W, H: Integer); override;
		procedure    CacheUpdated; override;
		procedure    ScrollInView;
		property     ScrollX: Integer read fScrollX;
		property     ScrollY: Integer read fScrollY;
		property     ScrollableRegion: Integer read fScrollable;
		property     FilterPanel: Boolean read fFilterPanel write setFP;
	end;

implementation
uses
		functions
	, file_sys
	, s_engine
	, opts
	, fyzzycomp
//	, regexp
	, WinAPI_GDIRenderer
	;

{ THomePage }

constructor THomePage.Create(Reader: TReader);
begin
	Aquirer := nil;
	Titles := TItemList.Create;
	inherited;
	j_not  := [];
	j_yes  := [];
	BYES := CreateSolidBrush($00FF00);
	BNOT := CreateSolidBrush($0000FF);
	b1 := GetStockObject(GRAY_BRUSH);
	b3 := GetStockObject(WHITE_BRUSH);
end;

destructor THomePage.Destroy;
begin
	DeleteObject(BYES);
	DeleteObject(BNOT);
	Titles.Free;
	inherited;
end;

procedure THomePage.StopAquirer;
begin
	if Aquirer = nil then exit;
	try
		Aquirer.Terminate;
		Aquirer.WaitFor;
		Aquirer.Free;
	except
	end;
	Aquirer := nil;
end;

procedure THomePage.CacheUpdated;
begin
	StopAquirer;
	Aquirer := TMangaAquirer.Create(Reader, Self);
end;

procedure THomePage.Draw;
var
	dx, dy, w, dw, i, j, n, k: Integer;
	b2, b4: HBRUSH;
	procedure PrintCheckBox(DC: HDC; Caption: AnsiString);
	begin
		Canvas.PlateOut(dx, dy + 2, dx + 12, dy + CHBHEIGHT - 2, 1, b2, b4);
		Canvas.TextOut(Caption, dx + 14, dy, dx + w - 4, dy + CHBHEIGHT, DT_SINGLELINE or DT_VCENTER);
	end;
begin
	if not FilterPanel then begin
		Reader.Plates.Draw(ScrollY, RD_TOPPLANE + 1, Width, Reader.Height - RD_TOPPLANE);
		exit;
	end;
	with Reader, Canvas do begin
		Canvas.PlateOut(3, -5, Width - 3, Height - 3, 1, b1, b3);

		Canvas.TextColor := 0;
		Canvas.RTF.RenderText('[RGB:0]{[RGB:00FF00]Показать}/{[RGB:0000FF]исключить} по тегам:', 10, RD_TOPPLANE + 5, Width - 20, CHBHEIGHT);
		w := Width - 20;
		dw:= (w div CHBWIDTH) + byte(w div CHBWIDTH = 0);
		w := round(w / dw);
		j := 0;
		i := 0;
		n := Jenres.Count;
		dx := 10;
		dy := RD_TOPPLANE + 20;
		k := 0;
		while k < n do begin
			inc(i);
			if not Jenres.Data[i].Valid then continue;
			inc(k);
			if HoverID = i then
				b2 := b1
			else
				b2 := b3;
			b4 := b3;
			if i in j_not then b4 := BNOT;
			if i in j_yes then b4 := BYES;
			with Jenres.Data[i] do PrintCheckBox(DC, Jenre + ' (' + ITS(Mangas) + ')');

			inc(j);
			if j >= dw then begin
				j := 0;
				dx := 10;
				inc(dy, CHBHEIGHT);
			end else
				inc(dx, w);
			if dy > Height - 5 - CHBHEIGHT then break;
		end;

		dx := 10;
		w := Width - 20;
		inc(dy, CHBHEIGHT * (2 - Byte(j = 0)));

		if -HoverID = 1 then
			b2 := b1
		else
			b2 := b3;
		b4 := b3;
		if Unfinished then b4 := BYES;
		PrintCheckBox(DC, 'Показать только недочитанные');
	end;

end;

function THomePage.MXToChB(X, Y: Integer): Integer;
var
	w, dw, dy, i, j, row, rows, col: Integer;
	b: Boolean;
begin
	result := 0;
	dy := RD_TOPPLANE + 20;
	if (Y < dy) or (X < 10) or (X > Width - 10) then exit;

	w := Width - 20;
	dw:= (w div CHBWIDTH) + byte(w div CHBWIDTH = 0);
	w := round(w / dw);
	i := Jenres.Count;

	rows := Ceil(i / dw);
	row := Ceil((Y - dy) / CHBHEIGHT) - 1;
	col := trunc((X - 10) / w);
	b := row > rows;
	if b then begin
		dec(row, rows);
		result := - row;
	end else begin
		result := row * dw + col + 1;
		j := result;
		result := 0;
		w := 0;
		while w < j do begin
			inc(result);
			if jenres.Data[result].Valid then
				inc(w);
		end;
	end;
end;

const
	FILTER_WIDTH = 1;

procedure THomePage.ApplyTitleFilter(Filter: AnsiString);
var
	i, j, k: Integer;
	ID: Cardinal;
	index: Integer;
	t: AnsiString;
	r: TStats;
	P: PPlates;
	f: Boolean;
begin
//	Reader.WantRender := true;
	P := @Reader.Plates;
	f := Length(Filter) <= FILTER_WIDTH + 1;
	for i := 0 to P.Count - 1 do P.Data[i].fFiltered := f;
	if f then exit;

	j := Titles.Add(Filter, Reader.Selected);
	try
		i := FyzzyAnalyze(Titles, j, FILTER_WIDTH, r);
		if i >= 0 then i := Titles.Data[i];
		t := '';
		k := Titles.Count;
		while k > 0 do begin
			dec(k);
			if k = j then continue;
			if R[k].R > 0 then begin
				ID := Titles.Data[k];
				i  := ID;
				index := P.IndexOf(ID);
				P.Data[P.Order[index]].fFiltered := true;
			end;
		end;
		if i >= 0 then Reader.Selected := i;
	finally
		Titles.Delete(j);
	end;
end;

procedure THomePage.EChanged(Sender: TObject);
begin
	ApplyTitleFilter(TEdit(Sender).Caption);
end;

procedure THomePage.InitSB;
begin
//	Reader.AddSB(SB_FIND  , al_top, al_first);
	Reader.AddSB(SB_REGIST, al_top, al_first);
//	Reader.AddSB(SB_RSS, al_top, al_first);
	Reader.AddSB(SB_NEXT  , al_top, al_last);
	Reader.AddSB(SB_PVIEW , al_top, al_last);
	Reader.AddSB(SB_FILTER, al_top, al_last);
	FilterPanel := false;

	eFilter := TEdit.Create(Reader);
	with eFilter do begin
		Left := Reader.fc * RD_SBGAIN + 10;
		Top := 1;
		Width := RD_FILTERWD;
		Height := RD_TOPPLANE - 5;
//		Focused := true;
		OnChange := EChanged;
	end;
end;

procedure THomePage.MakeTitle;
begin
	if (Reader.Selected >= 0) and (Reader.Selected < Reader.Plates.Count) then
		Title := '[ ' + Reader.Plates.Data[Reader.Selected].mTitles[0] + ' ]'
	else
		Title := 'Выбор манги (' + ITS(Reader.Plates.Count) + ' наименований)';
end;

var
	s: array [0..1023] of AnsiString;
	l: array [0..1023] of AnsiString;
	e: array [0..1023] of word;
	d: array [0..1023] of integer;
	u: array [0..1023] of Boolean;
	_f: array [0..1023] of Boolean;

procedure THomePage.LoadMangaList(Node: TConfigNode);
const
	FilterBy: TFilter = [f_jenres];
var
	c, j, n, k: integer;
	i: TString;
	g: AnsiString;
	f, jenres, states, links: TDBFetch;
	b: Boolean;
	r: TConfigNode;
	function ApplyFilters(R: PRowFetch): Boolean;
	var
		i, j, e, id: Integer;
	begin
		result := j_yes <> [];
		id := STI(R^[0]);
		e  := 0;
		for i := 0 to jenres.Count - 1 do
			if STI(jenres.Rows[i, 0]) = id then begin
				j := STI(jenres.Rows[i, 1]);
				if j in j_not then exit(false);
				if result then inc(e, Byte(j in j_yes));
			end;

		result := (not result) or (e > 0);
	end;

	function has(id: integer): integer;
	begin
		result := n;
		while result > 0 do begin
			dec(result);
			if d[result] = id then exit;
		end;
		result := -1;
	end;
begin
	n := 0;
	jenres.Fetch(SQL_SELECT, [TBL_NAMES[TBL_MJENRE]], ['t.manga', 't.jenre']);
	states.Fetch(SQL_SELECT, [TBL_NAMES[TBL_STATES]], ['t.manga', 't.complete', 't.readed']);
	links.Fetch(SQL_SELECT, [TBL_NAMES[TBL_LINKS]], ['t.manga', 't.link']);
	if f.Fetch('select from `%s` m, `%s` t, `%s` h where (t.manga = m.id) and (m.id = h.manga) order by h.lastread reverse;', [
//	if f.Fetch('select from `%s` m, `%s` t where t.manga = m.id;', [
			TBL_NAMES[TBL_MANGA]
		, TBL_NAMES[TBL_TITLES]
		, TBL_NAMES[TBL_MHIST]
	] , ['m.id', 't.title']) > 0 then begin
		for c := 0 to f.Count - 1 do begin
			j := sti(f.Rows[c, 0]);
			k := has(j);
			g := DecodeHTMLTags(f.Rows[c, 1]);
			if k < 0 then begin
				d[n] := j;
				s[n] := g;
				u[n] := false;
				e[n] := n;
			 _f[n] := ApplyFilters(@F.Rows[c]);
				inc(n);
			end else
				if (not isCyrylic(s[k])) and isCyrylic(g) then
					s[k] := strJoin(#13, [g, s[k]])
				else
					s[k] := strJoin(#13, [s[k], g]);
		end;
	end;
	r := TConfigNode.Create('');
	try
		if Request('{a=list;}', r) then begin
			i := TString(r.List['d'].Childs);
			while i <> nil do begin
				j := STI(i.Name);
				if has(j) < 0 then begin
					d[n] := j;
					s[n] := DecodeHTMLTags(i.Value);
					u[n] := true;
					e[n] := n;
				 _f[n] := j_yes = [];
					inc(n);
				end;
				i := TString(i.Next);
			end;
		end;
	finally
		r.Free;
	end;

{	repeat
		b := true;
		c := n;
		while c > 1 do begin
			dec(c);
			if d[e[c - 1]] < d[e[c]] then begin
				j := e[c];
				e[c] := e[c - 1];
				e[c - 1] := j;
				b := false;
			end;
		end;
	until b; }

	c := n;
	while c > 0 do begin
		dec(c);
		k := d[c];
		j := links.Count;
		while j > 0 do begin
			dec(j);
			if STI(links.Rows[j, 0]) = k then begin
				l[c] := links.Rows[j, 1];
				break;
			end;
		end;
	end;

	Node.RemoveChilds;
	while n > 0 do begin
		dec(n);
		c := e[n];
		if not _f[c] then continue;
		r := TConfigNode(Node.AddParam(TConfigNode, ITS(d[c])));
		TString(r.AddParam(TString, 'alts')).Value := s[c];
		TString(r.AddParam(TString, 'new')).Value := BTS(u[c]);
		TString(r.AddParam(TString, 'link')).Value := l[c];
//		lbSrvCachedManga.Items.AddObject(Format('%s%s', [news[u[c]], s[c]]), Pointer(d[c]));
	end;
end;

procedure THomePage.NavigateFrom(Show: TRPages);
begin
	StopAquirer;
end;

procedure THomePage.NavigateTo(From: TRPages);
var
	i, id: Integer;
	j, m: TDBFetch;
begin
	MakeTitle;
	FillChar(jenres, SizeOf(Jenres), 0);
	if j.Fetch(SQL_SELECT, [TBL_NAMES[TBL_JENRES]], ['t.id', 't.name', 't.descr']) > 0 then begin
		for i := 0 to j.Count - 1 do begin
			id := STI(j.Rows[i, 0]);
			with jenres.Data[id] do
				if not Valid then begin
					Jenre := j.Rows[i, 1];
					Descr := j.Rows[i, 2];
					Mangas:= m.Fetch(SQL_SELECT + ' where t.jenre = %d', [TBL_NAMES[TBL_MJENRE], id], ['t.manga']);
					Valid := true;
					inc(Jenres.Count);
				end;
		end;
	end;
	j_not := [];
	j_yes := [];
	for i := 0 to j.Fetch(SQL_SELECT, [TBL_NAMES[TBL_FILTER]], ['t.id', 't.include']) - 1 do begin
		id := STI(j.Rows[i, 0]);
		if STB(j.Rows[i, 1]) then Include(j_yes, id) else Include(j_not, id);
	end;
end;

function THomePage.Action(UID: Cardinal): Boolean;
var
	b: Byte;
begin
	result := true;
	case UID of
		SB_CLOSE : begin
			if FilterPanel then begin
				SC_STATES[SB_FILTER] := 0;
				Action(SB_FILTER);
			end else
				Reader.Perform(WM_CLOSE, 0, 0);
		end;
		SB_NEXT  : if Reader.Selected >= 0 then Reader.ActivePage := rp_manga;
		SB_FIND  : Reader.ActivePage := rp_search;
		SB_REGIST: Reader.ActivePage := rp_import;
		SB_PVIEW : begin
			OPT_PREVIEWS := SC_STATES[SB_PVIEW] <> 0;
			CacheUpdated;
		end;
		SB_FILTER: begin
			FilterPanel := SC_STATES[SB_FILTER] <> 0;
			if not FilterPanel then begin
				SQLCommand(SQL_DELETE, [TBL_NAMES[TBL_FILTER]]);
				for b in j_not do SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_FILTER], b, 0]);
				for b in j_yes do SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_FILTER], b, 1]);
				CacheUpdated;
				Reader.Selected := 0;
			end;
		end;
		else result := false;
	end;
end;

procedure THomePage.ScrollInView;
var
	i, j, k, l: Integer;
begin
	i := Reader.Selected;
	l := Reader.Plates.PlatesInRow;
	with Reader.Plates do begin
		if (TopID + PlatesInRow) > i then begin
			dec(fScrollY, ceil((TopID - i) / l + 1) * RD_PLATEHEIGHT);
			TopID    := imax(0, i - 1);
		end;
		fScrollY := imax(0, fScrollY);
		k := Self.Height - RD_TOPPLANE;
		k := (k div RD_PLATEHEIGHT - Byte(k mod RD_PLATEHEIGHT = 0)) * l;  // plates in view
		if TopID + k <= i then begin
			inc(fScrollY, ceil((i - (TopID + k + 1)) / l) * RD_PLATEHEIGHT);
			TopID    := imax(0, i - k - 1);
		end;
		fScrollY := imin(imax(0, fScrollY), fScrollable);
	end;
//	Reader.WantRender := true;
end;

procedure THomePage.setFP(const Value: Boolean);
begin
	if fFilterPanel <> Value then begin
		fFilterPanel := Value;
		SC_STATES[SB_FILTER] := Cardinal(Value);
	end;
end;

procedure THomePage.Size(W, H: Integer);
begin
	inherited;
	UpdateScrolls;
end;

procedure THomePage.UpdateScrolls;
begin
	fScrollable := imax(0, Reader.Plates.Height - Height + RD_TOPPLANE) + 1;
	fScrollY    := imin(imax(fScrollY, 0), fScrollable);//, imax(Plates.Height - HeightAvailable, 0));
end;

procedure THomePage.OnKey(var M: TWMChar);
var
	i, k, l: Integer;
begin
	if FilterPanel then exit;
	k := Reader.Plates.PlatesInRow;
	l := Reader.Plates.Count - 1;
	i := imax(imin(Reader.Selected, l), 0);
	Reader.Selected := i;
	case M.CharCode of
		VK_UP   : dec(i, k);
		VK_DOWN : inc(i, k);
		VK_LEFT : dec(i);
		VK_RIGHT: inc(i);
		else exit;
	end;
	i := imax(imin(i, l), 0);
	if (i = Reader.Selected) or (i >= Reader.Plates.Count) then exit;
	Reader.Selected := i;
	MakeTitle;
end;

procedure THomePage.DoDown(X, Y: Integer; B: TMsgButton);
var
	M: TWMChar;
begin
	if FilterPanel then exit;
	if b = b_wheel then begin
		M.CharCode := VK_DOWN;
		OnKey(M);
		exit;
	end;
	dScroll.X := ScrollX;
	dScroll.Y := ScrollY;
end;

procedure THomePage.DoUp(X, Y: Integer; B: TMsgButton);
var
	M: TWMChar;
begin
	if FilterPanel then exit;
	if b = b_wheel then begin
		M.CharCode := VK_UP;
		OnKey(M);
		exit;
	end;
end;

procedure THomePage.DoClick(X, Y: Integer; B: TMsgButton);
var
	i, k, s: Integer;
	procedure Toggle(ID: Integer; var J: TJenreFilter); inline;
	begin
		if ID in J then Exclude(J, ID) else Include(J, ID);
	end;
begin
	if FilterPanel then begin
		i := MXToChB(X, Y);
		if i <= 0 then
			case - i of
				1: Unfinished := not Unfinished;
				else
			end
		else begin
			if i in j_yes then begin
				Toggle(i, j_yes);
				Toggle(i, j_not);
			end else
				if i in j_not then
					Toggle(i, j_not)
				else
					Toggle(i, j_yes);
		end;
		exit;
	end;
	if (Y < RD_TOPPLANE) then exit;
	i := Reader.Plates.TopID;
	inc(Y, ScrollY - RD_TOPPLANE - 1);

	k := Reader.Plates.PlatesInRow;
	i := (Y div RD_PLATEHEIGHT) * k;
	inc(i, X div round(Width / k));
	if i < Reader.Plates.Count then
		s := i
	else
		s := -1;

	if s >= 0 then begin
		i := Y mod RD_PLATEHEIGHT;
		if (i > RD_PLATEHEIGHT - 22) and (i < RD_PLATEHEIGHT - 6) then begin
			i := round(Width / k);
			x := x mod i;
			dec(x, i - 18 * RD_SPEEDBUTS - 9);
			if x < 0 then
				i := -1
			else
				if x mod 18 > 15 then
					i := -1
				else
					i := RD_SPEEDBUTS - x div 18 - 1;
		end else
			i := -1;
		Reader.Plates.SBID := i;
		if i >= 0 then begin
			Reader.Selected := s;
			Reader.Action(Reader.Plates._sb_act[i]);
			exit;
		end;
	end;

	if s <> Reader.Selected then begin
		Reader.Selected := s;
		MakeTitle;
	end else
		if (s >= 0) then
			case b of
				b_left : Reader.ActivePage := rp_manga;
				b_right: CacheUpdated;
			end;
end;

procedure THomePage.DoMove(X, Y: Integer);
var
	i, k, s: Integer;
begin
	if FilterPanel then begin
		HoverID := MXToChB(X, Y);
		exit;
	end;
	if bDrag[b_left] then begin
		fScrollX := dScroll.X - (X - dPos[b_left].X);
		fScrollY := dScroll.Y - (Y - dPos[b_left].Y);
		UpdateScrolls;
	end else
	if not FilterPanel then begin
		if Y < RD_TOPPLANE then exit;
		i := Reader.Plates.TopID;
		inc(Y, ScrollY - RD_TOPPLANE - 1);

		k := imax(Reader.Plates.PlatesInRow, 1);
		i := (Y div RD_PLATEHEIGHT) * k;
		inc(i, X div round(Width / k));
		if i < Reader.Plates.Count then
			s := i
		else
			s := -1;

		if s >= 0 then begin
			i := Y mod RD_PLATEHEIGHT;
			if (i > RD_PLATEHEIGHT - 22) and (i < RD_PLATEHEIGHT - 6) then begin
				i := round(Width / k);
				x := x mod i;
				dec(x, i - 18 * RD_SPEEDBUTS - 9);
				if x < 0 then
					i := -1
				else
					if x mod 18 > 15 then
						i := -1
					else
						i := RD_SPEEDBUTS - x div 18 - 1;
			end else
				i := -1;
			if i >= 0 then
				Reader.Hint := SB_HINT[Reader.Plates._sb_act[i]];
			Reader.Plates.SBID := i;
		end;
		Reader.Plates.HoverID := s;
	end;
end;

{ TMangaAquirer }

constructor TMangaAquirer.Create(Reader: TReader; HomePage: THomePage);
begin
	inherited Create(true);
	fReader := Reader;
	fHomePage := HomePage;
	Resume;
end;

procedure TMangaAquirer.Execute;
var
	c: TConfigNode;
	i, j, k, u: Integer;
	_s, _p: TDBFetch;
	procedure AquireProgress(N: PPlate);
	var
		s, e: AnsiString;
		f: TDBFetch;
		i, a: Integer;
		b: Boolean;
		R: TSearchRec;
	begin
		for s in N.mTitles do begin
			e := Trim(S);
			if e = '' then continue;
			if HomePage.Titles.IndexOf(e) < 0 then HomePage.Titles.Add(e, N.mID);
		end;

		N.mChaps := 0;
		if FileExists(Format('%s\\%s', [OPT_MANGADIR, N.mLink])) then
			s := n.mLink
		else
			s := ITS(N.mID, 0, 6);
//		N.mLink := s;
		a := 0;
		s := Format('%s\\%s', [OPT_MANGADIR, s]);
		if FindFirst(s + '\*', faAnyFile, R) = 0 then
			try
				repeat
					if R.Name[1] = '.' then continue;
					if Contains(@R.Name[1], SDIRS) then continue;
					if R.Attr and faDirectory <> 0 then inc(N.mChaps);
				until FindNext(R) <> 0;
			finally
				FindClose(R);
			end;

		if N.pIcon = nil then
			N.pIcon := LoadPreview(N.mID, s);

		b := false;
		for i := 0 to _s.Count - 1 do
			if STI(_s.Rows[i, 0]) = N.mID then begin
				N.rChapter := STI(_s.Rows[i, 1]);
				N.rPage    := STI(_s.Rows[i, 2]);
				b := true;
				break;
			end;
		if not b then begin
			N.rChapter := 1;
			N.rPage    := 1;
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

		if f.Fetch(SQL_FETCHMANGAL, [TBL_NAMES[TBL_ARCHS], n.mID], ['t.archives']) > 0 then
			i := imax(f.Int[0], 0)
		else
			i := 0;

		n.mArchTotal := a;
		if i < a then
			n.mArchives := a - i
		else
			n.mArchives := 0;


		b := false;
		for i := 0 to _p.Count - 1 do
			if STI(_p.Rows[i, 0]) = N.mID then begin
				N.mComplete := STB(_p.Rows[i, 1]);
				N.rReaded   := STB(_p.Rows[i, 2]);
				b := true;
				break;
			end;
		if not b then begin
			N.mComplete := false;
			N.rReaded   := false;
		end;

		N.rChapter := imin(N.rChapter, N.mChaps);
		if HomePage.Unfinished and (N.rChapter >= N.mChaps) then
			Reader.Plates.Delete(N.mID);
		N.pUpdating := false;
	end;
	procedure Reord(var Current: Integer; Optimal: Integer);
	var
		t: TPlate;
		i: Integer;
	begin
		with Reader.Plates do begin
			i := Order[Current];
			t := Data[i];
			while i < Optimal do begin
				Data[i] := Data[i + 1];
				inc(i);
			end;
			while i > Optimal do begin
				Data[i] := Data[i - 1];
				dec(i);
			end;
			Data[i] := t;
			Sorted := false;
			Current := IndexOf(t.mID);
		end;
	end;
var
	mids: array [0..1023] of Integer;
	ords: array [0..1023] of Integer;
begin
	sel := Reader.Selected;
	if sel >= 0 then sel := Reader.Plates.Data[sel].mID;

	HomePage.LoadMangaList(Reader.List);
	_s.Fetch(SQL_SELECT, [TBL_NAMES[TBL_PROGRE]], ['manga', 'c', 'p']);
	_p.Fetch(SQL_SELECT, [TBL_NAMES[TBL_STATES]], ['manga', 'complete', 'readed']);
	Reader.WaitRenderSync;
	with Reader.Plates do begin
		mids[0] := Count;
		for i := 1 to Count do begin
			mids[i] := Data[i - 1].mid;
			Data[i - 1].pUpdating := true;
			ords[i] := Order[IndexOf(mids[i])];
		end;
	end;
	Reader.ReleaseRenderSync;

	c := TConfigNode(Reader.List.Childs);
	k := 0;
	with Reader.Plates do
		while (c <> nil) and not Terminated do begin
			if sel >= 0 then Reader.Selected := Reader.Plates.Order[Reader.Plates.IndexOf(sel)];
			Reader.WaitRenderSync;
			j := STI(C.Name);
			for i := 1 to mids[0] do
				if mids[i] = j then begin
					mids[i] := -1;
					u := ords[i];
					break;
				end;
			i := IndexOf(j);
			if i < 0 then
				i := Add(Plate(j, c.Bool['new'], Explode(#13, c.Str['alts']), c.Str['descr']));

			if k <> Order[i] then Reord(i, k);
			Reader.ReleaseRenderSync;
			Data[Order[i]].mLink := c.Str['link'];
			Data[Order[i]].pID := Order[i];
			AquireProgress(@Data[Order[i]]);
			c := TConfigNode(c.Next);
			inc(k);
		end;

	Reader.WaitRenderSync;
	with Reader.Plates do begin
		for i := 1 to mids[0] do
			if mids[i] >= 0 then
				Delete(mids[i]);
	end;
	if sel >= 0 then Reader.Selected := Reader.Plates.Order[Reader.Plates.IndexOf(sel)];
	Reader.ReleaseRenderSync;
end;

end.
