unit vcl_window;
interface
uses
	WinAPI
	, vcl_messages
	, vcl_components
	, vcl_control
	;

type
	TBorderStyle = (bs_none, bs_single, bs_sizeable, bs_dialog);
	TBorderIcon  = (bi_sysmenu, bi_minimize, bi_maximize, bi_close);
	TBorderIcons = set of TBorderIcon;

	TWindow      = class(TCustomCtl)
	private
		fBorderStyle:TBorderStyle;
		fBorderIcons:TBorderIcons;
		procedure    SetStyle;
		procedure    setBorderIcons(const Value: TBorderIcons);
		procedure    setBorderStyle(const Value: TBorderStyle);
	protected
		procedure    InitClass(var C: TWndClass); override;
		procedure    InitStyle(var S, E: Cardinal); override;
	public
		procedure    Init; override;

		procedure    DefaultHandler(var Message); override;

		property     BorderStyle: TBorderStyle read fBorderStyle write setBorderStyle;
		property     BorderIcons: TBorderIcons read fBorderIcons write setBorderIcons;
	end;


implementation

{ TWindow }

procedure TWindow.DefaultHandler(var Message);
begin
	with TMessage(Message) do
		case Msg of
			WM_DESTROY : begin
				if Owner <> nil then
					Owner.Remove(Self);
			end;
			else inherited DefaultHandler(Message);;
		end;
end;

procedure TWindow.Init;
begin
	BorderStyle := bs_sizeable;
	BorderIcons := [bi_sysmenu, bi_minimize, bi_maximize, bi_close];
end;

procedure TWindow.InitClass(var C: TWndClass);
begin
	inherited;
	C.hbrBackground := 0;//GetStockObject(LTGRAY_BRUSH);
end;

procedure TWindow.InitStyle(var S, E: Cardinal);
begin
	S := S or WS_VISIBLE or WS_CLIPCHILDREN and (not WS_CHILD);
	if BorderStyle <> bs_none then begin
		S := S or WS_BORDER or WS_CAPTION;
		if BorderStyle = bs_sizeable then S := S or WS_THICKFRAME;
		if BorderStyle = bs_dialog then S := S or WS_DLGFRAME;

		if bi_sysmenu in BorderIcons then S := S or WS_SYSMENU;
		if bi_minimize in BorderIcons then S := S or WS_MINIMIZEBOX;
		if bi_maximize in BorderIcons then S := S or WS_MAXIMIZEBOX;
		if not (bi_close in BorderIcons) then S := S xor WS_SYSMENU;
	end;
end;

procedure TWindow.setBorderIcons(const Value: TBorderIcons);
begin
	if fBorderIcons <> Value then begin
		fBorderIcons := Value;
		SetStyle;
	end;
end;

procedure TWindow.setBorderStyle(const Value: TBorderStyle);
begin
	if fBorderStyle <> Value then begin
		fBorderStyle := Value;
		SetStyle;
	end;
end;

procedure TWindow.SetStyle;
var
	st, et: Cardinal;
begin
	st := WS_VISIBLE or WS_BORDER;
	if (Parent <> nil) and (Parent is TWindow) then st := st or WS_CHILD;
	et := 0;
	InitStyle(st, et);
	SetWindowLong(Handle, GWL_STYLE, st);
	SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOSIZE or SWP_NOMOVE or SWP_NOZORDER or SWP_FRAMECHANGED);
end;

end.
