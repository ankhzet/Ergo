unit page_drawer;
interface
uses
		WinAPI
	, threads
//	, vcl_window
//	, vcl_components
//	, vcl_control
//	, vcl_messages
	, s_config
//	, plate_drawer
{$IFDEF FATRTL}
	, bmp
{$ENDIF}
//	, s_serverreader
//	, s_mangasync
//	, Graphics
	;

type
	TRPages     = (rp_none, rp_home, rp_options, rp_search, rp_manga, rp_chapter, rp_import, rp_rss);
	TMsgButton  = (b_none, b_left, b_middle, b_right, b_shift, b_ctrl, b_wheel);
	TMsgButtons = set of TMsgButton;
	TBtnState   = (s_up, s_down, s_move);

	TReader     = class;

	TSBPanel    = (al_top, al_left, al_right);
	TSBAlign    = (al_first, al_last, al_middle);
	PSpeedButton=^TSpeedButton;
	TSpeedButton= record
		Action    : Cardinal;
		Shortcut  : Cardinal;
		Bitmap    : HBITMAP;
		Panel     : TSBPanel;
		Align     : TSBAlign;
	end;

	TPage       = class
	private
		fHeight   : Integer;
		fWidth    : Integer;
		fReader   : TReader;
		fTitle    : AnsiString;
	protected
		bDrag     : array [TMsgButton] of Boolean;
		dPos      : array [TMsgButton] of TPoint;
		bDragged  : Boolean;
		rPos      : TPoint;
		function    MouseInRect(R: PRect): Boolean;
		procedure   DoClick(X, Y: Integer; B: TMsgButton); virtual;
		procedure   DoDown(X, Y: Integer; B: TMsgButton); virtual;
		procedure   DoUp(X, Y: Integer; B: TMsgButton); virtual;
		procedure   DoMove(X, Y: Integer); virtual;
		procedure   InitSB; virtual;
	public
		constructor Create(R: TReader); virtual;
		procedure   Draw; virtual;
		procedure   Size(W, H: Integer); virtual;
		procedure   ButtonMsg(X, Y: Integer; B: TMsgButton; State: TBtnState; Pressed: TMsgButtons); virtual;
		procedure   OnKey(var M: TWMChar); virtual;
		procedure   CacheUpdated; virtual;
		procedure   NavigateTo(From: TRPages); virtual;
		procedure   NavigateFrom(Show: TRPages); virtual;
		function    Action(UID: Cardinal): Boolean; virtual;
		property    Width: Integer read fWidth;
		property    Height: Integer read fHeight;
		property    Reader: TReader read fReader;
		property    Title: AnsiString read fTitle write fTitle;
	end;

	TPages      = array [TRPages] of TPage;
	TSpeedButts = array of TSpeedButton;
	TSBArr      = array [Byte] of PSpeedButton;
	TReader     = class(TWindow)
	private
		fActivePage:TRPages;
		fLog      : AnsiString;
		fSelected : Integer;
		fHint     : AnsiString;
		fWR       : Boolean;
		fwc, fwt  : Cardinal;
		fwa       : Cardinal;
    fSeID: Cardinal;
		procedure   ReleaseSB;
		procedure   setPage(const Value: TRPages);
		procedure   setLogMsg(const Value: AnsiString);
		procedure   setWR(const Value: Boolean);
    procedure setSelID(const Value: Cardinal);
	protected
		_t, _l, _r: TSBArr;
		_f, _m, _a: TSBArr;
		SpeedButton:TSpeedButts;
		count     : Cardinal;
		procedure   CreateHandle; override;
		procedure   ScrollInView; virtual; abstract;
		procedure   setSelected(const Value: Integer); virtual;
	public
		tc, lc, rc: Integer;
		fc, ac, mc: Integer;

		FntSmall  : HFont;
		FntNormal : HFont;

		Pages     : TPages;
		List      : TConfigNode;
		Plates    : TPlates;
		eRender   : THandle;
		WantRender: Boolean;

		constructor Create(Owner: TComponent); override;
		destructor  Destroy; override;
		procedure   Render; virtual;
		procedure   Action(ActionUID: Cardinal); virtual; abstract;
		procedure   WaitRenderSync;
		procedure   ReleaseRenderSync;
		function    AddSB(Action: Cardinal; Panel: TSBPanel; Align: TSBAlign): Integer;
		property    ActivePage: TRPages read fActivePage write setPage;
		property    LogMSG: AnsiString read fLog write setLogMsg;
		property    Hint: AnsiString read fHint write fHint;
		property    Selected: Integer read fSelected write setSelected;
		property    SelectedID: Cardinal read fSeID write setSelID;
		property    Renders: Boolean read fWR write setWR;
		property    Wants: Cardinal read fWa;
	end;

