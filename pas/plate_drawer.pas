unit plate_drawer;
interface
uses
		WinAPI
	, strings
{$IFDEF FATRTL}
	, Graphics
	, graphicex
	, s_httpproxy
{$ENDIF}
	, s_config
	, c_interactive_lists
	;

type
{$IFNDEF FATRTL}
	TBitmap      = TObject;
{$ENDIF}
	PILPlates    = PIList;
	PPlates      =^TPlates;
	PPlate       =^TPlate;
	TPlate       = object
		mID        : Cardinal;
		mNew       : Boolean;
		mTitles    : TStrings;
		mJenres    : TStrings;
		mJIDS      : array of record id: Integer; desc: AnsiString end;
		mDescr     : AnsiString;
		mStatus    : Cardinal;
		mLink      : AnsiString;
		mServer    : AnsiString;
		mSrc       : Integer;
		mComplete  : Boolean;
		mArchives  : Integer;
		mArchTotal : Integer;
		rChapter   : Integer;
		rPage      : Integer;
		rReaded    : Boolean;
		fFiltered  : Boolean;
		mChaps     : Integer;
		pIcon      : TBitmap;
		pUpdating  : Boolean;
		pID        : Integer;
		pPlates    : PPlates;
		procedure    Draw(X, Y, W: Integer; B: HBRUSH);
	end;
	TPlates      = object
	private
		Actual     : Integer;
		procedure    Sort;
	public
		Count      : Integer;
		Height     : Integer;
		Order      : array of Integer;
		Data       : array of TPlate;
		Sorted     : Boolean;
		PlatesInRow: Integer;
		InView     : Integer;
		FirstHidden: Integer;
		TopID      : Integer;
		HoverID    : Integer;
		SelID      : Integer;
		SBID       : Integer;
		_sb        : array [0..7] of HBITMAP;
		_sb_act    : array [0..7] of Cardinal;
		procedure    Init;
		procedure    Destroy;
		procedure    Resize(Size: Integer);
		function     IndexOf(ID: Cardinal): Integer;
		function     Add(P: TPlate): Integer;
		function     Delete(ID: Cardinal): Integer;
		procedure    Draw(S, Y, W, H: Integer);
	end;

var
	RD_PLATEHEIGHT  : Integer = 86;
	RD_PLATEWIDTH   : Integer = 260;
	RD_PREVIEWHEIGHT: Integer = 83;
	RD_PREVIEWWIDTH : Integer = trunc(83 * 0.656);

{var
	BG, WG, FG, SG: HBRUSH;
var
	N_P, B_P, W_P: HPEN;
	N_B, G_B, W_B: HBRUSH;
	L_B          : HBRUSH; }


	SrvSync: boolean = false;

var
	XIcon: TBitmap;
	QIcon: TBitmap;
	BIcon: TBitmap;


const
	RD_TOPPLANE = 21;
	RD_SBWIDTH  = 14;
	RD_SBSPACE  = 4;
	RD_SPEEDBUTS= 4;
	RD_SBGAIN   = RD_SBWIDTH + RD_SBSPACE;
	RD_FILTERWD = 100;
	RD_FILTERSPC= RD_FILTERWD + RD_SBSPACE;
	PV_WIDTH    = 71;
	PV_HEIGHT   = 107;


	SB_SEPAR = $0000;     // Q
	SB_CLOSE = $0001;     // Q
	SB_BACK  = $0002;     // Q
	SB_NEXT  = $0003;     // E
	SB_NEXTC = $0004;     // Ctrl+Right
	SB_NEXTP = $0005;     // Right
	SB_PREVC = $0006;     // Ctrl+Left
	SB_PREVP = $0007;     // Left
	SB_MMODE = $0008;     // M
	SB_VIEW  = $0009;     // Ctrl+Enter
	SB_CONT  = $000A;     // Enter
	SB_ORIG  = $000B;     // O
	SB_FIND  = $000C;     // Ctrl+F
	SB_FULLS = $000D;     // F11
	SB_UPD   = $000E;
	SB_SRVSYN= $000F;
	SB_COMPL = $0010;
	SB_READED= $0011;
	SB_IMPORT= $0012;     // Ctrl+I
	SB_PVIEW = $0013;
	SB_EXPLOR= $0014;     // Ctrl+O
	SB_REGIST= $0015;
	SB_FILTER= $0016;
	SB_MAKEPV= $0017;
	SB_RSS   = $0018;
	SB_SUSP  = $0019;
	SB_FIXARC= $001A;
	SB_MAX   = SB_FIXARC;

