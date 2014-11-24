unit vcl_listbox;
interface
uses
		WinAPI
	, strings
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TListBox     = class(TStaticCtl)
	private
		bN, bS     : HBRUSH;
		pB         : HPEN;
		fItems     : TItemList;
		fItemHeight: Integer;
		fSY        : Integer;
		fII        : Integer;
		down       : Boolean;
		procedure    setItemHeight(const Value: Integer);
		procedure    setSY(const Value: Integer);
		procedure    setII(const Value: Integer);
	protected
		procedure    WMLButtonDown(var M: TMessage); message WM_LBUTTONDOWN;
		procedure    WMLButtonUp(var M: TMessage); message WM_LBUTTONUP;
		procedure    WMMouseMove(var M: TMessage); message WM_MOUSEMOVE;
		procedure    Paint(DC: HDC; var PS: TPaintStruct); override;
		procedure    InitStyle(var s, e: Cardinal); override;
	public
		constructor  Create(Owner: TComponent); override;
		destructor   Destroy; override;

		property     ScrollY: Integer read fSY write setSY;
		property     ItemIndex: Integer read fII write setII;
		property     Items: TItemList read fItems;
		property     ItemHeight: Integer read fItemHeight write setItemHeight;
	end;


implementation
uses
	functions;

{ TGroupBox }

constructor TListBox.Create(Owner: TComponent);
begin
	inherited;
	fItems := TItemList.Create;//(Self);
	pB := CreatePen(PS_SOLID, 1, $808080);
	bN := CreateSolidBrush($FFFFFF);
	bS := CreateSolidBrush($FF8040);
	fItemHeight := 14;
	fII := -1;
	down := false;
end;

destructor TListBox.Destroy;
begin
	DeleteObject(bS);
	DeleteObject(bN);
	DeleteObject(pB);
	inherited;
end;

procedure TListBox.InitStyle(var s, e: Cardinal);
begin
	inherited;
	s := s xor WS_BORDER;
end;

procedure TListBox.Paint(DC: HDC; var PS: TPaintStruct);
var
	R: TRect;
	i, j, c: Integer;
	t: Cardinal;
begin
	SelectObject(DC, pB);
	SelectObject(DC, bN);
	Rectangle(DC, 0, 0, Width, Height);

	c := Height div ItemHeight + 1;
	i := ScrollY;
	j := imin(Items.Count, i + c);

	R := Rect(3, 0, Width - 3, ItemHeight);
	while i < j do begin
		if i = ItemIndex then begin
			SelectObject(DC, bS);
			SelectObject(DC, GetStockObject(NULL_PEN));
			Rectangle(DC, R.Left - 3, R.Top, R.Right + 3, R.Bottom);
			SelectObject(DC, pB);
			SelectObject(DC, bN);
			t := SetTextColor(DC, GetSysColor((not clSystemColor) and clHighlightText));
		end;
		DrawText(DC, PAnsiChar(Items[i]), Length(Items[i]), R, DT_NOPREFIX or DT_SINGLELINE or DT_LEFT or DT_VCENTER);
		if i = ItemIndex then
			SetTextColor(DC, t);
		inc(R.Top, ItemHeight);
		inc(R.Bottom, ItemHeight);
		inc(i);
	end;
end;

procedure TListBox.setII(const Value: Integer);
var
	DH: Integer;
begin
	if fII <> Value then begin
		fII := imax(-1, imin(Value, Items.Count - 1));
		dh := Height div ItemHeight;
		if ItemIndex >= ScrollY + dh then ScrollY := imax(ItemIndex - dh, 0);
		if ItemIndex <= ScrollY then ScrollY := ItemIndex;
		ScrollY := imax(0, imin(ScrollY, Items.Count - dh));
		Invalidate;
	end;
end;

procedure TListBox.setItemHeight(const Value: Integer);
begin
	if fItemHeight <> Value then begin
		fItemHeight := Value;
		if Items.Count > 0 then Invalidate;
	end;
end;

procedure TListBox.setSY(const Value: Integer);
begin
	if fSY <> Value then begin
		fSY := Value;
		Invalidate;
	end;
end;

procedure TListBox.WMLButtonDown(var M: TMessage);
begin
	down := true;
	SetCapture(Handle);
	ItemIndex := M.YPos div ItemHeight + ScrollY;
end;

procedure TListBox.WMLButtonUp(var M: TMessage);
begin
	if down then ReleaseCapture;
	down := false;
end;

procedure TListBox.WMMouseMove(var M: TMessage);
begin
	if not down then exit;
	ItemIndex := M.YPos div ItemHeight + ScrollY;
end;

end.
