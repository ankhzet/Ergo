unit chapter_drawer;
interface
uses
		WinAPI
{$IFDEF FATRTL}
//	, Windows
	, pngimage
	, Graphics
	, jpeg
	, gifimg
{$ENDIF}
	, Threads
	, page_drawer
	, plate_drawer
	;

type
{$IFNDEF FATRTL}
	TBitmap      = TObject;
{$ENDIF}
	TTinyThread  = class;
	TMethod      = procedure (Thread: TTinyThread) of object;
	TTinyThread  = class(TThread)
	private
	public
		Method     : TMethod;
		evtC, evtM : Thandle;
		constructor  Create(M: TMethod);
		destructor   Destroy; override;
		procedure    Execute; override;
		procedure    SafeTerminate;
	end;
	TChapterPage = class(TPage)
	private
		fPID       : Integer;
		fMID       : Integer;
		fCID       : Integer;
		fMM        : Boolean;

		dScroll    : TPoint;
		ScrollXMax : Integer;
		ScrollYMax : Integer;
		fR         : TRect;
//		nc         : hdc;
//		tbm        : HBITMAP;
		B          : TBitmap;
		iw, ih, w  : Integer;
		h, cw, ch  : Integer;
		fOS        : Boolean;
		fSX        : Integer;
		fSY        : Integer;
		SYDrow     : Integer;
		MouseY     : Integer;
		CineticY   : Integer;
		SXDrow     : Integer;
		MouseX     : Integer;
		CineticX   : Integer;
		Pages      : array of AnsiString;
		Data       : array of TBitmap;

		evtR, evtT : Thandle;
		cbThread   : TTinyThread;
		chThread   : TTinyThread;
		utTime     : Cardinal;
		Cached     : Integer;
		fManga     : PPlate;

		procedure    UpdateTimer(Thread: TTinyThread);
		procedure    CachePages(Thread: TTinyThread);
		procedure    FinalErr;
		procedure    Prev(I: Integer);
		procedure    Next(I: Integer);
		procedure    CalcScale;
		procedure    setMM(const Value: Boolean);
		procedure    DoUp(X, Y: Integer; B: TMsgButton); override;
		procedure    DoDown(X, Y: Integer; B: TMsgButton); override;
		procedure    DoMove(X, Y: Integer); override;
		procedure    setOS(const Value: Boolean);
		procedure    DoScrollX(DX: Integer);
		procedure    DoScrollY(DY: Integer);
		procedure    TimerCallback;
		procedure    setSX(const Value: Integer);
		procedure    setSY(const Value: Integer);
	public
		constructor  Create(R: TReader); override;
		destructor   Destroy; override;
		procedure    DoClick(X, Y: Integer; B: TMsgButton); override;
		procedure    NavigateTo(From: TRPages); override;
		procedure    InitSB; override;
		procedure    Init(MID: Integer; Continue: Boolean; CID: Integer = 1; PID: Integer = 1);
		function     Action(UID: Cardinal): Boolean; override;
		procedure    Size(W, H: Integer); override;
		procedure    Draw; override;

		function     Aquire: Boolean;
		function     AquireChapter: Integer;
		property     Manga: PPlate read fManga;
		property     MangaID: Integer read fMID write fMID;
		property     ChapID: Integer read fCID write fCID;
		property     PageID: Integer read fPID write fPID;
		property     ManhwaMode: Boolean read fMM write setMM;
		property     OriginalSize: Boolean read fOS write setOS;
		property     ScrollX: Integer read fSX write setSX;
		property     ScrollY: Integer read fSY write setSY;
	end;

implementation
uses
		strings
	, functions
	, logs
	, file_sys
	, sql_constants
	, opts
	, WinAPI_GDIRenderer
{$IFDEF FATRTL}
	, GraphicEx
{$ENDIF}
	;

{ ThapterPage }

var
	d: Cardinal;

