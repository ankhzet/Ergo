unit vcl_button;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TButton      = class(TCustomCtl)
	private
		bBg, bFG   : HBRUSH;
		pB1, pB2   : HPEN;
		procedure    WMLButtonDown(var M: TMessage); message WM_LBUTTONDOWN;
	protected
		procedure    Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure    InitStyle(var s, e: Cardinal); override;
	public
		constructor  Create(Owner: TComponent); override;
		destructor   Destroy; override;
	end;

implementation
uses
		functions
	, strings
	, WinAPI_GDIInterface
	;

{ TButton }

constructor TButton.Create(Owner: TComponent);
begin
	inherited;
	pB1 := CreatePen(PS_SOLID, 1, $A0A0A0);
	pB2 := CreatePen(PS_SOLID, 1, $FFD0C0);

	bBg := CreateSolidBrush($F0F0F0);
	bFG := CreateSolidBrush($FFFFFF);
end;

destructor TButton.Destroy;
begin
	DeleteObject(bBg);
	DeleteObject(bFG);
	DeleteObject(pB1);
	DeleteObject(pB2);
	inherited;
end;

procedure TButton.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

procedure TButton.Paint(DC: HDC; var PS: TPaintStruct);
var
	d: Integer;
	R: TRect;
	S: AnsiString;
begin
	if cs_pushed in State then SelectObject(DC, bFg) else SelectObject(DC, bBg);
	if cs_focused in State then
		SelectObject(DC, GetStockObject(BLACK_PEN))
	else
		SelectObject(DC, pB1);
	RoundRect(DC, 0, 0, Width, Height, 2, 2);

	if cs_pushed in State then SelectObject(DC, bBg) else SelectObject(DC, bFg);
	SelectObject(DC, GetStockObject(NULL_PEN));
	Rectangle(DC, 2, Height - 5, Width - 1, 6);

	if cs_hover in State then begin
		SelectObject(DC, pB2);
		SelectObject(DC, GetStockObject(NULL_BRUSH));
		Rectangle(DC, 1, 1, Width - 1, Height - 1);
	end; {}

	S := Caption;
	R := Rect(0, 0, Width, Height);
	DrawText(DC, PAnsiChar(S), Length(S), R, DT_SINGLELINE or DT_CENTER or DT_CALCRECT);
	d := (Width - R.Right) div 2;
	inc(R.Left, d);
	inc(R.Right, d);
	d := (Height - R.Bottom) div 2;
	inc(R.Top, d);
	inc(R.Bottom, d);
	if cs_pushed in State then begin
		inc(r.Left);
		inc(r.Top);
		inc(r.Right);
		inc(r.Bottom);
	end;

{	SelectObject(DC, bFG);
	SelectObject(DC, GetStockObject(NULL_PEN));
	d := Byte(cs_pushed in State);
	Rectangle(DC, 2 + d, 2 + d, Width - 2 + d, Height - 2 + d); }
	DrawText(DC, PAnsiChar(S), Length(S), R, 0);
end;

procedure TButton.WMLButtonDown(var M: TMessage);
begin
	inherited;
	SetFocus(Handle);
end;

end.
