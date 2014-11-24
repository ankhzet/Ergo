unit WinAPI_GDIInterface;
interface
uses
	WinAPI;


//procedure ImbaPlate(DC: HDC; X1, Y1, X2, Y2, O: Integer; B1, B2: HBrush; Q: Integer = 5);
//procedure TextOut(DC: HDC; T: AnsiString; X, Y, W, H: Integer; F: Integer = DT_Center or DT_Singleline or DT_Vcenter);
//procedure OutlinedText(DC: HDC; Text: AnsiString; X, Y, W, H, F: Integer; C1, C2: Cardinal);
function  TextWidth(DC: HDC; T: AnsiString): Integer;

(**)

{ $REGION 'WinAPI'}

function GetDC(hWnd: HWND): HDC; stdcall;
function ReleaseDC(hWnd: HWND; hDC: HDC): Integer; stdcall;
function SwapBuffers(DC: HDC): BOOL; stdcall;
function ValidateRect(hWnd: HWND; lpRect: PRect): BOOL; stdcall;

function ExcludeClipRect(DC: HDC; LeftRect, TopRect, RightRect, BottomRect: Integer): Integer; stdcall;
function GetStockObject(Index: Integer): HGDIOBJ; stdcall;
function DeleteObject(p1: THandle): BOOL; stdcall;
function SetDIBits(DC: HDC; Bitmap: HBITMAP; StartScan, NumScans: UINT; Bits: Pointer; var BitsInfo: TBitmapInfo; Usage: UINT): Integer; stdcall;
function CreateCompatibleDC(DC: HDC): HDC; stdcall;
function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP; stdcall;
function SelectObject(DC: HDC; p2: THandle): THandle; stdcall;
function Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): BOOL; stdcall;
function SetBkColor(DC: HDC; Color: Cardinal): Cardinal; stdcall;
function SetBkMode(DC: HDC; BkMode: Integer): Integer; stdcall;
function SetTextColor(DC: HDC; Color: Cardinal): Cardinal; stdcall;
function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
	XSrc, YSrc: Integer; Rop: DWORD): BOOL; stdcall;
function StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc, SrcWidth, SrcHeight: Integer; Rop: DWORD): BOOL; stdcall;
function SetStretchBltMode(DC: HDC; StretchMode: Integer): Integer; stdcall;
function DrawText(hDC: HDC; lpString: PChar; nCount: Integer;
	var lpRect: TRect; uFormat: UINT): Integer; stdcall;
function DeleteDC(DC: HDC): BOOL; stdcall;
function CreateSolidBrush(p1: Cardinal): HBRUSH; stdcall;
function BeginPaint(hWnd: HWND; var lpPaint: TPaintStruct): HDC; stdcall;
function EndPaint(hWnd: HWND; const lpPaint: TPaintStruct): BOOL; stdcall;
function GetSysColor(nIndex: Integer): DWORD; stdcall;
function GetSysColorBrush(nIndex: Integer): HBRUSH; stdcall;
function InvalidateRect(hWnd: HWND; const lpRect: TRect; bErase: BOOL): BOOL; stdcall;
function CreatePen(Style, Width: Integer; Color: Cardinal): HPEN; stdcall;
function RoundRect(DC: HDC; X1, Y1, X2, Y2, X3, Y3: Integer): BOOL; stdcall;
function SaveDC(DC: HDC): Integer; stdcall;
function RestoreDC(DC: HDC; SavedDC: Integer): BOOL; stdcall;
function CreateFont(nHeight, nWidth, nEscapement, nOrientaion, fnWeight: Integer;
	fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision,
	fdwClipPrecision, fdwQuality, fdwPitchAndFamily: DWORD; lpszFace: PAnsiChar): HFONT; stdcall;
function GetTextExtentPoint(DC: HDC; Str: PAnsiChar; Count: Integer;
	var Size: TSize): BOOL; stdcall;
function SetROP2(DC: HDC; p2: Integer): Integer; stdcall;

function PatBlt(DC: HDC; X, Y, Width, Height: Integer; Rop: DWORD): BOOL; stdcall;

function MoveToEx(DC: HDC; p2, p3: Integer; p4: PPoint): BOOL; stdcall;
function LineTo(DC: HDC; X, Y: Integer): BOOL; stdcall;

function GetUpdateRect(hWnd: HWND; var lpRect: TRect; bErase: BOOL): BOOL; stdcall;

function CreatePalette(const LogPalette: TLogPalette): HPalette; stdcall;
function SelectPalette(DC: HDC; Palette: HPALETTE;
	ForceBackground: Bool): HPALETTE; stdcall;

{ $ENDREGION}

(**)

implementation