function TChapterPage.Aquire: Boolean;
begin
	result := false;
	if fPID < 1 then fPID := 1;
	if fCID < 1 then fCID := 1;
	if fMID < 1 then fMID := 1;

	if fPID <= Length(Pages) then begin
		result := true;
		if (Cached > 0) and (Data[fPID - 1] <> nil) then begin
			B := Data[fPID - 1];
			CalcScale;
			ScrollX := ScrollXMax;
			ScrollY := 0;
			SYDrow  := 0;
			SXDrow  := 0;
			SQLCommand('delete from progress p where p.manga = %d', [MangaID]);
			SQLCommand('insert into progress values (%d, %d, %d)', [MangaID, ChapID, PageID]);
			SQLCommand('delete from m_hist p where p.manga = %d', [MangaID]);
			SQLCommand('insert into m_hist values (%d, %d)', [MangaID, UTCSecconds]);
			with fManga^ do
				Title := Format('%s [%d/%d (Chapter #%d/%d)]', [mTitles[0], PageID, Length(Pages), ChapID, mChaps]);
			d := GetTickCount - 1000;
			Reader.WantRender := true;
			Reader.Render;
			Reader.Invalidate;
		end;
		exit;
	end;
	FinalErr;
end;

function MakePreview(id: Integer; Img: TBitmap): Boolean;
var
	n: AnsiString;
	B: TBitmap;
	s: Single;
begin
	result := false;
	if not OPT_PREVIEWS then exit;

	n := Format('%s\\previews\\%d.6\.bmp', [OPT_DATADIR, id]);
	if FileExists(n) then DeleteFile(@n[1]);

	B := TBitmap.Create;
	try
{$IFDEF FATRTL}
		B.Assign(Img);
		if B.Width > B.Height then
			B.Width := round((63 / 96) * B.Height)
		else
			if B.Height / B.Width > (100 / 60) then
				B.Height := round((96 / 63) * B.Width);
		Stretch(63, 96, sfBox, 0, B);
		B.SaveToFile(n);
		ll_Write('done...');
{$ENDIF}
	finally
		B.Free;
	end;
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
			while p1^ in ['0'..'9', '.'] do inc(p1);
			i1 := STF(copy(p3, 0, Cardinal(p1) - Cardinal(p3)));

			p3 := p2;
			while p2^ in ['0'..'9', '.'] do inc(p2);
			i2 := STF(copy(p3, 0, Cardinal(p2) - Cardinal(p3)));
			if abs(i1 - i2) > 0.00001 then exit(i1 > i2);
		end else
			if p1^ = p2^ then begin
				inc(p1);
				inc(p2);
			end else
				exit(p1^ > p2^);

	end;
end;

function TChapterPage.AquireChapter: Integer;
var
	SR: TSearchRec;
	e, d, a: AnsiString;
	R   : TRect;
	p: Integer;
	procedure Add;
	begin
		if p >= Length(Pages) then
			SetLength(Pages, p * 2);

		Pages[p] := a + SR.Name;
		Data[p] := nil;
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
	if fPID < 1 then fPID := 1;
	if fCID < 1 then fCID := 1;
	if fMID < 1 then fMID := 1;
	p := Length(Pages);
	while WaitForSingleObject(evtT, 100) <> WAIT_OBJECT_0 do
		if chThread.Terminated then begin
			chThread.Free;
			chThread := TTinyThread.Create(CachePages);
		end;
	B := QIcon;
	Cached := 0;
	while p > 0 do begin
		dec(p);
		if Data[p] <> nil then
			Data[p].Free;
		Data[p] := nil;
	end;
	SetLength(Pages, 100);
	SetLength(Data, 100);
	try
		a := Format('%s\\%s\\%d.4\\', [OPT_MANGADIR, Manga.mLink, ChapID]);
		if FindFirst(a + '*', faFiles, SR) = 0 then
			repeat
				if SR.Name[1] = '.' then continue;
				e := LowerCase(ExtractFileExt(SR.Name));
				for d in ext do
					if d = e then begin
						Add;
						break;
					end;
			until FindNext(SR) <> 0;
	finally
		FindClose(SR);
	end;
	SetLength(Pages, p);
	SetLength(Data, p);
	Sort(Pages, p);
	SetEvent(evtR);
	SetEvent(evtT);
end;

constructor TChapterPage.Create(R: TReader);
begin
	inherited;
	B := nil;
	utTime := GetTickCount;
	evtT := CreateEvent(nil, false, true, nil);
	evtR := CreateEvent(nil, false, false, nil);
	cbThread := TTinyThread.Create(UpdateTimer);
	chThread := TTinyThread.Create(CachePages);
	d := GetTickCount;
end;

