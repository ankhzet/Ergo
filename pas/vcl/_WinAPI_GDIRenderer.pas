unit WinAPI_GDIRenderer;
interface
uses
	WinAPI, vcl_rtfrenderer;

type
	TCanvas     = object
	private
		fBM       : HBITMAP;
		fFont     : HFont;
		fDC       : HDC;
		fWindow   : HWnd;
		fWDC      : HDC;
		procedure   setFont(const Value: HFont);
		function    getTC: Cardinal;
		procedure   setTC(const Value: Cardinal);
	public
		TDC       : HDC;
		Width     : Integer;
		Height    : Integer;
		RTF       : TRTFRenderer;
		procedure   Create;
		procedure   Destroy;
		procedure   Bind(Wnd: HWnd);
		procedure   Resize(W, H: Integer);
		procedure   WMPaint;
		procedure   BeginPaint;// inline;
		function    SetBrush(B: HBRUSH): HBrush; //inline;
		function    SetPen(P: HPen): HPen;// inline;
		procedure   Flush;// inline;
		procedure   DrawBitmap(BM: HBITMAP; X, Y, W, H: Integer); overload;// inline;
		procedure   DrawBitmapO(BM: HBITMAP; X, Y, SW, SH, DX, DY: Integer);// inline;
		procedure   DrawBitmap(BM: HBITMAP; X, Y, SW, SH, DW, DH: Integer); overload;// inline;
		procedure   PlateOut(X1, Y1, X2, Y2, O: Integer; B1, B2: HBrush; Q: Integer = 5);// inline;
		procedure   TextOut(T: AnsiString; X, Y, W, H: Integer; F: Integer = DT_Center or DT_Singleline or DT_Vcenter);
		procedure   OutlinedText(Text: AnsiString; X, Y, W, H, F: Integer; C1, C2: Cardinal);
		procedure   Rectangle(X1, Y1, X2, Y2: Integer);
		function    RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer): BOOL;// inline;
		property    Window: HWnd read fWindow;
		property    WDC: HDC read fWDC;
		property    DC: HDC read fDC;
		property    Font: HFont read fFont write setFont;
		property    TextColor: Cardinal read getTC write setTC;
	end;

var
	Canvas: TCanvas = ();

var
	BG, WG, FG, SG: HBRUSH;
var
	N_P, B_P, W_P: HPEN;
	N_B, G_B, W_B: HBRUSH;
	L_B          : HBRUSH;

function GetStockObject(Index: Integer): HGDIOBJ; stdcall;
function DeleteObject(p1: THandle): BOOL; stdcall;
function CreateSolidBrush(p1: Cardinal): HBRUSH; stdcall;
function DrawText(hDC: HDC; lpString: PChar; nCount: Integer; var lpRect: TRect; uFormat: UINT): Integer; stdcall;
function TextWidth(DC: HDC; T: AnsiString): Integer;

implementation
uses
	WinAPI_GDIInterface;

function GetStockObject; external gdi32 name 'GetStockObject';
function DeleteObject; external gdi32 name 'DeleteObject';
function CreateSolidBrush; external gdi32 name 'CreateSolidBrush';
function DrawText; external user32 name 'DrawTextA';

function TextWidth(DC: HDC; T: AnsiString): Integer; inline;
var
	S: TSIZE;
begin
	GetTextExtentPoint(DC, PAnsiChar(@T[1]), Length(T), s);
	result := s.cx;
end;

{ TCanvas }

procedure TCanvas.Create;
begin
//	FntSmall  := CreateFont(10, 5, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_ONLY_PRECIS, 0, PROOF_QUALITY, FIXED_PITCH or FF_MODERN, 'Georgia');
	Font := CreateFont(12, 4, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_ONLY_PRECIS, 0, PROOF_QUALITY, FIXED_PITCH or FF_MODERN, 'Georgia');
	RTF := TRTFRenderer.Create;
end;

procedure TCanvas.Destroy;
begin
	RTF.Free;
	if fWDC <> 0 then ReleaseDC(fWindow, WDC);
	DeleteDC(TDC);
	DeleteObject(fBM);
end;

function TCanvas.RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer): BOOL;
begin
	result := WinAPI_GDIInterface.RoundRect(DC, X1, Y1, X2, Y2, X3, Y3);
end;

procedure TCanvas.OutlinedText(Text: AnsiString; X, Y, W, H, F: Integer; C1, C2: Cardinal);
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

procedure TCanvas.TextOut(T: AnsiString; X, Y, W, H: Integer; F: Integer);
var
	R: TRect;
begin
	R.Left := X;
	R.Top := Y;
	R.Right := w;
	R.Bottom := h;
	DrawText(DC, @T[1], Length(T), R, F);
end;