const
	SD_CREDITS = 'credits';
	SD_JUNK    = 'junk';
	SD_ARCHIVE = 'archives';
	SDIRS      : array [0..2] of PAnsiChar = (SD_CREDITS, SD_JUNK, SD_ARCHIVE);
	ARCHS      : array [0..3] of PAnsiChar = ('rar', 'zip', 'tar', 'arj');

const
	J_READED    = 55;
	J_COMPLETED = 56;
	J_SUSPENDED = 60;

	SIZE_IMGNAME = 3;
	SIZE_CHPNAME = 4;
	SIZE_MANNAME = 6;

const
	CHBWIDTH  = 90;
	CHBHEIGHT = 16;

implementation
uses
		strings
	, WinAPI_GDIRenderer
	;

{ TPage }

constructor TPage.Create(R: TReader);
begin
	fReader := R;
end;

function TPage.MouseInRect(R: PRect): Boolean;
begin
	with R^, rPos do
		result := (X > Left) and (Y > Top) and (X < Right) and (Y < Bottom);
end;

function TPage.Action(UID: Cardinal): Boolean;
begin

end;

procedure TPage.ButtonMsg(X, Y: Integer; B: TMsgButton; State: TBtnState; Pressed: TMsgButtons);
begin
	case State of
		s_up  : begin
			bDrag[B] := false;
			DoUp(X, Y, B);
			if not bDragged then
				DoClick(X, Y, B);
		end;
		s_down: begin
			SetFocus(Reader.Handle);
			bDrag[B] := true;
			bDragged := false;
			dPos[B].X := X;
			dPos[B].Y := Y;
			DoDown(X, Y, B);
		end;
		s_move: begin
			DoMove(X, Y);
		end;
	end;
	if (rPos.X <> X) or (rPos.Y <> Y) then begin
		if (abs(rPos.X - X) > 1) or (abs(rPos.Y - Y) > 1) then bDragged := true;
		rPos.X := X;
		rPos.Y := Y;
		Reader.WantRender := true;
	end;
end;

procedure TPage.DoClick(X, Y: Integer; B: TMsgButton);
begin

end;

procedure TPage.DoDown(X, Y: Integer; B: TMsgButton);
begin

end;

procedure TPage.DoMove(X, Y: Integer);
begin

end;

procedure TPage.DoUp(X, Y: Integer; B: TMsgButton);
begin

end;

procedure TPage.Draw;
begin

end;

procedure TPage.InitSB;
begin

end;

procedure TPage.NavigateFrom(Show: TRPages);
begin

end;

procedure TPage.NavigateTo(From: TRPages);
begin

end;

procedure TPage.Size(W, H: Integer);
begin
	fWidth  := W;
	fHeight := H;
end;

procedure TPage.OnKey(var M: TWMChar);
begin

end;

procedure TPage.CacheUpdated;
begin

end;

{ TReader }

function TReader.AddSB(Action: Cardinal; Panel: TSBPanel; Align: TSBAlign): Integer;
var
	i, j: Integer;
	p   : PSpeedButton;
	procedure add(var arr: TSBArr; var c: Integer);
	begin
		arr[c] := p;
		inc(c);
	end;