destructor TChapterPage.Destroy;
begin
	cbThread.SafeTerminate;
	chThread.SafeTerminate;
	cbThread.Free;
	chThread.Free;
//	DeleteDC(NC);
//	DeleteObject(tbm);
	CloseHandle(evtR);
	CloseHandle(evtT);
	inherited;
end;

procedure TChapterPage.DoClick(X, Y: Integer; B: TMsgButton);
begin
	case b of
		b_left  : Next(2);
		b_middle: ManhwaMode := not ManhwaMode;
		b_right : Prev(2);
	end;
end;

procedure TChapterPage.DoDown(X, Y: Integer; B: TMsgButton);
begin
	MouseX := X;
	CineticX := X;
	MouseY := Y;
	CineticY := Y;
	case b of
		b_wheel: SYDrow := - trunc(ch / 50);
		b_right: begin
			dScroll.X := ScrollX;
			dScroll.Y := ScrollY;
			SYDrow := 0;
			SXDrow := 0;
		end;
	end;
end;

procedure TChapterPage.DoUp(X, Y: Integer; B: TMsgButton);
begin
	case b of
		b_wheel: SYDrow := + trunc(min(ScrollYMax / 25, ch / 50));
		b_right: begin
			SXDrow := X - CineticX;
			SYDrow := Y - CineticY;
			if SXDrow <> 0 then SXDrow := trunc((SXDrow / 40) * (cw / 50));
			if SYDrow <> 0 then SYDrow := trunc((SYDrow / 40) * (ch / 50));
		end;
	end;
end;

procedure TChapterPage.DoMove(X, Y: Integer);
begin
	MouseX := X;
	MouseY := Y;
	if bDrag[b_right] then begin
		ScrollX := imin(imax(dScroll.X - (X - dPos[b_right].X), 0), ScrollXMax);
		ScrollY := imin(imax(dScroll.Y - (Y - dPos[b_right].Y), 0), ScrollYMax);
	end;
end;

procedure TChapterPage.FinalErr;
begin
	Title := Format('Final, or no image available =( [%d.4/%d.4/%d.4]', [MangaID, ChapID, PageID]);
	Reader.LogMSG := Title;
{$IFDEF FATRTL}
	b := QIcon;
	CalcScale;
	Reader.WantRender := true;
{$ENDIF}
end;

procedure TChapterPage.Init(MID: Integer; Continue: Boolean; CID, PID: Integer);
var
	e: TDBFetch;
begin
	fMID := MID;
	with Reader.Plates do fManga := @Data[Order[IndexOf(fMID)]];
	if Continue then begin
		if e.Fetch(SQL_FETCHMANGAL, [TBL_NAMES[TBL_PROGRE], MID], ['c', 'p']) = 1 then begin
			fCID := e.Int[0];
			fPID := e.Int[1];
		end else begin
			fCID := 1;
			fPID := 1;
		end;
	end else begin
		fCID := CID;
		fPID := PID;
	end;
	if e.Fetch(SQL_FETCHMANGAL, [TBL_NAMES[TBL_MANGAO], MID], ['manhwa', 'orig']) = 1 then begin
		fMM := e.Bool[0];
		fOS := e.Bool[1];
	end else begin
		fMM := false;
		fOS := false;
	end;
	SC_STATES[SB_MMODE] := Cardinal(ManhwaMode);
	SC_STATES[SB_ORIG]  := Cardinal(OriginalSize);
	AquireChapter;
	Aquire;
end;

procedure TChapterPage.InitSB;
begin
	Reader.AddSB(SB_NEXTP , al_top, al_last);
	Reader.AddSB(SB_PREVP , al_top, al_last);
	Reader.AddSB(SB_NEXTC , al_top, al_last);
	Reader.AddSB(SB_PREVC , al_top, al_last);
	Reader.AddSB(SB_MMODE , al_top, al_last);
	Reader.AddSB(SB_ORIG  , al_top, al_last);
	Reader.AddSB(SB_MAKEPV, al_top, al_first);
end;

procedure TChapterPage.NavigateTo(From: TRPages);
begin
	Aquire;
end;

