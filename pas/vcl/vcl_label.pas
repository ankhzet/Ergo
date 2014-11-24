unit vcl_label;
interface
uses
		WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TJustify    = (j_left, j_center, j_right);
	TLabel      = class(TStaticCtl)
	private
		fJustify  : TJustify;
		procedure   setJustify(const Value: TJustify);
	protected
		procedure   InitStyle(var s, e: Cardinal); override;
		procedure   Paint(DC: HDC; var PS: TPaintStruct); override;
	public
		property    Justify: TJustify read fJustify write setJustify;
	end;


implementation

{ TGroupBox }

procedure TLabel.Paint(DC: HDC; var PS: TPaintStruct);
const
	jv: array [TJustify] of Cardinal = (DT_LEFT, DT_CENTER, DT_RIGHT);
var
	R: TRect;
begin
	SetTextColor(DC, 0);
	SetBkMode(DC, TRANSPARENT);
	R.Left   := 0;
	R.Top    := 0;
	R.Right  := Width;
	R.Bottom := Height;
	DrawText(DC, PAnsiChar(Caption), Length(Caption), R, DT_SINGLELINE or jv[Justify] or DT_VCENTER);
end;

procedure TLabel.setJustify(const Value: TJustify);
begin
	if fJustify <> Value then begin
		fJustify := Value;
		Invalidate;
	end;
end;

procedure TLabel.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

end.
