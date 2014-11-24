unit reader;
interface
uses
		WinAPI
	, threads
	, vcl_control
	, vcl_components
	, vcl_messages
	, s_config
	, page_drawer
	, plate_drawer
	, homepage_drawer
	, mangapage_drawer
	, search_drawer
	, chapter_drawer
	, importpage_drawer
//	, rss_drawer
;

type
	TReader      = class;
	TFlushTimer  = class(TThread)
	private
		fReader    : TReader;
	public
		constructor Create(Reader: TReader);
		procedure   Execute; override;
	end;
	TReader      = class(page_drawer.TReader)
	private
		Lock       : Integer;
		DimX, DimY : Integer;
		Timer      : TFlushTimer;
		flen       : cardinal;
		procedure    WMSize(var M: TWMSize); message WM_SIZE;
		procedure    WMPaint(var M: TWMPaint); message WM_PAINT;
		procedure    WMEraseBG(var M: TWMEraseBkgnd); message WM_ERASEBKGND;

		procedure    WMMouseMove(var M: TWMMouseMove); message WM_MOUSEMOVE;

		procedure    WMLButtonDown(var M: TWMLButtonDown); message WM_LBUTTONDOWN;
		procedure    WMLButtonUp(var M: TWMLButtonUp); message WM_LBUTTONUP;
		procedure    WMRButtonDown(var M: TWMRButtonDown); message WM_RBUTTONDOWN;
		procedure    WMRButtonUp(var M: TWMRButtonUp); message WM_RBUTTONUP;
		procedure    WMMButtonDown(var M: TWMMButtonDown); message WM_MBUTTONDOWN;
		procedure    WMMButtonUp(var M: TWMMButtonUp); message WM_MBUTTONUP;
		procedure    WMMouseWheel(var M: TWMMouseWheel); message WM_MOUSEWHEEL;

		function     GetButtons(Keys: Integer): TMsgButtons;
		procedure    ButtonMsg(X, Y: Integer; B: TMsgButton; State: TBtnState; Pressed: TMsgButtons);
	protected
		procedure    ScrollInView; override;
		procedure    setSelected(const Value: Integer); override;
	public
		constructor  Create(AOwner: TComponent); override;
		destructor   Destroy; override;
		procedure    WMDlgCode(var M: TWMGetDlgCode); message WM_GETDLGCODE;
		procedure    WMKey(var M: TWMKey); message WM_KEYDOWN;
		procedure    Initialize;
		procedure    Action(ActionUID: Cardinal); override;
		procedure    Render; override;
	end;

implementation
uses
		functions
	, logs
	, strings
	, parsers
	, s_engine
	, sql_constants
	, vcl_window
	, opts
	, WinAPI_GDIRenderer
	;

{ TReader }

procedure TReader.Action(ActionUID: Cardinal);
var
	i: TRPages;
begin
	if SC_TOGGLE[ActionUID] <> 0 then
		SC_STATES[ActionUID] := Cardinal(not Boolean(SC_STATES[ActionUID]));
	case ActionUID of
		SB_SRVSYN: begin
			SrvSync := not SrvSync;
			Pages[ActivePage].NavigateTo(ActivePage);
		end;
		SB_FULLS: begin
			if BorderStyle <> bs_none then begin
				BorderStyle := bs_none;
				DimX := Width;
				DimY := Height;
				ShowWindow(Handle, SW_MAXIMIZE);
			end else begin
				DoReSize(DimX, DimY);
				ShowWindow(Handle, SW_NORMAL);
				BorderStyle := bs_sizeable;
			end;
			Render;
		end;
		SB_CONT : begin
			if (Selected >= 0) and (Selected < Plates.Count) then begin
				TChapterPage(Pages[rp_chapter]).Init(Plates.Data[Selected].mID, true);
				ActivePage := rp_chapter;
			end;
		end;
		SB_RSS : begin
			ActivePage := rp_rss;
		end;
		else
			if not Pages[ActivePage].Action(ActionUID) then
				for i := low(TRPages) to high(TRPages) do
					if (i <> ActivePage) and (Pages[i] <> nil) then
						if Pages[i].Action(ActionUID) then break;
	end;
	WantRender := true;
