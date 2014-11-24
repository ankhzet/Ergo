unit vcl_control;
interface
uses
		WinAPI
	, vcl_components
	, vcl_messages
	;

type
	TNotifyEvent = procedure (Sender: TObject) of object;
	TWndMethod  = procedure(var Message: TMessage) of object;
	PObjectInstance =^TObjectInstance;
	TObjectInstance = packed record
		Code          : Byte;
		Offset        : Integer;
		case Integer of
			0: (Next    : PObjectInstance);
			1: (Method  : TWndMethod);
	end;

	TCtlStates   = (cs_hover, cs_pushed, cs_focused);
	TCtlState    = Set of TCtlStates;

	TControl    = class(TComponent)
	private
		fHandle   : HWnd;
		fOjInst   : PObjectInstance;
		fBorderW  : Integer;
		fBorderH  : Integer;
		fCaption  : AnsiString;
		fShowSize : Boolean;
		fParent   : TControl;
		fWidth    : Integer;
		fHeight   : Integer;
		fTop      : Integer;
		fLeft     : Integer;
		fState    : TCtlState;
		fOnResize : TNotifyEvent;
		fOnClick  : TNotifyEvent;
		fFocused  : Boolean;
		fVisible  : Boolean;
		fTag      : Integer;
		fROnly    : Boolean;
		procedure   setHeight(const Value: Integer);
		procedure   setWidth(const Value: Integer);
		procedure   MainWndProc(var Message: TMessage);
		procedure   WndProc(var Message: TMessage);
		function    getTitle: AnsiString;
		procedure   Broadcast(M: TMessage);
		procedure   setParent(const Value: TControl);
		procedure   setLeft(const Value: Integer);
		procedure   setTop(const Value: Integer);
		procedure   setState(const Value: TCtlState);
		procedure   setFocused(const Value: Boolean);
		procedure   setVisible(const Value: Boolean);
	protected
		procedure   CreateHandle; virtual;
		function    MouseInRect(M: TMessage): Boolean;
		procedure   WMLButtonDown(var M: TMessage); message WM_LBUTTONDOWN;
		procedure   WMLButtonUP(var M: TMessage); message WM_LBUTTONUP;
		procedure   WMLButtonDblClick(var M: TMessage); message WM_LBUTTONDBLCLK;
		procedure   WMMouseMove(var M: TMessage); message WM_MOUSEMOVE;
		procedure   InitClass(var C: TWndClass); virtual;
		procedure   InitStyle(var s, e: Cardinal); virtual;

		procedure   DoClick; virtual;
		property    BorderW: Integer read fBorderW;
		property    BorderH: Integer read fBorderH;
		procedure   setTitle(const NewTitle: AnsiString); virtual;
	public
		constructor Create(AOwner: TComponent); override;
		destructor  Destroy; override;
		procedure   DefaultHandler(var Message); override;
		procedure   Invalidate;
		procedure   Validate;
		procedure   Init; virtual;
		function    Perform(Msg: Cardinal; WParam, LParam: Integer): LongInt;
		function    Handle: HWnd;
		function    Cursor: TPoint;
		procedure   PutMouse(Pos: TPoint); overload;
		procedure   PutMouse(X, Y: Integer); overload;
		procedure   Resize; virtual;
		procedure   DoReSize(const NewWidth, NewHeight: Integer);
		property    Parent: TControl read fParent write setParent;
		property    Caption: AnsiString read getTitle write setTitle;
		property    Width: Integer read fWidth write setWidth;
		property    Height: Integer read fHeight write setHeight;
		property    Left: Integer read fLeft write setLeft;
		property    Top: Integer read fTop write setTop;
		property    Focused: Boolean read fFocused write setFocused;
		property    ShowSize: Boolean read fShowSize write fShowSize;
		property    Visible: Boolean read fVisible write setVisible;
		property    ReadOnly: Boolean read fROnly write fROnly;

		property    State: TCtlState read fState write setState;
		property    OnResize: TNotifyEvent read fOnResize write fOnResize;
		property    OnClick: TNotifyEvent read fOnClick write fOnClick;
		property    Tag: Integer read fTag write fTag;
	end;
	TBrush      = class(TComponent)
	private
		OldBrush  : HBrush;
		fColor    : TColor;
		fHandle   : HBRUSH;
		procedure   setColor(const Value: TColor);
		procedure   setHandle(const Value: HBRUSH);
	public
		constructor Create(AOwner: TComponent); override;
		destructor  Destroy; override;
		property    Handle: HBRUSH read fHandle write setHandle;
		property    Color: TColor read fColor write setColor;
	end;
	TCustomCtl  = class(TControl)
	private
		fBrush    : TBrush;
	protected
		Font      : HFont;
		procedure   WMEraseBcknd(var M: TMessage); message WM_ERASEBKGND;
		procedure   WMPaint(var M: TMessage); message WM_PAINT;
		procedure   Paint(DC: HDC; var PS: TPaintStruct); virtual;
	public
		constructor Create(Owner: TComponent); override;
		destructor  Destroy; override;
		property    Brush: TBrush read fBrush;
	end;
	TStaticCtl  = class(TCustomCtl)
	protected
		procedure   WMLButtonDown(var M: TMessage); message WM_LBUTTONDOWN;
		procedure   WMLButtonUP(var M: TMessage); message WM_LBUTTONUP;
		procedure   WMLButtonDblClick(var M: TMessage); message WM_LBUTTONDBLCLK;
		procedure   WMMouseMove(var M: TMessage); message WM_MOUSEMOVE;
	end;

