unit vcl_rtfrenderer;
interface
uses
	WinAPI;

type
	TRTAttribute = (rta_font, rta_color, rta_size);
	TRTAttributes= set of TRTAttribute;
	PAttrRec     =^TAttrRec;
	TAttrRec     = record
		case Integer of
			0: (
				B: Byte;
				G: Byte;
				R: Byte;
				A: Byte;
			);
			1: (V: Cardinal);
			2: (S: Integer);
	end;
	TStackPtr    = array [TRTAttribute] of Byte;
	TRTFRenderer = class
	private
		TDC        : HDC;
		fTopStack  : TStackPtr;
		fAttrStack : array [TRTAttribute] of array [0..$F] of TAttrRec;
		function     getStack(Attr: TRTAttribute): PAttrRec;// inline;
		function     getTop(Attr: TRTAttribute): Byte;// inline;
		procedure    setTop(Attr: TRTAttribute; const Value: Byte);// inline;
		function     getFont: Cardinal;// inline;
		procedure    setFont(const Value: Cardinal);// inline;
		function     getColor: TAttrRec;// inline;
		procedure    setColor(const Value: TAttrRec);// inline;
		function     getSize: Integer;// inline;
		procedure    setSize(const Value: Integer);// inline;

		procedure    PushA(Attribs: TRTAttributes);// inline;
		procedure    PopA(Attribs: TRTAttributes);// inline;
		procedure    PushAll;// inline;
		procedure    PopAll;// inline;
		procedure    Assign(Attr: TRTAttribute);// inline;
		procedure    Get(Attr: TRTAttribute; Val: PAttrRec);// inline;

		function     RenderText(C: PAnsiChar; Left: Integer; var X, Y, AW, AH: Integer; CalcRect: boolean = false): Integer; overload;

		property     Top[Attr: TRTAttribute]: Byte read getTop write setTop;
		property     Stack[Attr: TRTAttribute]: PAttrRec read getStack;
		property     Font : Cardinal read getFont write setFont;
		property     Color: TAttrRec read getColor write setColor;
		property     Size : Integer read getSize write setSize;
	public
		constructor  Create;
		procedure    Bind(DC: HDC);// inline;
		procedure    CalcRect(S: PAnsiChar; X, Y: Integer; out AW, AH: Integer);// inline;
		procedure    RenderText(S: PAnsiChar; X, Y, AW, AH: Integer); overload;// inline;
	end;

implementation
uses
	functions, strings, WinAPI_GDIInterface;

{ TRTFRenderer }

const
	chh       = 12;
	DT_NORMAL = DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX;

function nextparam(var s: ansistring): ansistring;// inline;
begin
	result := Copy(s, 1, pos(',', s) - 1);
	if result = '' then result := s;
	delete(s, 1, length(result) + 1);
end;