end;

procedure TReader.ButtonMsg(X, Y: Integer; B: TMsgButton; State: TBtnState; Pressed: TMsgButtons);
var
	le, ri: Integer;
begin
	if Y > RD_TOPPLANE then
		Pages[ActivePage].ButtonMsg(X, Y, B, State, Pressed)
	else begin
		if State = s_down then begin
			if (X > 10) and (Width - X > 10) then begin
				le := (X - 10) div 18;
				ri := (Width - X - 10) div 18;
				if (le >= 0) and (le < fc) then Action(_f[le].Action) else
				if (ri >= 0) and (ri < ac) then Action(_a[ri].Action) else
					exit;
			end;
		end;
		if State = s_move then begin
			if (X > 10) and (Width - X > 10) then begin
				le := (X - 10) div 18;
				ri := (Width - X - 10) div 18;
				if (le >= 0) and (le < fc) then
					if (X - 10) mod 18 <= 15 then
						Hint := SB_HINT[_f[le].Action]
					else
				else
					if (ri >= 0) and (ri < ac) then
						if (Width - X - 10) mod 18 <= 15 then
							Hint := SB_HINT[_a[ri].Action]
						else
					else
			end;
		end;
	end;
	WantRender := true;
end;

constructor TReader.Create;
begin
	SC_STATES[SB_PVIEW] := Cardinal(OPT_PREVIEWS);
	List := TConfigNode.Create('list');

	inherited Create(AOwner);
	Parent := TControl(AOwner);
	Pages[rp_home] := THomePage.Create(Self);
	Pages[rp_manga] := TMangaPage.Create(Self);
	Pages[rp_chapter] := TChapterPage.Create(Self);
//	Pages[rp_search] := TSearchPage.Create(Self);
	Pages[rp_import] := TImportPage.Create(Self);
//	Pages[rp_rss] := TRSSPage.Create(Self);

	Lock := 0;
	Timer := TFlushTimer.Create(Self);
end;

destructor TReader.Destroy;
begin
	Timer.Free;
	List.Free;
	inherited;
end;

var
	d: cardinal;

procedure TReader.Initialize;
begin
	ActivePage := rp_home;
	d := 0;
end;

procedure TReader.ScrollInView;
begin
	if ActivePage <> rp_home then exit;
	THomePage(Pages[ActivePage]).ScrollInView;
	WantRender := true;
end;

procedure TReader.setSelected(const Value: Integer);
begin
	inherited;
	if (ActivePage = rp_home) and (THomePage(Pages[ActivePage]).Aquirer <> nil) then
		THomePage(Pages[ActivePage]).Aquirer.sel := Plates.Data[Value].mID;
end;

procedure TReader.WMEraseBG(var M: TWMEraseBkgnd);
begin
	M.Result := 0;
end;

procedure TReader.WMDlgCode(var M: TWMGetDlgCode);
begin
	M.Result := 1;
end;

function isPressed(K: Integer): Boolean;
begin
	result := GetKeyState(K) and $80 <> 0;
end;

procedure TReader.WMKey(var M: TWMChar);
var
	p: array[boolean] of boolean;
	s: TSpeedButton;
	k, e: Word;
	cs: Boolean;
begin
//	if M.KeyData and $FF{ $40000000} = 0 then
	p[false] := isPressed(VK_CONTROL);
	p[true ] := isPressed(VK_SHIFT);

		for s in SpeedButton do begin
			k := s.Shortcut and $FFFF;
			if k <> M.CharCode then continue;
			e := s.Shortcut shr 16;
			if e <> 0 then
				cs := p[e = VK_SHIFT] and not p[e <> VK_SHIFT]
			else
				cs := not (p[false] or p[true]);
			if cs then Action(s.Action);
		end;
	Pages[ActivePage].OnKey(M);
	WantRender := true;
end;

procedure TReader.WMLButtonDown(var M: TWMLButtonDown);
begin
	SetCapture(Handle);
	ButtonMsg(M.XPos, M.YPos, b_left, s_down, GetButtons(M.Keys));