type
	TSCTable = array [SB_SEPAR..SB_MAX] of Cardinal;
	TSCHints = array [SB_SEPAR..SB_MAX] of AnsiString;

const
	SB_HINT  : TSCHints = (
		'',
		'Закрыть',
		'Назад',
		'Дальше',
		'Следующая глава',
		'Следующий скан',
		'Предыдущая глава',
		'Предыдущий скан',
		'Манхва-режим',
		'Читать с начала',
		'Продолжить чтение',
		'Сканы в оригинальном размере',
		'Искать',
		'Полноэкранный режим',
		'Обновление',
		'Синхронизация с сервером',
		'Манга завершена',
		'Манга прочитана',
		'Импорт',
		'Кешировать превью',
		'Папка с архивами',
		'Добавить мангу',
		'Фильтр манги',
		'Использовать скан в качестве превью',
		'RSS',
		'Релиз был приостановлен',
		'Пересчитать архивы'
	);

	SC_CTRL  = VK_CONTROL shl 16;
	SC_SHIFT = VK_SHIFT shl 16;

	SC_CLOSE = ord('Q');            // Q
	SC_BACK  = SC_CLOSE;            // Q
	SC_NEXT  = ord('E');            // E
	SC_NEXTC = VK_RIGHT or SC_CTRL; // Ctrl+Right
	SC_NEXTP = VK_RIGHT;            // Right
	SC_PREVC = VK_LEFT or SC_CTRL;  // Ctrl+Left
	SC_PREVP = VK_LEFT;             // Left
	SC_MMODE = ord('M');            // M
	SC_VIEW  = VK_RETURN or SC_CTRL;// Ctrl+Enter
	SC_CONT  = VK_RETURN;           // Enter
	SC_ORIG  = ord('O');            // O
	SC_FIND  = ord('F') or SC_CTRL; // Ctrl+F
	SC_FULLS = VK_F11;              // F11
	SC_IMPORT= ord('I') or SC_CTRL; // Ctrl+E
	SC_EXPLOR= ord('O') or SC_CTRL; // Ctrl+E
	SC_RSS   = ord('R') or SC_CTRL; // Ctrl+E

var

	SC_TABLE : TSCTable = (
		0,
		SC_CLOSE,
		SC_BACK,
		SC_NEXT ,
		SC_NEXTC,
		SC_NEXTP,
		SC_PREVC,
		SC_PREVP,
		SC_MMODE,
		SC_VIEW ,
		SC_CONT ,
		SC_ORIG ,
		SC_FIND ,
		SC_FULLS,
		0,
		0,
		0,
		0,
		SC_IMPORT,
		0,
		SC_EXPLOR,
		0,
		0,
		0,
		SC_RSS,
		0,
		0
	);
	SC_TOGGLE: TSCTable = (
		$FFFFFFFF,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		1,
		0,
		1,
		0,
		1,
		1,
		1,
		0,
		1,
		0,
		0,
		1,
		0,
		0,
		1,
		0
	);
	SC_STATES: TSCTable;


var
	IPlates : PILPlates;

function  Request(M: AnsiString; c: TConfigNode): Boolean;
function  Plate(ID: Cardinal; New: Boolean; Titles: TStrings; Descr: AnsiString): TPlate;
function  LoadPreview(id: Integer; SubDir: AnsiString): TBitmap;
function  LoadIcon(Icon: Cardinal): HBITMAP;

