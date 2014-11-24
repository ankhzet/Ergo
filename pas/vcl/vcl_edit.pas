unit vcl_edit;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	, vcl_application
	;

type
	TEdit       = class(TCustomCtl)
	private
		wdts      : array [byte] of Integer;
		bBg, bSG  : HBRUSH;
		pB1, pB2  : HPEN;
		fOnChange : TNotifyEvent;
		fSelLen   : Integer;
		fSelEnd   : Integer;
		fSelStart : Integer;
		Timer     : THandle;
		fBlink    : Cardinal;
		fDrag     : Boolean;
		procedure   setSelEnd(Value: Integer);
		procedure   setSelStart(Value: Integer);
	protected
		procedure   Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure   DoChanged; virtual;
		function    isShift: Boolean;
		function    isCtrl: Boolean;
		procedure   InitStyle(var s, e: Cardinal); override;
		procedure   InitClass(var C: TWndClass); override;
		procedure   WMLButtonDblClck(var M: TMessage); message WM_LBUTTONDBLCLK;
		procedure   WMLButtonDown(var M: TMessage); message WM_LBUTTONDOWN;
		procedure   WMLButtonUP(var M: TMessage); message WM_LBUTTONUP;
		procedure   WMMouseMove(var M: TMessage); message WM_MOUSEMOVE;
		procedure   WMChar(var M: TMessage); message WM_CHAR;
		procedure   WMKey(var M: TMessage); message WM_KEYDOWN;
		procedure   setTitle(const NewTitle: AnsiString); override;
	public
		constructor Create(Owner: TComponent); override;
		destructor  Destroy; override;
		property    OnChange: TNotifyEvent read fOnChange write fOnChange;
		property    SelStart: Integer read fSelStart write setSelStart;
		property    SelEnd: Integer read fSelEnd write setSelEnd;
		property    SelLen: Integer read fSelLen;
	end;

implementation
uses
		functions
	, strings
	, WinAPI_GDIInterface
	;

function EditBlinker(E: TEdit): Integer;
var
	t: Cardinal;
begin
	result := 0;
	try
		repeat
			t := GetTickCount;
			repeat
				sleep(10);
			until (GetTickCount - t >= 500) or App.Terminated;
			E.Invalidate;
		until App.Terminated;
	finally
		EndThread(0);
	end;
end;

{ TButton }

constructor TEdit.Create(Owner: TComponent);
var
	thid: Cardinal;
begin
	inherited;
	pB1 := CreatePen(PS_SOLID, 1, $A0A0A0);
	pB2 := CreatePen(PS_SOLID, 1, $FFd0c0);

	bBg := CreateSolidBrush($FFFFFF);
	bSg := CreateSolidBrush($202020);
{	DeleteObject(font);
	Font := CreateFont(14, 7, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_ONLY_PRECIS,
		CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE or VARIABLE_PITCH, 'Courier New'); }
	SelStart := 0;
	fBlink := GetTickCount;
	fDrag  := false;
	Timer := BeginThread(nil, 0, @EditBlinker, Pointer(Self), 0, thid);
end;

destructor TEdit.Destroy;
begin
	TerminateThread(Timer, 0);
	DeleteObject(bBg);
	DeleteObject(bSg);
	DeleteObject(pB1);
	DeleteObject(pB2);
	inherited;
end;

procedure TEdit.DoChanged;
begin
	if Assigned(OnChange) then OnChange(Self);
end;

procedure TEdit.InitClass(var C: TWndClass);
begin
	C.lpszClassName := 'nailec';
	C.hCursor := LoadCursor(0, IDC_IBEAM);
end;

procedure TEdit.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

function TEdit.isCtrl: Boolean;
begin
	result := GetKeyState(VK_CONTROL) and $80 <> 0;
end;

function TEdit.isShift: Boolean;
begin
	result := GetKeyState(VK_SHIFT) and $80 <> 0;
end;

procedure TEdit.Paint(DC: HDC; var PS: TPaintStruct);
var
	i, j, a, b: Integer;
	R: TRect;
	S: AnsiString;