function TChapterPage.Action(UID: Cardinal): Boolean;
begin
	result := true;
	case UID of
		SB_CLOSE: Reader.ActivePage := rp_manga;
		SB_PREVC: Prev(1);
		SB_PREVP: Prev(2);
		SB_NEXTC: Next(1);
		SB_NEXTP: Next(2);
		SB_MMODE,
		SB_ORIG : begin
			if UID = SB_MMODE then begin
				ManhwaMode   := SC_STATES[SB_MMODE] <> 0;
				OriginalSize := ManhwaMode and OriginalSize;
			end else
				OriginalSize := ManhwaMode and not OriginalSize;
			SC_STATES[SB_ORIG] := Cardinal(OriginalSize);
			if MangaID <= 0 then exit;
			SQLCommand(SQL_DELETEMANGAL, [TBL_NAMES[TBL_MANGAO], MangaID]);
			SQLCommand(SQL_INSERT_III, [TBL_NAMES[TBL_MANGAO], MangaID, Byte(ManhwaMode), Byte(OriginalSize)]);
		end;
		SB_MAKEPV: MakePreview(MangaID, B);
		else result := false;
	end;
end;

procedure TChapterPage.Next(I: Integer);
begin
	case i of
		1: begin
			inc(fCID);
			fPID := 1;
			AquireChapter;
			Aquire;
		end;
		2: begin
			inc(fPID);
			if not Aquire then begin
				inc(fCID);
				fPID := 1;
				AquireChapter;
				if not Aquire then FinalErr;
			end;
		end;
	end;
end;

procedure TChapterPage.Prev(I: Integer);
label l1;
begin
	case i of
		1: begin
			dec(fCID);
			fPID := 1;
			AquireChapter;
			Aquire;
		end;
		2: if fPID > 1 then begin
			dec(fPid);
			Aquire;
		end else
			if fCid > 1 then begin
				repeat
					l1:
					dec(fCid);
					if fCID <= 0 then begin
						FinalErr;
						break;
					end;
					AquireChapter;
					fPid := Length(Pages);
					while not Aquire do begin
						dec(fPid);
						if fPID <= 0 then goto l1;
					end;
					break;
				until false;
			end;
	end;
end;

procedure OffsetRect(var R: TRect; dX, dY: Integer); inline;
begin
	inc(R.Left, dx);
	inc(R.Top, dy);
	inc(R.Right, dx);
	inc(R.Bottom, dY);
end;

procedure TChapterPage.Draw;
var
	rh, y1, y2, i, j, k: Integer;
	s: Single;
	b1, b2, b3, b4: HBRUSH;
	DC: HDC;
	tbm: HBITMAP;
begin
	with fR do begin
//		DC := Reader.Canvas.DC;
{$IFDEF FATRTL}
		TBM := B.Handle;
//		SelectObject(NC, B.Handle);
{$ENDIF}
		b1 := L_B;//GetStockObject(LTGRAY_BRUSH);
		b2 := W_B;// GetStockObject(WHITE_BRUSH);
		b3 := N_B;//GetStockObject(NULL_BRUSH);
		if OPT_DRAWFRAME then begin
			Canvas.SetPen(B_P);//SelectObject(DC, B_P);//GetStockObject(BLACK_PEN));
			Canvas.SetBrush(b3);//SelectObject(DC, b3);
		end;
		if ManhwaMode then begin
			if OPT_DRAWFRAME then Canvas.Rectangle(left - ScrollX - 1, top - ScrollY - 1, Right + 1, top - ScrollY + h + 1);
			Canvas.DrawBitmap(TBM, left - ScrollX, top - ScrollY, iw, ih, Right - Left, h);
		end else begin
			if OPT_DRAWFRAME then Canvas.Rectangle(left - 1, top - 1, left + w + 1, top + h + 1);
			Canvas.DrawBitmap(TBM, left, top, iw, ih, w, h);
		end;
//		SelectObject(nc, tbm);
		if ScrollYMax > 0 then begin
			rh := imax(trunc(ch * (ch / ih)), 10);
			y1 := Top + trunc((ch - rh) * ScrollY / ScrollYMax);
			Y2 := y1 + rh - 1;
			if y2 > Top then Canvas.PlateOut(Width - 6, y1, Width - 1, y2, 1, b1, b2, 2);
		end;
		if ScrollXMax > 0 then begin
			rh := imax(trunc((cw - 7) * (cw / iw)), 10);
			y1 := Left + 1 + trunc((cw - rh - 7) * ScrollX / ScrollXMax);
			Y2 := y1 + rh - 1;
			if y2 > Left then Canvas.PlateOut(y1, Height - 6, y2, Height - 1, 1, b1, b2, 2);
		end;