implementation
uses
		functions
	, logs
	, file_sys
	, parsers
	, opts
	, vcl_rtfrenderer
	, WinAPI_GDIRenderer
	;

procedure _ip_init(Item: PILItem; Data: Pointer; var Continue: Boolean);
var
	Plate: PPlate;
begin
	new(Plate);
	Item.Data := Cardinal(Plate);
	Plate.mID     := 0;
	Plate.mNew    := false;
	Plate.mDescr  := '';
end;

procedure _ip_release(Item: PILItem; Data: Pointer; var Continue: Boolean);
begin
	Dispose(PPlate(Item.Data));
end;

function InitPlates: PILPlates;
begin
	IPlates := _il_new(_ip_init, _ip_release);
end;

function Request(M: AnsiString; c: TConfigNode): Boolean;
var
	P: TTokenizer;
{$IFDEF FATRTL}
	R: TClientRequest;
{$ENDIF}
begin
	result := false;
{$IFDEF FATRTL}
	if not SrvSync then begin
		{$IFDEF DEBUG}ll_write('Reqest [%s] aborted: syncstate is OFF...', [M]);{$ENDIF}
		exit;
	end;
	R := TClientRequest.Create;
	try
		if R.Request(1122, '127.0.0.1', M, 10) then begin
			{$IFDEF DEBUG}ll_write('Reqest [%s] success...', [M]);{$ENDIF}
//			mSrvResp.Text := PAnsiChar(R.Data);
			try
				P := TTokenizer.Create;
				try
					P.Init(PAnsiChar(RecodeHTMLTags(PAnsiChar(R.Data))));
					C.RemoveChilds;
					C.ReadFromParser(P);
				finally
					P.Free;
				end;
				result := true;
			except
				on E: Exception do begin
//					l_Write('Error parsing response: %s', [E.Message]);
				end;
			end;
		end else
			ll_Write('Request fail...');
	except
//		on E: Exception do l_Write('Request fail: %s', [E.Message]);
	end;
	R.Free;
{$ENDIF}
end;

procedure OffsetRect(var R: TRect; DX, DY: Integer);// inline;
begin
	inc(R.Left, DX);
	inc(R.Right, DX);
	inc(R.Top, DY);
	inc(R.Bottom, DY);
end;

function Plate(ID: Cardinal; New: Boolean; Titles: TStrings; Descr: AnsiString): TPlate;
begin
	result.mID     := ID;
	result.mNew    := New;
	result.mTitles := Titles;
	result.mDescr  := Descr;
end;

{ TPlates }

function LoadIcon(Icon: Cardinal): HBITMAP;
var
	s: AnsiString;
	b: TBitmap;
begin
	result := 0;
	s := Format('%s\\icons\\%d.4.bmp', [OPT_DATADIR, Icon]);
	B := TBitmap.Create;
	try
{$IFDEF FATRTL}
		try
			B.LoadFromFile(S);
			result := B.ReleaseHandle;
		except
		end;
{$ENDIF}
	finally
		B.Free;
	end;
end;

function LoadPreview(id: Integer; SubDir: AnsiString): TBitmap;
var
	e: AnsiString;
	n: AnsiString;
{$IFDEF FATRTL}
	R: TGraphicExGraphic;
	Y: TGraphic absolute R;
	T: TGraphicClass;
	C: TGraphicExGraphicClass;
{$ENDIF}
	L: Boolean;
const
	ext: array [0..4] of AnsiString = ('bmp', 'jpg', 'jpeg', 'png', 'gif');