procedure TCanvas.WMPaint;
var
	EDC: HDC;
	PS: TPaintStruct;
begin
	EDC := WinAPI_GDIInterface.BeginPaint(Window, PS);
//	if WantRender then Render;
	with PS.rcPaint do
		BitBlt(EDC, left, top, right - left, bottom - top, DC, left, top, srccopy);
	EndPaint(Window, PS);
end;

procedure TCanvas.BeginPaint;
begin
	SelectObject(DC, Font);
	SelectObject(DC, GetStockObject(BLACK_PEN));
	SelectObject(DC, BG);//GetStockObject(WHITE_BRUSH));
	SelectObject(DC, fBM);//GetStockObject(WHITE_BRUSH));
	PatBlt(DC, 0, 0, Width, Height, PATCOPY);
end;

procedure TCanvas.Bind(Wnd: HWnd);
begin
	if fWDC <> 0 then ReleaseDC(fWindow, WDC);
	fWindow := Wnd;
	fWDC := GetDC(Window);
	if TDC <> 0 then DeleteDC(TDC);
	TDC := CreateCompatibleDC(WDC);
end;

procedure TCanvas.DrawBitmap(BM: HBITMAP; X, Y, W, H: Integer);
begin
	BM := SelectObject(TDC, BM);
	BitBlt(DC, X, Y, W, H, TDC, 0, 0, SRCCOPY);
	BM := SelectObject(TDC, BM);
end;

procedure TCanvas.DrawBitmap(BM: HBITMAP; X, Y, SW, SH, DW, DH: Integer);
begin
	BM := SelectObject(TDC, BM);
	StretchBlt(DC, X, Y, DW, DH, TDC, 0, 0, SW, SH, SRCCOPY);
	BM := SelectObject(TDC, BM);
end;

procedure TCanvas.DrawBitmapO(BM: HBITMAP; X, Y, SW, SH, DX, DY: Integer);
begin
	BM := SelectObject(TDC, BM);
	BitBlt(DC, X, Y, SW, SH, TDC, DX, DY, SRCCOPY);
	BM := SelectObject(TDC, BM);
end;

procedure TCanvas.Flush;
//var
//	R: TRect;
begin
//	GetUpdateRect(Window, R, true);
//	with R do BitBlt(WDC, Left, Top, Right - Left, Bottom - Top, DC, Left, Top, SRCCOPY);
		BitBlt(WDC, 0, 0, Width, Height, DC, 0, 0, SRCCOPY);
end;

function TCanvas.getTC: Cardinal;
begin
	result := SetTextColor(DC, 0);
	SetTextColor(DC, result);
end;

procedure TCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
begin
	WinAPI_GDIInterface.Rectangle(DC, X1, Y1, X2, Y2);
end;

procedure TCanvas.Resize(W, H: Integer);
var
	oBM: HBITMAP;
begin
	if WDC = 0 then exit;
	Width := W;
	Height := H;
	if DC = 0 then fDC := CreateCompatibleDC(WDC);
	fBM := CreateCompatibleBitmap(WDC, Width, Height);
	oBM := SelectObject(DC, fBM);
	if oBM <> 0 then DeleteObject(oBM);
	SetBkMode(DC, TRANSPARENT);
	SetStretchBltMode(DC, HALFTONE);
	SelectObject(DC, Font);
	RTF.Bind(DC);
end;

function TCanvas.SetBrush(B: HBRUSH): HBrush;
begin
	result := SelectObject(DC, B);
end;

procedure TCanvas.setFont(const Value: HFont);
begin
	fFont := Value;
	SelectObject(TDC, fFont);
end;

function TCanvas.SetPen(P: HPen): HPen;
begin
	result := SelectObject(DC, P);
end;

procedure TCanvas.setTC(const Value: Cardinal);
begin
	SetTextColor(DC, Value);
end;

procedure TCanvas.PlateOut(X1, Y1, X2, Y2, O: Integer; B1, B2: HBrush; Q: Integer);
var
	P: HPen;
	B: HBRUSH;
begin
	P := SelectObject(DC, N_P);
	B := SelectObject(DC, B1);
	WinAPI_GDIInterface.RoundRect(DC, X1    , Y1    , X2 + 1, Y2 + 1, Q, Q);
	SelectObject(DC, N_B);
	SelectObject(DC, B_P);
	WinAPI_GDIInterface.RoundRect(DC, X1 + O, Y1 + O, X2 - O, Y2 - O, Q, Q);
	SelectObject(DC, W_P);
	SelectObject(DC, B2);
	inc(O);
	WinAPI_GDIInterface.RoundRect(DC, X1 + O, Y1 + O, X2 - O, Y2 - O, Q, Q);

	SelectObject(DC, P);
	SelectObject(DC, B);
end;

end.
