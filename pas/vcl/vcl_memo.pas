unit vcl_memo;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TMemo    = class(TCustomCtl)
	private
		pB         : HPEN;
	protected
		procedure    Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure    InitStyle(var s, e: Cardinal); override;
	public
		constructor  Create(Owner: TComponent); override;
		destructor   Destroy; override;
	end;


implementation
uses
	functions;

{ TGroupBox }

constructor TGroupBox.Create(Owner: TComponent);
begin
	inherited;
	pB := CreatePen(PS_SOLID, 1, $808080);
end;

destructor TGroupBox.Destroy;
begin
	DeleteObject(pB);
	inherited;
end;

procedure TGroupBox.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

procedure TGroupBox.Paint(DC: HDC; var PS: TPaintStruct);
var
	R: TRect;
begin
	SelectObject(DC, GetStockObject(NULL_BRUSH));
	SelectObject(DC, pB);
	Rectangle(DC, 0, 8, Width, Height);

	R := Rect(10, 1, Width - 10, 16);
	DrawText(DC, PAnsiChar(Caption), Length(Caption), R, DT_CALCRECT);
	SelectObject(DC, Brush.Handle);
	SelectObject(DC, GetStockObject(NULL_PEN));
	Rectangle(DC, R.Left - 1, R.Top, R.Right + 1, R.Bottom);
	DrawText(DC, PAnsiChar(Caption), Length(Caption), R, DT_LEFT or DT_TOP);
end;

end.