begin
	result := QIcon;
	if not OPT_PREVIEWS then exit;
	result := nil;
	for e in ext do begin
		n := Format('%s\\previews\\%d.6\.%s', [OPT_DATADIR, id, e]);
		L := not FileExists(n);
		if L then begin
			n := Format('%s\\%s\\0001\\0001\.%s', [OPT_MANGADIR, SubDir, e]);//previews\\%d\.%s', [id, e]);
			if not FileExists(n) then continue;
		end;

		result := TBitmap.Create;
		try
{$IFDEF FATRTL}
			C := FileFormatList.GraphicFromContent(n);
			if C = nil then begin
				T := FileFormatList.GraphicFromExtension(e);
				if T = nil then exit;
				Y := T.Create;
				try
					Y.LoadFromFile(n);
					result.Assign(Y);
				finally
					Y.Free;
				end;
				Stretch(63, 96, sfBox, 0, result);
			end else begin
				R := C.Create;
				try
					R.LoadFromFile(n);
					Stretch(63, 96, sfBox, 0, R, result);
				finally
					R.Free;
				end;
			end;
			if L then result.SaveToFile(Format('%s\\previews\\%d.6\.bmp', [OPT_DATADIR, id]));
{$ENDIF}
		except
			result.Free;
			result := nil;
		end;
		exit;
	end;
end;  {}