begin
	result := Length(SpeedButton);
	SetLength(SpeedButton, result + 1);
	SpeedButton[result].Action := Action;
	SpeedButton[result].Shortcut := SC_TABLE[Action];
	SpeedButton[result].Bitmap := LoadIcon(Action);
	SpeedButton[result].Panel  := Panel;
	SpeedButton[result].Align  := Align;

	tc := 0;
	lc := 0;
	rc := 0;
	i := 0;
	j := Length(SpeedButton);
	while i < j do begin
		p := @SpeedButton[i];
		inc(i);
		case p.Panel of
			al_left : add(_l, lc);
			al_top  : add(_t, tc);
			al_right: add(_r, rc);
		end;
	end;
	fc := 0;
	mc := 0;
	ac := 0;
	i := 0;
	while i < tc do begin
		p := _t[i];
		inc(i);
		case p.Align of
			al_first : add(_f, fc);
			al_middle: add(_m, mc);
			al_last  : add(_a, ac);
		end;
	end;
end;

constructor TReader.Create(Owner: TComponent);
//var
//	R: s_serverreader.TReader;
begin
	fSelected := -1;
	eRender := CreateEvent(nil, false, true, 'render');
	Canvas.Create;
	Plates.Init;
//	Sync := TSynhronizer.Create;
//	R := TManga24Rdr.Create;
//	R.UID := 1;
//	Readers.Register(R);
	inherited;
end;

procedure TReader.CreateHandle;
begin
	inherited;
	Canvas.Bind(Handle);
	Canvas.Resize(Width, Height);
	fwt := GetTickCount;
	fwc := 0;
end;

destructor TReader.Destroy;
begin
//	Sync.Free;
	Plates.Destroy;
	Canvas.Destroy;
	inherited;
end;

procedure TReader.ReleaseRenderSync;
begin
	SetEvent(eRender);
end;

procedure TReader.ReleaseSB;
var
	i: Integer;
begin
	RemoveAll;
	i := Length(SpeedButton);
	while i > 0 do begin
		dec(i);
		DeleteObject(SpeedButton[i].Bitmap);
	end;
	SetLength(SpeedButton, 0);
end;

procedure TReader.Render;
begin

end;

procedure TReader.setLogMsg(const Value: AnsiString);
begin
	fLog := Value;
	Count := GetTickCount;
	WantRender := true;
end;

procedure TReader.setPage(const Value: TRPages);
var
	Old: TRPages;
begin
	if fActivePage <> Value then begin
		ReleaseSB;
		AddSB(SB_CLOSE , al_top, al_first);
		AddSB(SB_SEPAR , al_top, al_first);
//		if Value <> rp_chapter then AddSB(SB_SRVSYN, al_top, al_first);
		AddSB(SB_FULLS , al_top, al_first);
		if Value <> rp_chapter then AddSB(SB_CONT  , al_top, al_first);
		Old := fActivePage;
		fActivePage := Value;
		if Pages[Old] <> nil then Pages[Old].NavigateFrom(Value);
		Pages[Value].Size(Width, Height);
		Pages[Value].InitSB;
		Pages[Value].NavigateTo(Old);
		Pages[Value].CacheUpdated;
	end;
end;

procedure TReader.setSelected(const Value: Integer);
begin
	if fSelected <> Value then begin
		fSelected := Value;
		Plates.SelID := Value;
		if Value >= 0 then ScrollInView;
	end;
end;

procedure TReader.setSelID(const Value: Cardinal);
begin
	if fSeID <> Value then begin
		fSeID := Value;
		Selected := Plates.IndexOf(Value);
	end;
end;

procedure TReader.setWR(const Value: Boolean);
begin
	fWR := Value;
	if value then inc(fwc);
	if value and (GetTickCount - fwt >= 1000) then begin
		fwa := round((fwa + fwc) / 2);
		fwc := 0;
		fwt := GetTickCount;
	end;
end;

procedure TReader.WaitRenderSync;
begin
	while WaitForSingleObject(eRender, 1) = WAIT_TIMEOUT do ;
end;

end.