//		ImbaPlate(Reader.TDC, 1, RD_MENUSIZE - 5, cw - 1, RD_MENUSIZE + 5, 1, b3, b3, 2);
		j := Length(Pages);
		k := 0;
		i := 0;
		while i < j do begin
			inc(k, Byte(Data[i] <> nil));
			inc(i);
		end;
		y1 := k;

		Canvas.OutlinedText(Format('%d / %d', [k, j]), 0, RD_TOPPLANE + 9, Width - 16, 16, DT_RIGHT, $000000, $FFFFFF);

		if (j > 0) and (cw > 0) then begin
			k := PageID;
			s := (cw - 6) / j;
			while s < 7 do begin
				j := round(j / 2 + 0.5);
				k := round(k / 2 + 0.5);
				y1:= round(y1 / 2 + 0.5);
				s := (cw - 6) / j;
			end;

			for i := 0 to j - 1 do begin
				if i < y1 then b4 := b2 else b4 := b3;
				if i < k then
					Canvas.PlateOut(3 + trunc(i * s), RD_TOPPLANE, 3 + trunc((i + 1) * s), RD_TOPPLANE + 9, 1, b1, b4, 2)
				else
					Canvas.PlateOut(3 + trunc(i * s), RD_TOPPLANE + 1, 3 + trunc((i + 1) * s), RD_TOPPLANE + 8, 1, b3, b4, 2);
			end;
		end;
	end;
end;

procedure TChapterPage.CalcScale;
var
	s: Single;
	n: Integer;
begin
{$IFDEF FATRTL}
	if (B = nil) or (B.Height = 0) then B := BIcon;

{	 begin
		iw := 128;
		ih := 128;
	end else} begin
		iw := B.Width;
		ih := B.Height;
	end;

{$ELSE}
	iw := 128;
	ih := 128;
{$ENDIF}
	w  := iw;
	h  := ih;
	cw := Width;
	ch := Height - RD_TOPPLANE - 10;

	s := w / h;
	if ManhwaMode then begin
		if not OriginalSize then begin
			if w > cw then begin
				w := cw;
				h := Trunc(w / s);
			end;
			n := h;
		end else
			if w > cw then n := Trunc(cw / s) else n := h;

		ScrollXMax := imax(w - cw, 0);
		ScrollYMax := imax(h - ch, 0);
		s := (n - ch) / (ih - ch);
		if OriginalSize then s := 1 / s;
		ScrollY := imin(imax(round(ScrollY * s), 0), ScrollYMax);
		ScrollX := imin(imax(ScrollX, 0), ScrollXMax);
	end else begin
		ScrollXMax := 0;
		ScrollYMax := 0;
		if (not OPT_DONTENLARGE) or ((w > cw) or (h > ch)) then
		begin
			if w > cw then begin
				w := cw;
				h := Trunc(cw / s);
				if h > ch then begin
					h := ch;
					w := Trunc(ch * s);
				end;
			end else begin
				h := ch;
				w := Trunc(ch * s);
				if w > cw then begin
					w := cw;
					h := Trunc(cw / s);
				end;
			end;
		end;
	end;
	fr.Left  := 0;
	fr.Top   := RD_TOPPLANE + 10;
	fr.Right := w;
	fr.Bottom:= h;
	OffsetRect(fR, imax(0, (cw - w) div 2), imax(0, (ch - h) div 2));
end;

procedure TChapterPage.setMM(const Value: Boolean);
begin
	if fMM <> Value then begin
		fMM := Value;
		CalcScale;
	end;
end;

procedure TChapterPage.setOS(const Value: Boolean);
begin
	if fOS <> Value then begin
		fOS := Value;
		CalcScale;
	end;
end;

procedure TChapterPage.setSX(const Value: Integer);
begin
	if fSX <> Value then begin
		fSX := Value;
		Reader.WantRender := true;
	end;
end;

procedure TChapterPage.setSY(const Value: Integer);
begin
	if fSY <> Value then begin
		fSY := Value;
		Reader.WantRender := true;
	end;
end;

procedure TChapterPage.Size(W, H: Integer);
begin
	inherited;
{	if nc = 0 then begin
		nc := CreateCompatibleDC(0);
		tbm := CreateCompatibleBitmap(nc, 0, 0);
	end;   }
	CalcScale;