end;

procedure TReader.WMMButtonDown(var M: TWMMButtonDown);
begin
	SetCapture(Handle);
	ButtonMsg(M.XPos, M.YPos, b_middle, s_down, GetButtons(M.Keys));
end;

procedure TReader.WMRButtonDown(var M: TWMRButtonDown);
begin
	SetCapture(Handle);
	ButtonMsg(M.XPos, M.YPos, b_right, s_down, GetButtons(M.Keys));
end;

procedure TReader.WMMouseMove(var M: TWMMouseMove);
begin
	Hint := '';
	ButtonMsg(M.XPos, M.YPos, b_none, s_move, GetButtons(M.Keys));
end;

procedure TReader.WMMouseWheel(var M: TWMMouseWheel);
begin
	if M.WheelDelta > 0 then
		ButtonMsg(M.XPos, M.YPos, b_wheel, s_up, GetButtons(M.Keys))
	else
		ButtonMsg(M.XPos, M.YPos, b_wheel, s_down, GetButtons(M.Keys));
end;

procedure TReader.WMMButtonUp(var M: TWMMButtonUp);
begin
	ReleaseCapture;
	ButtonMsg(M.XPos, M.YPos, b_middle, s_up, GetButtons(M.Keys));
end;

procedure TReader.WMRButtonUp(var M: TWMRButtonUp);
begin
	ReleaseCapture;
	ButtonMsg(M.XPos, M.YPos, b_right, s_up, GetButtons(M.Keys));
end;

procedure TReader.WMLButtonUp(var M: TWMLButtonUp);
begin
	ReleaseCapture;
	ButtonMsg(M.XPos, M.YPos, b_left, s_up, GetButtons(M.Keys));
end;

procedure TReader.WMPaint(var M: TWMPaint);
var
	DC: HDC;
	PS: TPaintStruct;
begin
	Canvas.WMPaint;
//	inherited;
//	DC := BeginPaint(Handle, PS);
//	if WantRender then Render;
//	with PS.rcPaint do
//		BitBlt(DC, left, top, right - left, bottom - top, Canvas.DC, left, top, srccopy);
//	EndPaint(Handle, PS);
end;

procedure TReader.WMSize(var M: TWMSize);
begin
	inherited;
	Canvas.Resize(Width, Height);
	if ActivePage = rp_none then exit;
	Pages[ActivePage].Size(Width, Height);
	WantRender := true;
end;

function TReader.GetButtons(Keys: Integer): TMsgButtons;
begin
	result := [];
	if Keys and MK_LBUTTON <> 0 then Include(result, b_left);
	if Keys and MK_MBUTTON <> 0 then Include(result, b_middle);
	if Keys and MK_RBUTTON <> 0 then Include(result, b_right);
	if Keys and MK_SHIFT   <> 0 then Include(result, b_shift);
	if Keys and MK_CONTROL <> 0 then Include(result, b_ctrl);
end;

procedure OffsetRect(var R: TRect; dx, dy: Integer); inline;
begin
	inc(R.Left, dx);
	inc(R.Right, dx);
	inc(R.Top, dy);
	inc(R.Bottom, dy);
end;

procedure TReader.Render;
var
	DC: HDC;
	procedure DrawSB;
	var
		i, j, k, z: Integer;
		p: PSpeedButton;
	begin
		i := 0;
		j := 10;
		k := Width - 8;
		z := fc * RD_SBGAIN + RD_FILTERSPC - RD_SBSPACE;
		while i < tc do begin
			p := _t[i];
			inc(i);

			if (SC_TOGGLE[p.Action] = 0) or (SC_STATES[p.Action] <> 0) then
				Canvas.SetPen(B_P)
			else
				Canvas.SetPen(W_P);

			case p.Align of
				al_first : begin
					if SC_TOGGLE[p.Action] <> Cardinal(-1) then
						Canvas.RoundRect(j, 1, j + 16, 17, 2, 2);
{$IFDEF FATRTL}
					if p.Bitmap <> 0 then
						Canvas.DrawBitmap(p.Bitmap, j + 1, 2, 16, 16, RD_SBWIDTH, RD_SBWIDTH);
{$ENDIF}
					inc(j, RD_SBGAIN);
				end;
				al_middle: ;
				al_last  : begin
					dec(k, RD_SBGAIN);
					if k < z then continue;
					if SC_TOGGLE[p.Action] <> Cardinal(-1) then
						Canvas.RoundRect(k, 1, k + 16, 17, 2, 2);
{$IFDEF FATRTL}
					if p.Bitmap <> 0 then
						Canvas.DrawBitmap(p.Bitmap, k + 1, 2, 16, 16, RD_SBWIDTH, RD_SBWIDTH);
{$ENDIF}
				end;
			end;
		end;
		Canvas.SetPen(B_P);//GetStockObject(BLACK_PEN));
	end;