begin
	S := Caption;
	for i := 1 to Length(S) do
		wdts[i] := TextWidth(DC, S[i]);

	if (cs_hover in State) or (cs_focused in State) then
		SelectObject(DC, pB2)
	else
		SelectObject(DC, pB1);
	SelectObject(DC, bBg);
	RoundRect(DC, 0, 0, Width, Height, 6, 6);
	SelectObject(DC, GetStockObject(NULL_BRUSH));
	SelectObject(DC, GetStockObject(BLACK_PEN));
	RoundRect(DC, 1, 1, Width - 1, Height - 1, 4, 4);

	R := Rect(0, 0, Width - 8, Height);
	inc(r.Left, 4);
	dec(r.Right, 4);
	SetTextColor(DC, $000000);
	DrawText(DC, PAnsiChar(S), Length(S), R, DT_SINGLELINE or DT_VCENTER or DT_LEFT);
	if cs_focused in State then begin
		i := imin(SelStart, SelEnd);
		j := imax(SelStart, SelEnd);
		if i <> 0 then 
			a := TextWidth(DC, copy(s, 1, i))
		else
			a := 0;

		if j - i <> 0 then begin
			s := copy(s, i + 1, j - i);
			b := a + TextWidth(DC, s);
		end else  
			b := a + 1;

		SelectObject(DC, GetStockObject(NULL_PEN));
		SelectObject(DC, bSG);
		Rectangle(DC, a + 4, 3, b + 4, Height - 2);
		if j > i then begin
			R := Rect(a + 4, 0, b + 5, Height);
			SetTextColor(DC, $FFFFFF);
			DrawText(DC, PAnsiChar(S), Length(S), R, DT_SINGLELINE or DT_LEFT or DT_VCENTER);
		end;

		if (GetTickCount - fBlink) mod 1000 < 500 then begin
			SelectObject(DC, GetStockObject(BLACK_PEN));
			if SelStart > SelEnd then a := b - 1;
			SetROP2(DC, R2_NOT);
			MoveToEx(DC, a + 4, 3, nil);
			LineTo(DC, a + 4, Height - 3);
			SetROP2(DC, R2_COPYPEN);
		end;
	end;
end;

procedure TEdit.setSelEnd(Value: Integer);
begin
	Value := imax(0, imin(Value, Length(Caption)));
	if fSelEnd <> Value then begin
		fSelEnd := Value;
		fSelLen := abs(Value - fSelStart);
		Invalidate;
	end;
end;

procedure TEdit.setSelStart(Value: Integer);
begin
	Value := imax(0, imin(Value, Length(Caption)));
	if fSelStart <> Value then begin
		fSelStart := Value;
		if not isShift then fSelEnd := Value;
		fSelLen   := abs(fSelEnd - fSelStart);
		Invalidate;
	end else
		if (not isShift) and (fSelEnd <> Value) then begin
			fSelEnd := Value;
			Invalidate;
		end;
	fBlink := GetTickCount;
end;

procedure TEdit.setTitle(const NewTitle: AnsiString);
var
	b: Boolean;
begin
	b := NewTitle <> Caption;
	inherited;
	if b then DoChanged;
end;

procedure TEdit.WMChar(var M: TMessage);
var
	c, t: AnsiString;
	s: Cardinal;
	h: THandle;
