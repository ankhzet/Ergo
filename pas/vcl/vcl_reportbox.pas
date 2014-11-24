unit vcl_reportbox;
interface
uses
		WinAPI
	, strings
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TReportBox   = class(TStaticCtl)
	private
		pB         : HPEN;
		fItems     : TItemList;
		fItemHeight: Integer;
		procedure    setItemHeight(const Value: Integer);
	protected
		procedure    Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure    InitStyle(var s, e: Cardinal); override;
	public
		constructor  Create(Owner: TComponent); override;
		destructor   Destroy; override;

		property     Items: TItemList read fItems;
		property     ItemHeight: Integer read fItemHeight write setItemHeight;
	end;


implementation
uses
	functions
	, WinAPI_GDIInterface;

{ TGroupBox }

constructor TReportBox.Create(Owner: TComponent);
begin
	inherited;
	fItems := TItemList.Create;//(Self);
	pB := CreatePen(PS_SOLID, 1, $808080);
	Brush.Color := $FFFFFF;
	fItemHeight := 14;
end;

destructor TReportBox.Destroy;
begin
	DeleteObject(pB);
	inherited;
end;

procedure TReportBox.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

procedure TReportBox.Paint(DC: HDC; var PS: TPaintStruct);
var
	R: TRect;
	i, c: Integer;
begin
	SelectObject(DC, pB);
	Rectangle(DC, 0, 0, Width, Height);

	c := Height div ItemHeight + 1;
	i := Items.Count;
	R := Rect(3, 0, Width - 3, ItemHeight);
	while i > 0 do begin
		dec(i);
		DrawText(DC, PAnsiChar(Items[i]), Length(Items[i]), R, DT_NOPREFIX or DT_SINGLELINE or DT_LEFT or DT_VCENTER);
		inc(R.Top, ItemHeight);
		inc(R.Bottom, ItemHeight);
		dec(c);
		if c <= 0 then exit;
	end;
end;

procedure TReportBox.setItemHeight(const Value: Integer);
begin
	if fItemHeight <> Value then begin
		fItemHeight := Value;
		if Items.Count > 0 then Invalidate;
	end;
end;

end.
