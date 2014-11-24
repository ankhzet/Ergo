unit bmp;
interface
uses
	WinAPI, Streams;

type
	TPixelFormat = (pfDevice, pf1bit, pf4bit, pf8bit, pf15bit, pf16bit, pf24bit, pf32bit, pfCustom);
	TRGBQuad    = record
		case Integer of
			0: (bR, bG, bB : Byte;
					bReserved  : Byte);
			1: (IntVal     : Integer);
	end;
	TBitmap     = class
	private
		bmi       : TBitmapInfo;
		fBits     : array of Byte;
		fHandle   : HBITMAP;
    fPalette: HPalette;
		procedure   UpdateBitmap;
		function    getBits(X, Y: Integer): TRGBQuad;
		procedure   setBits(X, Y: Integer; const Value: TRGBQuad);
		function    getHeight: Integer;
		function    getWidth: Integer;
		function    getHandle: HBITMAP;
		function    CopyImage: HBITMAP;
		function    getData: Pointer;
		procedure   setHeight(const Value: Integer);
		procedure   setWidth(const Value: Integer);
		function    getBPP: Integer;
		procedure   setBPP(const Value: Integer);
		function    getScanLine(L: Integer): Pointer;
		procedure   setHandle(const Value: HBITMAP);
    procedure setPalette(const Value: HPalette);
	public
		constructor Create; virtual;
    procedure   Assign(Source: TBitmap); virtual;
		function    LoadFromFile(FileName: AnsiString): Boolean;
		function    LoadFromStream(S: TStream): Boolean; virtual;
		function    SaveToFile(FileName: AnsiString): Boolean;
		property    Bits[X, Y: Integer]: TRGBQuad read getBits write setBits; default;
		property    ScanLine[L: Integer]: Pointer read getScanLine;
		property    Data: Pointer read getData;
		property    Width: Integer read getWidth write setWidth;
		property    Height: Integer read getHeight write setHeight;
		property    BPP: Integer read getBPP write setBPP;
		property    Handle: HBITMAP read getHandle write setHandle;
		property    Palette: HPalette read fPalette write setPalette;
	end;
	TGraphicClass = class of TBitmap;

const
	C_BPP: array[TPixelFormat] of Byte = (
		0, 1, 4, 8, 15, 16, 24, 32, 0
	);

implementation
uses
	WinAPI_GDIInterface
//	packages
	;

{ TBitmap }

constructor TBitmap.Create;
begin
	FillChar(bmi, sizeOf(bmi), 0);
	bmi.bmiHeader.biBitCount := 32;
	fHandle := 0;
end;

function TBitmap.getHeight: Integer;
begin
	result := bmi.bmiHeader.biHeight;
	if result = 0 then result := 1;
end;

function TBitmap.getWidth: Integer;
begin
	result := bmi.bmiHeader.biWidth;
	if result = 0 then result := 1;
end;

function TBitmap.getBPP: Integer;
begin
	result := bmi.bmiHeader.biBitCount;
	if result = 0 then result := 1;
end;

function TBitmap.SaveToFile(FileName: AnsiString): Boolean;
var
	h: TBitmapFileHeader;
	f: File of Byte;
label
	fail, norm;
begin
	result := false;
	AssignFile(F, FileName);
	Rewrite(F);
	if IOResult <> 0 then exit;
	try
		FillChar(h, sizeof(TBitmapFileHeader), 0);
		h.bfType := $4D42;
		with bmi do begin
			with bmiHeader do begin
				biSize := sizeof(bmiHeader);
				biPlanes := 1;
				biCompression := 0;
				if biClrUsed = 0 then biClrUsed := 1 shl biBitCount;
				if biSizeImage = 0 then            // top-down DIBs have negative height
					biSizeImage := ((((biWidth * biBitCount) + 31) and not 31) div 8) * Abs(biHeight);
				h.bfSize := sizeof(h) + bisize + biSizeImage;
				h.bfOffBits := sizeof(h) + biSize;
				BlockWrite(F, h, sizeof(h));
				BlockWrite(F, bmiHeader, biSize);
				BlockWrite(F, fBits[0], biSizeImage);
			end;
		end;
		result := true;
	finally
		Close(F);
	end;
end;

function TBitmap.getScanLine(L: Integer): Pointer;
begin
	result := @fBits[L * Width * (bmi.bmiHeader.biBitCount div 8)];
end;

procedure TBitmap.setBits(X, Y: Integer; const Value: TRGBQuad);
begin
	if Bits[X, Y].IntVal <> Value.IntVal then begin
		Move(Value, (@fBits[(X + Y * Width) * (bmi.bmiHeader.biBitCount div 8)])^, bmi.bmiHeader.biBitCount div 8);
		UpdateBitmap;
	end;