begin
	if ReadOnly then exit;
	if isCtrl then begin
		case M.WParam of
			03: begin //Ctrl+C
				if SelLen = 0 then exit;
{				c := System.Copy(c, imin(SelStart, SelEnd) + 1, SelLen);
				SetClipboardData(CF_TEXT, Cardinal(@c[1]));    }
			end;
			22: begin //Ctrl+V
{				if not (IsClipboardFormatAvailable(CF_TEXT) or
					 IsClipboardFormatAvailable(CF_UNICODETEXT) or
					 IsClipboardFormatAvailable(CF_OEMTEXT)) then exit; }
				OpenClipboard(Handle);
				try
					c := Caption;
					s := GetClipboardData(CF_TEXT);
					if SelLen <> 0 then System.Delete(c, imin(SelStart, SelEnd) + 1, SelLen);
					System.Insert(PAnsiChar(s), c, imin(SelStart, SelEnd) + 1);
					Caption := c;
					SelStart := imin(SelStart, SelEnd) + StrLen(PAnsiChar(s));
					fSelLen := 0;
					fSelEnd := fSelStart;
				finally
					CloseClipboard;
				end;
			end;
			24: begin //Ctrl+X
				if (SelLen = 0) {or not OpenClipboard(Handle)} then exit;
{				c := Caption;
				t := System.Copy(c, imin(SelStart, SelEnd) + 1, SelLen);
				h := GlobalAlloc(GMEM_MOVEABLE, Length(t) + 1);
				if h = 0 then exit;
				s := Cardinal(GlobalLock(h));
				Move(t[1], Pointer(s)^, Length(t) + 1);
				GlobalUnlock(h);
				SetClipboardData(CF_TEXT, h);
				System.Delete(c, imin(SelStart, SelEnd) + 1, SelLen);
				fSelEnd := imin(fSelStart, fSelEnd);
				fSelStart := fSelEnd;
				fSelLen := 0;
				Caption := c;  }
			end;
		end;
		exit;
	end;
	case M.WParam of
		VK_BACK  : ;
		VK_RETURN: ;
		else
			c := Caption;
			if SelLen <> 0 then System.Delete(c, imin(SelStart, SelEnd) + 1, SelLen);
			System.Insert(AnsiChar(M.WParam), c, imin(SelStart, SelEnd) + 1);
			Caption := c;
			SelStart := imin(SelStart, SelEnd) + 1;
			fSelLen := 0;
			fSelEnd := fSelStart;
	end;
end;

procedure TEdit.WMKey(var M: TMessage);
var
	c: AnsiString;
begin
	case M.WParam of
		VK_BACK  : begin
			if ReadOnly then exit;
			c := Caption;
			if SelLen <> 0 then System.Delete(c, imin(SelStart, SelEnd) + 1, SelLen);
			if SelLen = 0 then begin
				System.Delete(c, SelStart, 1);
				SelStart := SelStart - 1;
			end;
			fSelEnd := imin(fSelStart, fSelEnd);
			fSelStart := fSelEnd;
			fSelLen := 0;
			Caption := c;
		end;
		VK_DELETE: begin
			if ReadOnly then exit;
			c := Caption;
			if SelLen <> 0 then System.Delete(c, imin(SelStart, SelEnd) + 1, SelLen);
			if SelLen = 0 then begin
				System.Delete(c, SelStart + 1, 1);
			end;
			fSelEnd := imin(fSelStart, fSelEnd);
			fSelStart := fSelEnd;
			fSelLen := 0;
			Caption := c;
		end;
		VK_LEFT  : SelStart := SelStart - 1;
		VK_RIGHT : SelStart := SelStart + 1;
		VK_HOME  : SelStart := 0;
		VK_END   : SelStart := Length(c);
		else exit;
	end;
end;

procedure TEdit.WMLButtonDblClck(var M: TMessage);
begin
	fSelEnd := 0;
	fSelStart := Length(Caption);
	fSelLen := fSelStart;
	inherited;
end;

procedure TEdit.WMLButtonDown(var M: TMessage);
var
	i, j, k: Integer;
	c      : AnsiString;
begin
	k := 2;
	c := Caption;
	j := Length(c);
	for i := 0 to j - 1 do begin
		inc(k, wdts[i]);
		if k + wdts[i + 1] div 2 >= M.XPos then break;
	end;

	fSelEnd := i;
	fSelStart := i;
	fSelLen := 0;
	fBlink := GetTickCount;
	fDrag  := true;
	inherited;
end;

procedure TEdit.WMLButtonUP(var M: TMessage);
begin
	fDrag := false;
	inherited;
end;

procedure TEdit.WMMouseMove(var M: TMessage);
var
	i, j, k: Integer;
	c      : AnsiString;
begin
	if not fDrag then exit;
	k := 2;
	c := Caption;
	j := Length(c);
	for i := 0 to j - 1 do begin
		inc(k, wdts[i]);
		if k + wdts[i + 1] div 2 >= M.XPos then break;
	end;

	fSelStart := i;
	fSelLen := Abs(fSelEnd - SelStart);
	fBlink := GetTickCount;
	inherited;
end;

end.