function TRTFRenderer.RenderText(C: PAnsiChar; Left: Integer; var X, Y, AW, AH: Integer; CalcRect: boolean = false): Integer;
var
	a      : PAnsiChar;
	l      : Integer;
	iw, ih : integer;
	io     : boolean;
	d, t   : ansistring;
	nx, ny : Integer;
	linebrk: Integer;
	v      : TAttrRec;
	Centered: boolean;
	procedure Render;
	var
		tw, l, c: Integer;
		R : TRect;
		P : PAnsiChar;
	begin
		tw := TextWidth(TDC, d);
		if not CalcRect then begin
			R.Left := nx;
			if Centered then inc(R.Left, (AW - tw) div 2);
			l := Length(d);
			p := @d[1];
			R.Top := ny;
			R.Right := imin(R.Left + tw, X + AW);
			R.Bottom := R.Top + chh;
			{
			c := SetTextColor(TDC, $ffeedd);
//			c := PCardinal(@fAttrStack[rta_color, fTopStack[rta_color]])^;
			dec(R.Top);
			dec(r.Bottom);
//			inc(R.Top);
//			inc(r.Bottom);
//			inc(R.Left);
//			inc(r.Right);
			DrawText(TDC, p, l, R, DT_NORMAL);
//			dec(R.Top);
//			dec(r.Bottom);
			inc(R.Top);
			inc(r.Bottom);
//			dec(R.Left);
//			dec(r.Right);
			SetTextColor(TDC, c); {}
			DrawText(TDC, p, l, R, DT_NORMAL);
		end;
		nx := nx + tw;
		d := '';
	end;
begin
	result := 0;
	Centered := false;
	a := c;
	d := '';
	t := '';
	nx:= X;
	ny:= Y;
	linebrk := chh;
	while c^ <> #0 do begin
		case c^ of
			'}': break;
			#13: begin
				if d <> '' then render;
				ny := ny + linebrk;
				linebrk := chh;
				inc(c);
				if c^ = #10 then nx := left else dec(c);
			end;
			'\': begin
				inc(c);
				case c^ of
					'n': begin
						if d <> '' then render;
						nx := left;
						ny := ny + linebrk;
						linebrk := chh;
					end;
					'u': begin
						if d <> '' then render;
						nx := left;
						ny := ny - linebrk;
						linebrk := chh;
					end;
					't': begin
					end;
					else d := d + c^;
				end;
			end;
			'[': begin
				inc(c);
				if d <> '' then render;
				t := '';
				while not (c^ in [#0, ':', ']']) do begin
					t := t + c^;
					inc(c);
				end;
				case c^ of
					#0 : break;
					']': begin
						if t = 'TL'   then Centered := false else
						if t = 'TC'   then Centered := true else
						if t = 'LINE' then begin
							nx := left;
							ny := ny + linebrk;
							linebrk := chh;
							if not CalcRect then begin
								MoveToEx(TDC, nx - 5, ny + chh{} div 2, nil);
								LineTo(TDC, nx - 5 + AW + 10, ny + chh{} div 2);
							end;
							ny := ny + chh;
						end else
							break;
					end;
					':': begin
						inc(c);
						d := '';
						while not (c^ in [#0, ']']) do begin
							d := d + c^;
							inc(c);
						end;
						case c^ of
							#0 : break;
							']': begin
								if t = 'RGB' then begin
									v.v := HTC(d);
									Color := V;
								end else
								if t = 'SIZE' then Size := STI(d) else
								if t = 'FONT' then Font := STI(d) else
								;
								d := '';
							end;
						end;
					end;
				end;
			end;
			'{': begin
				PushAll;
				inc(c);
				if d <> '' then render;
				iw := nx - X;
				ih := ny - Y;
				dec(AW, iw);
				dec(AH, ih);
				inc(c, RenderText(c, left, nx, ny, AW, AH, CalcRect));
				inc(AW, iw);
				inc(AH, ih);
				PopAll;
				Centered := false;
			end;
			else d := d + c^;
		end;
		inc(c);
	end;
	if d <> '' then Render;
	result := Cardinal(c) - Cardinal(a);
	x := nx;
	y := ny;
end;

procedure TRTFRenderer.PopA(Attribs: TRTAttributes);
var
	a: TRTAttribute;
begin
	for a:=Low(a) to High(a) do
		if a in Attribs then begin
			Top[a] := Top[a] - 1;
			Assign(a);
		end;
end;

procedure TRTFRenderer.PushA(Attribs: TRTAttributes);
var
	a: TRTAttribute;
	v: PAttrRec;
begin
	for a := Low(a) to High(a) do
		if a in Attribs then begin
			v := Stack[a];
			Top[a] := Top[a] + 1;
			Get(a, v);
		end;
end;

procedure TRTFRenderer.PopAll;
begin
//	PopA([rta_font, rta_color, rta_size]);
	Top[rta_color] := Top[rta_color] - 1;
	Assign(rta_color);
end;

procedure TRTFRenderer.PushAll;
var
	v: PAttrRec;
begin
//	PushA([rta_font, rta_color, rta_size]);
	v := Stack[rta_color];
	Top[rta_color] := Top[rta_color] + 1;
	Get(rta_color, v);
end;

function TRTFRenderer.getStack(Attr: TRTAttribute): PAttrRec;
begin
	result := @fAttrStack[Attr, Top[Attr]];
end;

function TRTFRenderer.getTop(Attr: TRTAttribute): Byte;
begin
	result := fTopStack[Attr];
end;

procedure TRTFRenderer.setTop(Attr: TRTAttribute; const Value: Byte);
begin
	if Value >= 10 then
		fTopStack[Attr] := 0
	else
		fTopStack[Attr] := Value;
end;

procedure TRTFRenderer.Assign(Attr: TRTAttribute);
var
	v: TAttrRec;
begin
	v := Stack[Attr]^;
	if Attr = rta_color then Color := v;
	{case Attr of
		rta_font : begin
			Font := v.V;
		end;
		rta_color: begin
			Color := v;
		end;
		rta_size : begin
			Size := v.S;
		end;
	end;  }
end;

procedure TRTFRenderer.Get(Attr: TRTAttribute; Val: PAttrRec);
begin
	Stack[Attr]^ := Val^;
end;

function TRTFRenderer.getFont: Cardinal;
begin
	result := Stack[rta_font].V;
end;

procedure TRTFRenderer.setFont(const Value: Cardinal);
begin
	Stack[rta_font].V := Value;
end;

function TRTFRenderer.getColor: TAttrRec;
begin
	result := Stack[rta_color]^;
end;

procedure TRTFRenderer.setColor(const Value: TAttrRec);
begin
	Stack[rta_color]^ := Value;
	SetTextColor(TDC, Value.V);
end;

function TRTFRenderer.getSize: Integer;
begin
	result := Stack[rta_size].S;
end;

procedure TRTFRenderer.setSize(const Value: Integer);
begin
	Stack[rta_size].S := Value;
end;

constructor TRTFRenderer.Create;
begin
	Size := 1;
	Font := 0;
	Stack[rta_color].V := $000000;
	PushAll;
end;

procedure TRTFRenderer.Bind(DC: HDC);
begin
	TDC := DC;
end;

procedure TRTFRenderer.CalcRect(S: PAnsiChar; X, Y: Integer; out AW, AH: Integer);
begin
	AW := 0;
	AH := 0;
	RenderText(S, X, X, Y, AW, AH, True);
end;

procedure TRTFRenderer.RenderText(S: PAnsiChar; X, Y, AW, AH: Integer);
var
	t: TStackPtr;
begin
	t := fTopStack;
	RenderText(S, X, X, Y, AW, AH, False);
	fTopStack := t;
end;

end.