var
	CtlHover: TControl = nil;

const

	WS_OVERLAPPED = 0;
  {$EXTERNALSYM WS_POPUP}
  WS_POPUP = DWORD($80000000);
  {$EXTERNALSYM WS_CHILD}
  WS_CHILD = $40000000;
  {$EXTERNALSYM WS_MINIMIZE}
  WS_MINIMIZE = $20000000;
  {$EXTERNALSYM WS_VISIBLE}
  WS_VISIBLE = $10000000;
  {$EXTERNALSYM WS_DISABLED}
  WS_DISABLED = $8000000;
  {$EXTERNALSYM WS_CLIPSIBLINGS}
  WS_CLIPSIBLINGS = $4000000;
  {$EXTERNALSYM WS_CLIPCHILDREN}
  WS_CLIPCHILDREN = $2000000;
  {$EXTERNALSYM WS_MAXIMIZE}
  WS_MAXIMIZE = $1000000;
  {$EXTERNALSYM WS_CAPTION}
  WS_CAPTION = $C00000;      { WS_BORDER or WS_DLGFRAME  }
  {$EXTERNALSYM WS_BORDER}
  WS_BORDER = $800000;
  {$EXTERNALSYM WS_DLGFRAME}
  WS_DLGFRAME = $400000;
  {$EXTERNALSYM WS_VSCROLL}
  WS_VSCROLL = $200000;
  {$EXTERNALSYM WS_HSCROLL}
  WS_HSCROLL = $100000;
  {$EXTERNALSYM WS_SYSMENU}
  WS_SYSMENU = $80000;
  {$EXTERNALSYM WS_THICKFRAME}
  WS_THICKFRAME = $40000;
  {$EXTERNALSYM WS_GROUP}
  WS_GROUP = $20000;
  {$EXTERNALSYM WS_TABSTOP}
  WS_TABSTOP = $10000;

  {$EXTERNALSYM WS_MINIMIZEBOX}
  WS_MINIMIZEBOX = $20000;
  {$EXTERNALSYM WS_MAXIMIZEBOX}
  WS_MAXIMIZEBOX = $10000;

  {$EXTERNALSYM WS_TILED}
  WS_TILED = WS_OVERLAPPED;
  {$EXTERNALSYM WS_ICONIC}
  WS_ICONIC = WS_MINIMIZE;
  {$EXTERNALSYM WS_SIZEBOX}
  WS_SIZEBOX = WS_THICKFRAME;

  { Common Window Styles }
  {$EXTERNALSYM WS_OVERLAPPEDWINDOW}
  WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or
    WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX);
  {$EXTERNALSYM WS_TILEDWINDOW}
  WS_TILEDWINDOW = WS_OVERLAPPEDWINDOW;
  {$EXTERNALSYM WS_POPUPWINDOW}
  WS_POPUPWINDOW = (WS_POPUP or WS_BORDER or WS_SYSMENU);
  {$EXTERNALSYM WS_CHILDWINDOW}
  WS_CHILDWINDOW = (WS_CHILD);

  { Extended Window Styles }
  {$EXTERNALSYM WS_EX_DLGMODALFRAME}
  WS_EX_DLGMODALFRAME = 1;
  {$EXTERNALSYM WS_EX_NOPARENTNOTIFY}
  WS_EX_NOPARENTNOTIFY = 4;
  {$EXTERNALSYM WS_EX_TOPMOST}
  WS_EX_TOPMOST = 8;
  {$EXTERNALSYM WS_EX_ACCEPTFILES}
  WS_EX_ACCEPTFILES = $10;
  {$EXTERNALSYM WS_EX_TRANSPARENT}
  WS_EX_TRANSPARENT = $20;
  {$EXTERNALSYM WS_EX_MDICHILD}
  WS_EX_MDICHILD = $40;
  {$EXTERNALSYM WS_EX_TOOLWINDOW}
  WS_EX_TOOLWINDOW = $80;
  {$EXTERNALSYM WS_EX_WINDOWEDGE}
  WS_EX_WINDOWEDGE = $100;
  {$EXTERNALSYM WS_EX_CLIENTEDGE}
  WS_EX_CLIENTEDGE = $200;
  {$EXTERNALSYM WS_EX_CONTEXTHELP}
  WS_EX_CONTEXTHELP = $400;

  {$EXTERNALSYM WS_EX_RIGHT}
  WS_EX_RIGHT = $1000;
  {$EXTERNALSYM WS_EX_LEFT}
  WS_EX_LEFT = 0;
  {$EXTERNALSYM WS_EX_RTLREADING}
  WS_EX_RTLREADING = $2000;
  {$EXTERNALSYM WS_EX_LTRREADING}
  WS_EX_LTRREADING = 0;
  {$EXTERNALSYM WS_EX_LEFTSCROLLBAR}
  WS_EX_LEFTSCROLLBAR = $4000;
  {$EXTERNALSYM WS_EX_RIGHTSCROLLBAR}
  WS_EX_RIGHTSCROLLBAR = 0;

  {$EXTERNALSYM WS_EX_CONTROLPARENT}
  WS_EX_CONTROLPARENT = $10000;
  {$EXTERNALSYM WS_EX_STATICEDGE}
  WS_EX_STATICEDGE = $20000;
  {$EXTERNALSYM WS_EX_APPWINDOW}
  WS_EX_APPWINDOW = $40000;
  {$EXTERNALSYM WS_EX_OVERLAPPEDWINDOW}
  WS_EX_OVERLAPPEDWINDOW = (WS_EX_WINDOWEDGE or WS_EX_CLIENTEDGE);
  {$EXTERNALSYM WS_EX_PALETTEWINDOW}
  WS_EX_PALETTEWINDOW = (WS_EX_WINDOWEDGE or WS_EX_TOOLWINDOW or WS_EX_TOPMOST);

  {$EXTERNALSYM WS_EX_LAYERED}
  WS_EX_LAYERED = $00080000;
  {$EXTERNALSYM WS_EX_NOINHERITLAYOUT}
  WS_EX_NOINHERITLAYOUT = $00100000; // Disable inheritence of mirroring by children
  {$EXTERNALSYM WS_EX_LAYOUTRTL}
  WS_EX_LAYOUTRTL = $00400000; // Right to left mirroring
  {$EXTERNALSYM WS_EX_COMPOSITED}
  WS_EX_COMPOSITED = $02000000;
  {$EXTERNALSYM WS_EX_NOACTIVATE}
  WS_EX_NOACTIVATE = $08000000;

  { Class styles }
  {$EXTERNALSYM CS_VREDRAW}
  CS_VREDRAW = DWORD(1);
  {$EXTERNALSYM CS_HREDRAW}
  CS_HREDRAW = DWORD(2);
  {$EXTERNALSYM CS_KEYCVTWINDOW}
  CS_KEYCVTWINDOW = 4;
  {$EXTERNALSYM CS_DBLCLKS}
  CS_DBLCLKS = 8;
  {$EXTERNALSYM CS_OWNDC}
  CS_OWNDC = $20;
  {$EXTERNALSYM CS_CLASSDC}
  CS_CLASSDC = $40;
  {$EXTERNALSYM CS_PARENTDC}
  CS_PARENTDC = $80;
  {$EXTERNALSYM CS_NOKEYCVT}
  CS_NOKEYCVT = $100;
  {$EXTERNALSYM CS_NOCLOSE}
  CS_NOCLOSE = $200;
  {$EXTERNALSYM CS_SAVEBITS}
  CS_SAVEBITS = $800;
  {$EXTERNALSYM CS_BYTEALIGNCLIENT}
  CS_BYTEALIGNCLIENT = $1000;
  {$EXTERNALSYM CS_BYTEALIGNWINDOW}
  CS_BYTEALIGNWINDOW = $2000;
  {$EXTERNALSYM CS_GLOBALCLASS}
  CS_GLOBALCLASS = $4000;

  {$EXTERNALSYM CS_IME}
  CS_IME = $10000;
  {$EXTERNALSYM CS_DROPSHADOW}
  CS_DROPSHADOW = $20000;


  MEM_COMMIT = $1000;
  PAGE_EXECUTE_READWRITE = $40;

