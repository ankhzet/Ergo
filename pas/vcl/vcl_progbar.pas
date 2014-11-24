unit vcl_progbar;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TPBStyle     = (pb_vertical, pb_gorizontal);
	TProgressBar = class(TStaticCtl)
	private
		fMax       : Integer;
		fMin       : Integer;
		fPos       : Integer;
		bBg, bFG   : HBRUSH;
		pB1, pB2   : HPEN;
		fPBS       : TPBStyle;
		procedure    setPos(const Value: Integer);
	protected
		procedure    Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure    InitStyle(var s, e: Cardinal); override;
	public
		constructor  Create(Owner: TComponent); override;
		destructor   Destroy; override;
		property     Min: Integer read fMin write fMin;
		property     Max: Integer read fMax write fMax;
		property     Pos: Integer read fPos write setPos;
		property     Style: TPBStyle read fPBS write fPBS;
	end;

implementation
uses
		functions
	, strings
	;

{ TProgressBar }

constructor TProgressBar.Create(Owner: TComponent);
begin
	inherited;
	fMin:= 0;
	fMax:= 100;
	fPos:= 1;
	pB1 := CreatePen(PS_SOLID, 1, $A0A0A0);
	pB2 := CreatePen(PS_SOLID, 1, $F0F0F0);

	bBg := CreateSolidBrush($E0E0E0);
	bFG := CreateSolidBrush($FFd0c0);
end;

destructor TProgressBar.Destroy;
begin
	DeleteObject(bBg);
	DeleteObject(bFG);
	DeleteObject(pB1);
	DeleteObject(pB2);
	inherited;
end;

procedure TProgressBar.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

procedure TProgressBar.Paint(DC: HDC; var PS: TPaintStruct);
var
	f: Single;
	d: Integer;
	R: TRect;
	S: AnsiString;
begin
	if Max - Min = 0 then f := 0 else f := (Pos - Min) / (Max - Min);
	if Style = pb_gorizontal then
		d := Round((Width - 4) * f) + 1
	else
		d := Round((Height - 4) * f) + 1;
	SelectObject(DC, bBg);
	SelectObject(DC, pB1);
	RoundRect(DC, 0, 0, Width, Height, 2, 2);

	SelectObject(DC, GetStockObject(NULL_BRUSH));
	SelectObject(DC, pB2);
	Rectangle(DC, 1, 1, Width - 1, Height - 1);

	SelectObject(DC, bFG);
	SelectObject(DC, GetStockObject(NULL_PEN));
	if Style = pb_gorizontal then begin
		Rectangle(DC, 2, 2, 2 + d, Height - 1);
		S := Caption + ITS(Round(100 * f)) + '%';
		R := Rect(0, 0, Width, Height);
		DrawText(DC, PAnsiChar(S), Length(S), R, DT_SINGLELINE or DT_VCENTER or DT_CENTER);
	end else
		Rectangle(DC, 2, 2 + (Height - d), Width - 1, Height - 1);
end;

procedure TProgressBar.setPos(const Value: Integer);
begin
	if fPos <> Value then begin
		fPos := imin(imax(Value, Min), Max);
		Invalidate;
	end;
end;

end.
