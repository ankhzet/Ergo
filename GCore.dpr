library GCore;
uses
		WinAPI
	, pngimage
	, Graphics
	, jpeg
	, gifimg
	, file_sys;

type
	PImage   =^TImage;
	TImage   = record
		Handle : HBitmap;
		Path   : AnsiString;
		Width  : Integer;
		Height : Integer;
		Prev   : PImage;
		Next   : PImage;
	end;

var
	Head     : PImage;
	Loader   : TPicture;

const
	DLL_PROCESS_DETACH = 0;
	DLL_PROCESS_ATTACH = 1;
	DLL_THREAD_ATTACH  = 2;
	DLL_THREAD_DETACH  = 3;

procedure Init; forward;
procedure DeInit; forward;

procedure DllMain(fdwReason: Integer);
begin
	case fdwReason of
		DLL_PROCESS_ATTACH: Init;
		DLL_PROCESS_DETACH: DeInit;
	end;
end;

procedure _il_add(var i: PImage; n: PImage);
begin
	n.Prev := nil;
	n.Next := i;
	i.Prev := n;
	i := n;
end;

function _il_new: PImage;
begin
	New(result);
	result.Handle := 0;
	result.Path := '';
	result.Width := 0;
	result.Height := 0;
	result.Next := nil;
end;

procedure _il_free1(var i: PImage);
var
	t, p, n: PImage;
begin
	t := i;
	p := i.Prev;
	n := i.Next;
	if n <> nil then n.Prev := p;
	if p <> nil then p.Next := n;
	if p <> nil then i := p else i := n;

	Dispose(t);
end;

procedure _il_free(var i: PImage);
begin
	while i <> nil do
		_il_free1(i);
end;

procedure Init;
begin
	Head := nil;
	Loader := TPicture.Create;
end;

procedure DeInit;
begin
	Loader.Free;
	_il_free(Head);
end;

function _image_load(Path: AnsiString): PImage;
var
	B: TBitmap;
begin
	result := nil;
	if not FileExists(Path) then exit;
	B := TBitmap.Create;
	try
		try
			Loader.LoadFromFile(Path);
			B.Assign(Loader.Graphic);
			result := _il_new;
			result.Path := Path;
			result.Width := B.Width;
			result.Height := B.Height;
			result.Handle := B.ReleaseHandle;
		except

		end;
	finally
		B.Free;
	end;
end;

procedure _image_draw(i: PImage; DC, TDC: HDC; X, Y, W, H: Integer);
begin
	if i = nil then exit;
	SelectObject(TDC, i.Handle);
	StretchBlt(DC, X, Y, W, H, TDC, 0, 0, i.Width, i.Height, SRCCOPY);
end;

begin
	@DllProc := @DLLMain;
end.