end;

procedure TBitmap.setBPP(const Value: Integer);
begin
	bmi.bmiHeader.biBitCount := Value;
	setLength(fBits, Width * Height * (BPP div 8));
	SetDIBits(0, Handle, 0, Height, @fBits[0], bmi, 0);
	UpdateBitmap;
end;

procedure TBitmap.setHandle(const Value: HBITMAP);
begin
	if Value <> fHandle then begin
//		DeleteObject(fHandle);
		fHandle := Value;
	end;
end;

procedure TBitmap.setHeight(const Value: Integer);
begin
	bmi.bmiHeader.biHeight := Value;
	setLength(fBits, Width * Height * (BPP div 8));
	SetDIBits(0, Handle, 0, Height, @fBits[0], bmi, 0);
	UpdateBitmap;
end;

procedure TBitmap.setPalette(const Value: HPalette);
begin
	if fPalette <> Value then begin
		DeleteObject(fPalette);
		fPalette := Value;
	end;
end;

procedure TBitmap.setWidth(const Value: Integer);
begin
	bmi.bmiHeader.biWidth := Value;
	setLength(fBits, Width * Height * (BPP div 8));
	SetDIBits(0, Handle, 0, Height, @fBits[0], bmi, 0);
	UpdateBitmap;
end;

function TBitmap.getBits(X, Y: Integer): TRGBQuad;
begin
	Move((@fBits[(X + Y * Width) * (bmi.bmiHeader.biBitCount div 8)])^, result, bmi.bmiHeader.biBitCount div 8);
end;

function TBitmap.getData: Pointer;
begin
	result := @fBits[0];
end;

procedure TBitmap.UpdateBitmap;
var
	TDC: HDC;
	BM : HBITMAP;
begin
	TDC := GetDC(0);
	BM := CopyImage;
	DeleteObject(fHandle);
	if Palette <> 0 then SelectPalette(TDC, Palette, false);
	SetDIBits(TDC, BM, 0, Height, @fBits[0], bmi, 0);
	fHandle := BM;
	ReleaseDC(0, TDC);
end;

function TBitmap.getHandle: HBITMAP;
begin
	if fHandle = 0 then UpdateBitmap;
	result := fHandle;
end;

procedure TBitmap.Assign(Source: TBitmap);
begin

end;

function TBitmap.CopyImage: HBITMAP;
var
	TDC, DC1, DC2: HDC;
	H, T1, T2: HBITMAP;
begin
	H := fHandle;
	TDC := GetDC(0);
	DC1 := CreateCompatibleDC(TDC);
	DC2 := CreateCompatibleDC(TDC);
	result := CreateCompatibleBitmap(TDC, Width, Height);
	ReleaseDC(0, TDC);

	T1 := SelectObject(DC1, H);
	T2 := SelectObject(DC2, result);
	BitBlt(DC2, 0, 0, Width, Height, DC1, 0, 0, SRCCOPY);
	SelectObject(DC1, T1);
	SelectObject(DC2, T2);
	DeleteDC(DC1);
	DeleteDC(DC2);
end;

function TBitmap.LoadFromStream(S: TStream): Boolean;
var
	h: TBitmapFileHeader;
	HeaderSize: Integer;
label
	fail, norm;
begin
	with S do
	try
		Read(@h, SizeOf(h));
		if h.bfType <> $4D42 then goto fail;
		Read(@HeaderSize, SizeOf(HeaderSize));
		with bmi do begin
			Read(Pointer(Longint(@bmi) + sizeof(HeaderSize)), HeaderSize - sizeof(HeaderSize));
			with bmiHeader do begin
				biSize := HeaderSize;
				if biPlanes <> 1 then goto fail;
				if biClrUsed = 0 then biClrUsed := 1 shl biBitCount;
				if biSizeImage = 0 then            // top-down DIBs have negative height
					biSizeImage := ((((biWidth * biBitCount) + 31) and not 31) div 8) * Abs(biHeight);
					SetLength(fBits, biSizeImage);
					Read(@fBits[0], biSizeImage);
			end;
		end;
		UpdateBitmap;
		goto norm;
	fail:
		if fHandle <> 0 then DeleteObject(fHandle);
		fHandle := 0;
	norm:
		result := fHandle <> 0;
	except
		result := false;
	end;
end;

function TBitmap.LoadFromFile(FileName: AnsiString): Boolean;
var
	S: TStream;
begin
	try
		S := TFileStream.Create(FileName, fmOpen);
		try
			result := LoadFromStream(S);
			UpdateBitmap;
		finally
			S.Free;
		end;
	except
		result := false;
	end;
end;

end.