var
	i: Integer;
	R: TRect;
	s : AnsiString;
begin
	WantRender := false;
	if GetTickCount - d < 20 then exit;
	d := GetTickCount;
	WaitRenderSync;
	try
		DC := Canvas.DC;
		Canvas.BeginPaint;

		Pages[ActivePage].Draw;
		Canvas.TextColor := 0;

		Canvas.SetPen(B_P);
		Canvas.SetBrush(W_B);
		Canvas.PlateOut(0, -5, Width, RD_TOPPLANE - 1, 1, L_B, SG);
		DrawSB;
		i := fc * 18;
		if ActivePage = rp_home then inc(i, RD_FILTERSPC);
		if i + ac * 18 < Width - 20 then
			Canvas.TextOut(Pages[ActivePage].Title, 10 + i, 0, Width - 10 - ac * 18, RD_TOPPLANE);

		if GetTickCount - count < 5000 then s := LogMSG else s := '';
//		if s = '' then
//			s := ITS(Wants);

		if s <> '' then begin
			Canvas.PlateOut(-5, Height - 20, TextWidth(DC, s) + 20, Height + 5, 2, L_B, W_B);
			Canvas.TextOut(s, 10, Height - 14, Width, Height, DT_BOTTOM or DT_LEFT);
		end;
		if Hint <> '' then begin
			R := Rect(0, 0, TextWidth(DC, Hint) + 8, 20);
			if Cursor.X > Width - R.Right then
				OffsetRect(R, Cursor.X - R.Right, Cursor.Y + 23)
			else
				OffsetRect(R, Cursor.X + 14, Cursor.Y + 23);
			if R.Left   < 0      then OffsetRect(R,       - R.Left ,                 0);
			if R.Right  > Width  then OffsetRect(R, Width - R.Right,                 0);
			if R.Top    < 0      then OffsetRect(R,               0,        - R.Top   );
			if R.Bottom > Height then OffsetRect(R,               0, Height - R.Bottom);

			with R do begin
				Canvas.PlateOut(Left, Top, Right, Bottom, 1, G_B, W_B);
				Canvas.TextOut(Hint, Left + 4, Top + 4, Right - 4, Bottom - 4, DT_VCENTER or DT_CENTER or DT_SINGLELINE);
			end;
		end;

	finally
		Canvas.Flush;
		ReleaseRenderSync;
	end;
end;

{ TFlushTimer }

constructor TFlushTimer.Create(Reader: TReader);
begin
	inherited Create(true);
	FreeOnTerminate := true;
	fReader := Reader;
	Resume;
end;

const
	FPS = 75;
	INTERVAL = trunc(1000 / FPS);

procedure TFlushTimer.Execute;
var
	d1, d2, d3: Cardinal;
	d4: Integer;
begin
	d1 := GetTickCount;
	d4 := 0;
	repeat
		d2 := GetTickCount;
		d3 := d2 - d1;
		with fReader do
			if d3 >= INTERVAL then begin
				if WantRender then begin
					Render;
//					d4 := GetTickCount - d2;
//					flen := round((d4 + flen) / 2);
//					d1 := d2 + d4;
				end;// else
					d1 := d2;// + d3 mod INTERVAL;
			end else
				sleep(1);
	until Terminated;
end;

end.