function ClrToRGB(c: TColor): Cardinal;

implementation
uses
	functions, strings, WinAPI_GDIInterface;

function ClrToRGB(c: TColor): Cardinal;
begin
	if c and clSystemColor = clSystemColor then
		result := GetSysColor((not clSystemColor) and c)
	else
		result := c;
end;

function VirtualAlloc(lpvAddress: Pointer; dwSize, flAllocationType, flProtect: DWORD): Pointer; stdcall; external 'kernel32.dll' name 'VirtualAlloc';

const
	InstanceCount = $FF;

type
	PInstanceBlock  =^TInstanceBlock;
	TInstanceBlock  = packed record
		Next          : PInstanceBlock;
		Code          : array[1..2] of Byte;
		WndProcPtr    : Pointer;
		Instances     : array[0..InstanceCount] of TObjectInstance;
	end;

var
	InstBlockList   : PInstanceBlock = nil;
	InstFreeList    : PObjectInstance = nil;

function StdWndProc(Window: HWND; Message, WParam: Longint;
  LParam: Longint): Longint; stdcall; assembler;
asm
        XOR     EAX,EAX
        PUSH    EAX
        PUSH    LParam
        PUSH    WParam
        PUSH    Message
        MOV     EDX,ESP
        MOV     EAX,[ECX].Longint[4]
        CALL    [ECX].Pointer
        ADD     ESP,12
        POP     EAX