function TPlates.Add(P: TPlate): Integer;
//var
//	s: AnsiString;
begin
	result := IndexOf(P.mID);
	if result >= 0 then exit;
	result := Count;
	Resize(Count + 1);
{	if FileExists(OPT_MANGADIR + '\' + p.mLink) then
		s := p.mLink
	else
		s := ITS(p.mID, 0, 6);
//	if not p.mNew then
//	else
//		P.pIcon := XIcon
	;   }
	p.fFiltered := true;
	P.pPlates   := @Self;
	p.pID       := result;
	Data[result] := P;
	Order[result] := result;
	result := IndexOf(P.mID);
end;

function TPlates.Delete(ID: Cardinal): Integer;
var
	i: Integer;
begin
	result := IndexOf(ID);
	if result < 0 then exit;
	i := Count - 1;
	if Order[result] <> i then Data[Order[result]] := Data[i];
	Resize(i);
	for i := 0 to Count - 1 do Order[i] := i;
	Sorted := false;
end;

procedure TPlates.Draw(S, Y, W, H: Integer);
var
	i, j: Integer;
	o, k: Integer;
	B, T: HBRUSH;
	T2, R: HBRUSH;
	e : Integer;
label exit1;
begin
	InView := 0;
	Height := 0;
	FirstHidden := 0;
	PlatesInRow := imax(1, W div RD_PLATEWIDTH);
	if Count <= 0 then goto exit1;

//	stt := SaveDC(DC);
// finding plates obscured by upper margin
	i := imax(0, imin(Count - 1, (S div RD_PLATEHEIGHT) * PlatesInRow));
// their's height is///
	j := (i div PlatesInRow) * RD_PLATEHEIGHT;

	FirstHidden := j;
	TopID := i;

	o := j - S;
	Canvas.SetBrush(B_P);
	j := (S + H) - j;
	j := imin((j div RD_PLATEHEIGHT + Byte(j mod RD_PLATEHEIGHT <> 0)) * PlatesInRow, Count - TopID);
	InView := RD_PLATEHEIGHT * j;
	Height := RD_PLATEHEIGHT * Ceil(Count / PlatesInRow);
	inc(j, i);
	if i >= j then goto exit1;
	T := wg;
	T2:= fg;
	k := W div PlatesInRow;
	while i < j do begin
		if i <> HoverID then
			if i = SelID then B := SG else
				if Data[i].fFiltered then
					B := T
				else
						B := T2
		else
			B := BG;
		s := k * (i mod PlatesInRow);
		Data[i].Draw(s, Y + o, k, B);
		if i = HoverID then begin
			s := s + k;
			H := Y + o + RD_PLATEHEIGHT;
			for e := 1 to RD_SPEEDBUTS do begin
				if e = SBID + 1 then R := W_B else R := N_B;
				Canvas.PlateOut(s - 18 * e - 7, H - 22, s - (e - 1) * 18 - 9, H - 6, 1, R, B);
				Canvas.DrawBitmap(_sb[e - 1], s - 18 * e - 4, H - 19, RD_SBWIDTH + 1, RD_SBWIDTH + 1, 10, 10);
			end;
		end;
		if (i + 1) mod PlatesInRow = 0 then inc(o, RD_PLATEHEIGHT);
		inc(i);
	end;
	exit1:
//	RestoreDC(DC, stt);
end;

function TPlates.IndexOf(ID: Cardinal): Integer;
var
	l, h: Integer;
	i   : Cardinal;
begin
	h := Count - 1;
	if h >= 0 then begin
		l := 0;
		if not Sorted then Sort;
		repeat
			result := (l + h) div 2;
			i := Data[Order[result]].mID;
			if i = ID then exit;
			if i > ID then
				h := result - 1
			else
				l := result + 1;
		until l > h;
	end;
	result := -1;
end;

procedure TPlates.Init;
var
	i: Integer;
begin

	N_P := GetStockObject(NULL_PEN);
	B_P := GetStockObject(BLACK_PEN);
	W_P := GetStockObject(WHITE_PEN);

	N_B := GetStockObject(NULL_BRUSH);
	G_B := GetStockObject(GRAY_BRUSH);
	L_B := GetStockObject(LTGRAY_BRUSH);
	W_B := GetStockObject(WHITE_BRUSH);

	XIcon := TBitmap.Create;
	try
{$IFDEF FATRTL}
		XIcon.LoadFromFile('data\previews\new.bmp');
{$ENDIF}
	except

	end;
	QIcon := TBitmap.Create;
	try
{$IFDEF FATRTL}
		QIcon.LoadFromFile('data\previews\unk.bmp');
{$ENDIF}
	except

	end;
	BIcon := TBitmap.Create;
	try
{$IFDEF FATRTL}
		BIcon.LoadFromFile('data\previews\brk.bmp');
{$ENDIF}
	except

	end;

	_sb_act[0] := SB_CONT;
	_sb_act[1] := SB_IMPORT;
	_sb_act[2] := SB_EXPLOR;
	_sb_act[3] := SB_FIXARC;
	for i := 0 to RD_SPEEDBUTS - 1 do
		_sb[i] := LoadIcon(_sb_act[i]);
end;

procedure TPlates.Destroy;
begin
	XIcon.Free;
	QIcon.Free;
	BIcon.Free;
	DeleteObject(BG);
	DeleteObject(WG);
	DeleteObject(FG);
	DeleteObject(SG);
end;

procedure TPlates.Resize(Size: Integer);
begin
	if Count <> Size then begin
		Sorted := (Size < 2) or (Size < Count);
		Count := Size;
		if (Actual > Count + $F) or (Actual < Count) then Actual := Count + $F;
		if Actual <> Count then begin
			SetLength(Order, Actual);
			SetLength(Data, Actual);
		end;
	end;
end;

procedure TPlates.Sort;
var
	t, i: Integer;
begin
	repeat
		Sorted := true;
		for i := 0 to Count - 2 do
			if Data[Order[i]].mID > Data[Order[i + 1]].mID then begin
				t := Order[i];
				Order[i] := Order[i + 1];
				Order[i + 1] := t;
				Sorted := false;
			end;
	until Sorted;
end;

{ TPlate }

function aaxx(i: Integer; Word: AnsiString; Forms: array of AnsiString): AnsiString;
(*
	'', 'а', 'ов'
	1, 21, 31, ххх           архив
	2, 3, 4, 22, 23, 24, ххх архива
	0, 5, 6, 7, 8, 9, 10,
	11, 12, 13, 14, 15, 16, 17, 18, 19, 20
	25, 26, 27, 28, 29, 30
	35, ххх архивов
*)
begin
	if (i mod 100) in [11..19] then
		result := Word + Forms[2]
	else
	case i mod 10 of
		1      : result := Word + Forms[0];
		2..4   : result := Word + Forms[1];
		0, 5..9: result := Word + Forms[2];
	end;
end;

const
	TM_STR: PAnsiChar =
		'{[RGB:%h6]%s}\n' +
		'[TL][RGB:808080]Прогресс: {[RGB:%h6]%d} / {[RGB:000090]%d}\n' +
		'{[RGB:808080]%s%d %s}';
	TM_STRL: PAnsiChar =
		'{[RGB:%h6]%s}\n' +
		'[TL][RGB:808080]Прогресс: {[RGB:%h6]%d} / {[RGB:000090]%d}\n' +
		'{[RGB:808080]%s%d %s}\n' +
		'{[RGB:808080]\\[ID#%d.4\\] %s}\n' +
		'%s, %s'
		;
	TA_STR: PAnsiChar = '({[RGB:00AA00]+%d}) ';
	com: array [boolean] of ansistring = ('{[RGB:804040]Онгоинг}', '{[RGB:008800]Завершена}');
	red: array [boolean] of ansistring = ('{[RGB:008000]В процессе}', '{[RGB:909090]Прочитана}');
	con: array [boolean] of cardinal   = ($FF0000, $309030);
	coc: array [boolean] of cardinal   = ($008000, $000090);

procedure TPlate.Draw(X, Y, W: Integer; B: HBRUSH);
var
	R: TRect;
	S, T: AnsiString;
	H, AW, AH: Integer;
	TBM: HBITMAP;
begin
	R.Left := X + 5;
	R.Top := Y + 1;
	R.Right := X + W - 5;
	R.Bottom := Y + RD_PLATEHEIGHT - 2;
	with R do begin
		Canvas.PlateOut(Left, Top, Right, Bottom, 1, G_B, B);
		Canvas.Rectangle(Left + 9, Y, Left + RD_PREVIEWWIDTH + 2 + 9, Y + RD_PLATEHEIGHT - 1);
{$IFDEF FATRTL}
		if (pIcon <> nil) then
			TBM := pIcon.Handle //SelectObject(TDC, pIcon.Handle)
		else
			TBM := QIcon.Handle //SelectObject(TDC, QIcon.Handle)
			;
{$ENDIF}
		Canvas.DrawBitmapO(TBM, Left + 1 + 9, Top, RD_PREVIEWWIDTH, RD_PREVIEWHEIGHT, 4, 6);
//		StretchBlt(DC, Left + 1 + 9, Top, RD_PREVIEWWIDTH, RD_PLATEHEIGHT - 3, TDC, 0, 0, 63, 96, SRCCOPY);
//		SelectObject(TDC, TBM);
	end;

	R.Left := R.Left + RD_PREVIEWWIDTH + 4 + 9;
	inc(R.Top, 5);
	dec(R.Right, 5);
	dec(R.Bottom, 5);

	AW := R.Right - R.Left;
	AH := R.Bottom - R.Top;

	if Length(mTitles) > 1 then s := mTitles[0] + '\n{[RGB:808080]' + mTitles[1] + '}' else s := mTitles[0];
	if mArchives > 0 then t := Format(TA_STR, [mArchives, mArchTotal]) else t := '';
	if (pPlates.HoverID <> pID) and (pPlates.SelID <> pID) then
	s := Format(TM_STR, [
		con[mNew or pUpdating],
		s,
		coc[rChapter >= mChaps],
		rChapter,
		mChaps,
		t,
		mArchTotal,
		aaxx(mArchTotal, 'архив', ['', 'а', 'ов'])
	]) else
	s := Format(TM_STRL, [
		con[mNew or pUpdating],
		s,
		coc[rChapter >= mChaps],
		rChapter,
		mChaps,
		t,
		mArchTotal,
		aaxx(mArchTotal, 'архив', ['', 'а', 'ов']),
		mID,
		mLink,
		com[mComplete],
		red[rReaded]
	]);

	Canvas.RTF.RenderText(@s[1], R.Left, R.Top, AW, AH);
end;

end.