{
procedure OutlinedText(DC: HDC; Text: AnsiString; X, Y, W, H, F: Integer; C1, C2: Cardinal);
var
	R: TRect;
	L: Integer;
	C: Cardinal;
begin
	with R do begin
		Left := X;
		Right := X + W;
		Top := Y;
		Bottom := Y + H;
	end;
	L := Length(Text);
	C := SetTextColor(DC, c2);
	inc(R.Left, 1);
	inc(R.Right, 1);
	DrawText(DC, @Text[1], L, R, F);
	dec(R.Left, 2);
	dec(R.Right, 2);
	DrawText(DC, @Text[1], L, R, F);
	inc(R.Left, 1);
	inc(R.Right, 1);
	inc(R.Top, 1);
	inc(R.Bottom, 1);
	DrawText(DC, @Text[1], L, R, F);
	dec(R.Top, 2);
	dec(R.Bottom, 2);
	DrawText(DC, @Text[1], L, R, F);
	inc(R.Top, 1);
	inc(R.Bottom, 1);
	SetTextColor(DC, c1);
	DrawText(DC, @Text[1], L, R, F);
	SetTextColor(DC, C);
end;

procedure TextOut(DC: HDC; T: AnsiString; X, Y, W, H: Integer; F: Integer);
var
	R: TRect;
begin
	R.Left := X;
	R.Top := Y;
	R.Right := w;
	R.Bottom := h;
	DrawText(DC, @T[1], Length(T), R, F);
end;


procedure ImbaPlate(DC: HDC; X1, Y1, X2, Y2, O: Integer; B1, B2: HBrush; Q: Integer);
var
	P: HPen;
	B: HBRUSH;
begin
	P := SelectObject(DC, N_P);
	B := SelectObject(DC, B1);
	RoundRect(DC, X1    , Y1    , X2 + 1, Y2 + 1, Q, Q);
	SelectObject(DC, N_B);
	SelectObject(DC, B_P);
	RoundRect(DC, X1 + O, Y1 + O, X2 - O, Y2 - O, Q, Q);
	SelectObject(DC, W_P);
	SelectObject(DC, B2);
	inc(O);
	RoundRect(DC, X1 + O, Y1 + O, X2 - O, Y2 - O, Q, Q);

	SelectObject(DC, P);
	SelectObject(DC, B);
end;  }

function TextWidth(DC: HDC; T: AnsiString): Integer;// inline;
var
	S: TSIZE;
begin
	GetTextExtentPoint(DC, PAnsiChar(@T[1]), Length(T), s);
	result := s.cx;
end;


{ $REGION 'WinAPI'}

function MoveToEx; external gdi32 name 'MoveToEx';
function LineTo; external gdi32 name 'LineTo';

function GetUpdateRect; external user32 name 'GetUpdateRect';

function SelectPalette; external gdi32 name 'SelectPalette';
function CreatePalette; stdcall; external gdi32 name 'CreatePalette';

function ExcludeClipRect; external gdi32 name 'ExcludeClipRect';
function CreateFont; external gdi32 name 'CreateFontA';
function GetSysColor; external user32 name 'GetSysColor';
function GetSysColorBrush; external user32 name 'GetSysColorBrush';
function BeginPaint; external user32 name 'BeginPaint';
function EndPaint; external user32 name 'EndPaint';
function DeleteDC; external gdi32 name 'DeleteDC';
function DrawText; external user32 name 'DrawTextA';
function PatBlt; external gdi32 name 'PatBlt';
function BitBlt; external gdi32 name 'BitBlt';
function StretchBlt; external gdi32 name 'StretchBlt';
function SetStretchBltMode; external gdi32 name 'SetStretchBltMode';
function SelectObject; external gdi32 name 'SelectObject';
function Rectangle; external gdi32 name 'Rectangle';
function SetBkColor; external gdi32 name 'SetBkColor';
function SetBkMode; external gdi32 name 'SetBkMode';
function SetTextColor; external gdi32 name 'SetTextColor';
function CreateCompatibleBitmap; external gdi32 name 'CreateCompatibleBitmap';
function CreateCompatibleDC; external gdi32 name 'CreateCompatibleDC';
function SetDIBits; external gdi32 name 'SetDIBits';
function GetStockObject; external gdi32 name 'GetStockObject';
function DeleteObject; external gdi32 name 'DeleteObject';
function CreateSolidBrush; external gdi32 name 'CreateSolidBrush';
function InvalidateRect; external user32 name 'InvalidateRect';
function CreatePen; external gdi32 name 'CreatePen';
function RoundRect; external gdi32 name 'RoundRect';
function RestoreDC; external gdi32 name 'RestoreDC';
function SaveDC; external gdi32 name 'SaveDC';
function GetTextExtentPoint; external gdi32 name 'GetTextExtentPointA';
function SetROP2; external gdi32 name 'SetROP2';

function GetDC; external user32 name 'GetDC';
function ReleaseDC; external user32 name 'ReleaseDC';

function ValidateRect; external user32 name 'ValidateRect';
function SwapBuffers; external gdi32 name 'SwapBuffers';

{ $ENDREGION}

end.