end;

function CalcJmpOffset(Src, Dest: Pointer): Longint;
begin
  Result := Longint(Dest) - (Longint(Src) + 5);
end;

function MakeObjectInstance(Method: TWndMethod): Pointer;
const
  BlockCode: array[1..2] of Byte = (
    $59,       { POP ECX }
    $E9);      { JMP StdWndProc }
  PageSize = 4096;
var
  Block: PInstanceBlock;
  Instance: PObjectInstance;
begin
  if InstFreeList = nil then
  begin
		Block := VirtualAlloc(nil, PageSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    Block^.Next := InstBlockList;
    Move(BlockCode, Block^.Code, SizeOf(BlockCode));
		Block^.WndProcPtr := Pointer(CalcJmpOffset(@Block^.Code[2], @StdWndProc));
    Instance := @Block^.Instances;
    repeat
      Instance^.Code := $E8;  { CALL NEAR PTR Offset }
      Instance^.Offset := CalcJmpOffset(Instance, @Block^.Code);
      Instance^.Next := InstFreeList;
      InstFreeList := Instance;
      Inc(Longint(Instance), SizeOf(TObjectInstance));
    until Longint(Instance) - Longint(Block) >= SizeOf(TInstanceBlock);
    InstBlockList := Block;
  end;
  Result := InstFreeList;
  Instance := InstFreeList;
  InstFreeList := Instance^.Next;
  Instance^.Method := Method;
end;

procedure FreeObjectInstance(ObjectInstance: Pointer);
begin
  if ObjectInstance <> nil then
  begin
    PObjectInstance(ObjectInstance)^.Next := InstFreeList;
    InstFreeList := ObjectInstance;
  end;
end;

{ TWindow }

procedure TControl.Broadcast(M: TMessage);
var
	m1: TMessage;
	i : Integer;
begin
	for i := 0 to Components - 1 do begin
		m1 := M;
		TControl(Component[i]).Dispatch(m1);
	end;
end;

constructor TControl.Create(AOwner: TComponent);
begin
	inherited;
	fOjInst   := MakeObjectInstance(MainWndProc);
	fHandle   := 0;
	fShowSize := false;
	if (Owner <> nil) and (Owner is TControl) then
		Parent := TControl(Owner);
	Init;
	CreateHandle;
	Invalidate;
end;

destructor TControl.Destroy;
begin
	if Handle  <> 0 then DestroyWindow(Handle);
	if fOjInst <> nil then FreeObjectInstance(fOjInst);
	inherited;
end;

procedure TControl.DoClick;
begin
	if Assigned(OnClick) then OnClick(Self);
end;

procedure TControl.MainWndProc(var Message: TMessage);
begin
	try
		WndProc(Message);
	except

	end;
end;

function TControl.MouseInRect(M: TMessage): Boolean;
begin
	with M do
		MouseInRect := (XPos >= 0) and (YPos >= 0) and (XPos < Width) and (YPos < Height);
end;

procedure TControl.WMLButtonDblClick(var M: TMessage);
begin
	WMLButtonDown(M);
end;

procedure TControl.WMLButtonDown(var M: TMessage);
begin
	SetCapture(Handle);
	State := State + [cs_pushed];
	SetFocus(Handle);
end;

procedure TControl.WMLButtonUP(var M: TMessage);
begin
	ReleaseCapture;
	if State * [cs_pushed, cs_hover] = [cs_pushed, cs_hover] then DoClick;
	State := State - [cs_pushed];
end;

procedure TControl.WMMouseMove(var M: TMessage);
var
	s: TCtlState;
begin
	s := State;
	if MouseInRect(M) then begin
		Include(s, cs_hover);
		if CtlHover <> nil then
			CtlHover.State := CtlHover.State - [cs_hover];
		CtlHover := Self;
	end else begin
		Exclude(s, cs_hover);
		if CtlHover = Self then
			CtlHover := nil;
	end;
	if cs_hover in s then
//		SetCapture(Handle)
	else
		if not (cs_pushed in s) then
			//ReleaseCapture
			;
	State := s;
end;

procedure TControl.WndProc(var Message: TMessage);
begin
	Dispatch(Message);
end;

procedure TControl.DoReSize(const NewWidth, NewHeight: Integer);
var
	S: AnsiString;
begin
	S := Caption;
	SetWindowPos(fHandle, 0, 0, 0, NewWidth + fBorderW, NewHeight + fBorderH, SWP_NOMOVE);
	Caption := S;
end;

procedure TControl.InitClass(var C: TWndClass);
begin
end;

procedure TControl.InitStyle(var s, e: Cardinal);
begin
end;

procedure TControl.Invalidate;
var
	R: TRect;
//	i: Integer;
begin
	GetClientRect(Handle, R);
	InvalidateRect(handle, R, false);
{	for i := 0 to Components - 1 do begin
		GetClientRect(TControl(Component[i]).Handle, R);
		ValidateRect(Handle, @R);
	end; }
end;

procedure TControl.Validate;
begin
	ValidateRect(handle, nil);
end;

procedure TControl.CreateHandle;
const
	clname: PAnsiChar = 'nailwc';
var
	wc: TWNDCLASS;
	cr: TRect;
	st: Cardinal;
	et: Cardinal;
	p : HWND;
begin
	if fHandle <> 0 then DestroyWindow(fHandle);

	with WC do begin
		style        := CS_DBLCLKS or CS_OWNDC;
		lpfnWndProc  := @DefWindowProc;
		cbClsExtra   := 0;
		cbWndExtra   := 0;
		hCursor      := LoadCursor(0, IDC_ARROW);
		hbrBackground:= 0;
		lpszMenuName := '';
		lpszClassName:= clname;
	end;
	wc.hInstance   := hInstance;
	wc.hIcon       := LoadIcon(hInstance, 'MAINICON');
	InitClass(wc);
	if not GetClassInfo(HInstance, wc.lpszClassName, wc) then
		if RegisterClass(wc) = 0 then
			raise Exception.Create('VCL: Register window class "%s" failed', [wc.lpszClassName]);

	st := WS_VISIBLE or WS_BORDER;
	if Parent <> nil then st := st or WS_CHILD;
	et := 0;
	InitStyle(st, et);
	fVisible := st and WS_VISIBLE <> 0;
	st := st xor WS_VISIBLE;
	if Parent <> nil then p := Parent.Handle else p := 0;

	fHandle := CreateWindowEx(et, wc.lpszClassName, PAnsiChar(Caption), st, Left, Top, Width, Height, p, 0, hInstance, nil);
	if fHandle = 0 then raise
		Exception.Create('VCL: Create window failed');
	SetWindowLong(fHandle, GWL_WNDPROC, Longint(fOjInst));

	GetClientRect(fHandle, cr);
	fBorderW := Width  - cr.Right;
	fBorderH := Height - cr.Bottom;
	DoReSize(Width, Height);
	if fVisible then ShowWindow(Handle, SW_SHOW);
end;

function ifelse(cond: boolean; a, b: ansistring): ansistring;
begin
	if cond then result := a else result := b;
end;

procedure TControl.DefaultHandler(var Message);
var
	s: AnsiString;
	b: boolean;
begin
	with TMessage(Message) do
		case Msg of
			WM_MOVE         : begin
				b := (fLeft <> LParLo) or (fTop <> LParHi);
				if b then begin
					fLeft   := LParLo;
					fTop    := LParHi;
				end;
			end;
			WM_SIZE         : begin
				b := (fWidth <> LParLo) or (fHeight <> LParHi);
				if b then begin
					fWidth  := LParLo;
					fHeight := LParHi;
					Resize;
				end;
			end;
			WM_SETFOCUS     : Focused := true;
			WM_KILLFOCUS    : Focused := false;
			WM_GETTEXTLENGTH: result := Length(fCaption);
			WM_GETTEXT      : begin
				Result := Length(fCaption);
				if WParam < Result then Result := WParam;
				if Result > 0 then Move(fCaption[1], PChar(LParam)^, Result);
			end;
			WM_SETTEXT      : begin
				Result := StrLen(PChar(LParam));
				setLength(fCaption, Result);
				if Result > 0 then Move(PChar(LParam)^, fCaption[1], Result);
				s := ifelse(fShowSize, fCaption + ' (' +
					ifelse(fWidth * fHeight = 0, 'minimized', Format('%dx%d', [fWidth, fHeight])) + ')',
					fCaption
				);
				DefWindowProc(fHandle, Msg, 0, LongInt(PChar(S)));
			end;
			else Result := DefWindowProc(fHandle, Msg, WParam, LParam);
		end;
end;

function TControl.Handle: HWnd;
begin
	result := fHandle;
end;

procedure TControl.Init;
begin
end;

function TControl.getTitle: AnsiString;
var
	Len: Integer;
begin
	result := '';
	Len := Perform(WM_GETTEXTLENGTH, 0, 0);
	SetString(result, nil, Len);
	if Len <> 0 then Perform(WM_GETTEXT, Len + 1, LongInt(Result));
end;

procedure TControl.setFocused(const Value: Boolean);
begin
	if fFocused <> Value then begin
		fFocused := Value;
		if Value then Include(fState, cs_focused) else Exclude(fState, cs_focused);
		if Value then SetFocus(Handle);
		Invalidate;
	end;
end;

procedure TControl.setHeight(const Value: Integer);
begin
	if fHeight <> Value then begin
		fHeight := Value;
		DoReSize(fWidth, fHeight);
	end;
end;

procedure TControl.setLeft(const Value: Integer);
begin
	if fLeft <> Value then begin
		fLeft := Value;
		SetWindowPos(fHandle, 0, fLeft, fTop, 0, 0, SWP_NOSIZE or SWP_NOZORDER);
	end;
end;

procedure TControl.setTop(const Value: Integer);
begin
	if fTop <> Value then begin
		fTop := Value;
		SetWindowPos(fHandle, 0, fLeft, fTop, 0, 0, SWP_NOSIZE or SWP_NOZORDER);
	end;
end;

procedure TControl.setVisible(const Value: Boolean);
begin
	if fVisible <> Value then begin
		fVisible := Value;
		if Value then
			ShowWindow(Handle, SW_SHOW)
		else
			ShowWindow(Handle, SW_HIDE);
	end;
end;

procedure TControl.setWidth(const Value: Integer);
begin
	if fWidth <> Value then begin
		fWidth := Value;
		DoReSize(fWidth, fHeight);
	end;
end;

procedure TControl.setParent(const Value: TControl);
begin
	if fParent <> Value then begin
		fParent := Value;
		if (Value <> nil) and (Handle <> 0) then begin
			WinAPI.SetParent(Handle, Value.Handle);
		end;
	end;
end;

procedure TControl.setState(const Value: TCtlState);
begin
	if fState <> Value then begin
		fState := Value;
		Invalidate;
	end;
end;

procedure TControl.setTitle(const NewTitle: AnsiString);
begin
	if NewTitle <> Caption then begin
		Perform(WM_SETTEXT, 0, LongInt(PChar(@NewTitle[1])));
		Invalidate;
	end;
end;

function TControl.Perform(Msg: Cardinal; WParam, LParam: Integer): LongInt;
var
	M: TMessage;
begin
	M.Msg    := Msg;
	M.WParam := WParam;
	M.LParam := LParam;
	M.Result := 0;
	if Self <> nil then MainWndProc(M);
	result   := M.Result;
end;

procedure TControl.PutMouse(X, Y: Integer);
var
	p: TPoint;
begin
	p.X := X;
	p.Y := Y;
	ClientToScreen(fHandle, P);
	SetCursorPos(P.X, P.Y);
end;

procedure TControl.Resize;
begin
	if Assigned(fOnResize) then fOnResize(Self);
end;

function TControl.Cursor: TPoint;
begin
	GetCursorPos(result);
	ScreenToClient(fHandle, result);
end;

procedure TControl.PutMouse(Pos: TPoint);
begin
	ClientToScreen(fHandle, Pos);
	SetCursorPos(Pos.X, Pos.Y);
end;

{ TBrush }

constructor TBrush.Create(AOwner: TComponent);
begin
	inherited;
	Color := clBtnFace;
end;

destructor TBrush.Destroy;
begin
	Handle := 0;
	inherited;
end;

procedure TBrush.setColor(const Value: TColor);
var
	c: Cardinal;
begin
	if fColor <> Value then begin
		fColor := Value;
		if Value and clSystemColor = clSystemColor then
			c := GetSysColor((not clSystemColor) and Value)
		else
			c := Value;
		Handle := CreateSolidBrush(c);
	end;
end;

procedure TBrush.setHandle(const Value: HBRUSH);
var
	h : HWND;
	DC: HDC;
begin
	if fHandle <> Value then begin
		h  := TControl(Owner).Handle;
		if h <> 0 then begin
			DC := GetDC(h);
			SelectObject(DC, OldBrush);
		end;
		DeleteObject(fHandle);
		if h <> 0 then begin
			SelectObject(DC, Value);
			ReleaseDC(H, DC);
		end;
		fHandle := Value;
	end;
end;

{ TCustomCtl }

constructor TCustomCtl.Create(Owner: TComponent);
begin
	inherited;
	fBrush := TBrush.Create(Self);
	Font := CreateFont(14, 5, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_ONLY_PRECIS,
		CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE or VARIABLE_PITCH, 'MS Sans Serif');
end;

destructor TCustomCtl.Destroy;
begin
	DeleteObject(Font);
	inherited;
end;

procedure TCustomCtl.Paint(DC: HDC; var PS: TPaintStruct);
begin

end;

procedure TCustomCtl.WMEraseBcknd(var M: TMessage);
begin
	M.result := 0;
end;

procedure TCustomCtl.WMPaint(var M: TMessage);
var
	DC: HDC;
	TDC: HDC;
	OBM, TBM: HBITMAP;
	OBr: HBRUSH;
	OFn: HFONT;
	PS: TPaintStruct;
//	i: Integer;
begin
	DC := BeginPaint(Handle, PS);
	TDC := CreateCompatibleDC(DC);
	TBM := CreateCompatibleBitmap(DC, Width, Height);
	OBM := SelectObject(TDC, TBM);
	OBr := SelectObject(TDC, Brush.Handle);
	OFn := SelectObject(TDC, Font);
	SetBkMode(TDC, TRANSPARENT);

	try

		if PS.fErase then
			with PS.rcPaint do
				PatBlt(TDC, Left, Top, Right - Left, Bottom - Top, PATCOPY);

{		for i := 0 to Components - 1 do
			with TControl(Component[i]) do
				ExcludeClipRect(TDC, Left, Top, Left + Width, Top + Height); }

		Paint(TDC, PS);

		with PS.rcPaint do
			BitBlt(DC, Left, Top, Right - Left, Bottom - Top, TDC, Left, Top, SRCCOPY);
	finally
		SelectObject(TDC, OFn);
		SelectObject(TDC, OBr);
		SelectObject(TDC, OBM);
		DeleteObject(TBM);
		DeleteDC(TDC);
	end;
	EndPaint(Handle, PS);
end;

{ TStaticCtl }

procedure TStaticCtl.WMLButtonDblClick(var M: TMessage);
begin

end;

procedure TStaticCtl.WMLButtonDown(var M: TMessage);
begin

end;

procedure TStaticCtl.WMLButtonUP(var M: TMessage);
begin

end;

procedure TStaticCtl.WMMouseMove(var M: TMessage);
begin

end;

end.