end;

var
	s: Cardinal;

procedure TChapterPage.TimerCallback;
var
	sx, sy: Integer;
begin
	sx := trunc(cw / 50);
	sy := trunc(ch / 50);
	if GetKeyState(VK_CONTROL) and $80 <> 0 then begin
		if GetKeyState(VK_LEFT) and $80 <> 0 then SXDrow := sx;
		if GetKeyState(VK_RBUTTON) and $80 <> 0 then SXDrow := - sx;
	end;
	if GetKeyState(VK_UP) and $80 <> 0 then SYDrow := sy;
	if GetKeyState(VK_DOWN) and $80 <> 0 then SYDrow := - sy;
	DoScrollX(SXDrow);
	DoScrollY(SYDrow);
	inc(s);
	SXDrow := trunc(SXDrow * 0.95);
	SYDrow := trunc(SYDrow * 0.95);
	if s mod 3 = 0 then CineticX := MouseX;
	if s mod 3 = 0 then CineticY := MouseY;
end;

procedure TChapterPage.DoScrollY(DY: Integer);
begin
	ScrollY := imin(imax(ScrollY - DY, 0), ScrollYMax);
end;

procedure TChapterPage.DoScrollX(DX: Integer);
begin
	ScrollX := imin(imax(ScrollX - DX, 0), ScrollXMax);
end;

procedure TChapterPage.UpdateTimer;
var
	p: Cardinal;
begin
	p := GetTickCount - utTime;
	if p > 33 then begin
		inc(utTime, p mod 33);
		TimerCallback;
	end;
end;

procedure TChapterPage.CachePages(Thread: TTinyThread);
{$IFDEF FATRTL}
var
	m, c, p: Integer;
	pc, i  : Integer;
	Picture: TPicture;
	B      : TBitmap;
	first  : boolean;
	fID    : Integer;
{$ENDIF}
begin
{$IFDEF FATRTL}
	if WaitForSingleObject(evtR, 0) <> WAIT_OBJECT_0 then begin // cache not requested
		SetEvent(evtT);
		exit;
	end;
	m := mangaID;
	c := ChapID;
	if PageID <= 0 then PageID := 1;
	pc := Length(Pages);
	p := 0;
	first := true;
	fID := PageID - 1;
	Picture := TPicture.Create;
	while p < pc do begin
		while WaitForSingleObject(evtT, 100) <> WAIT_OBJECT_0 do
			if Thread.Terminated then exit; // wait until synchronization is allowed

		if WaitForSingleObject(evtR, 0) = WAIT_OBJECT_0 then begin // cur chapter was changed =\
			Picture.Free;
			SetEvent(evtT);
			SetEvent(evtR);
			exit;
		end;
		// else proceed with caching

		if first then begin
			i := fID;
			first := false;
		end else
			if p = fID then begin
				inc(p);
				setEvent(evtT);
				continue;
			end else begin
				i := p;
				inc(p);
			end;
//		if Data[i] <> nil then Data[i].Free;
		Data[i] := nil;
		B := TBitmap.Create;
		if FileExists(Pages[i]) then begin
			try
				Picture.LoadFromFile(Pages[i]);
				B.Assign(Picture.Graphic);
			except
			end;
		end;
		Data[i] := B;
		inc(Cached);
		if i = PageID - 1 then Aquire;
		setEvent(evtT);
		Reader.WantRender := true;
	end;
	Picture.Free;
	Cached := pc;
{$ENDIF}
end;

{ TTinyThread }

constructor TTinyThread.Create(M: TMethod);
begin
	Method := M;
	evtC := CreateEvent(nil, false, false, nil);

//	FreeOnTerminate := true;
	inherited Create(false);
end;

destructor TTinyThread.Destroy;
begin
	CloseHandle(evtC);
	inherited;
end;

procedure TTinyThread.Execute;
begin
	repeat
		SetEvent(evtC);
		sleep(10);
		WaitForSingleObject(evtC, INFINITE);
		if Terminated then break;
		Method(Self);
	until false;
end;

procedure TTinyThread.SafeTerminate;
begin
	WaitForSingleObject(evtC, INFINITE);
	Terminate;
	SetEvent(evtC);
end;

end.
