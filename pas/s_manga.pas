unit s_manga;
interface
uses
	streams;

type
	TUniEntity    = class
	private
		fName       : AnsiString;
		fUID        : Cardinal;
	public
		constructor   Create(UID: Cardinal); virtual;
		function      LoadFromStream(Stream: TStream): Boolean; virtual;
		function      SaveToStream(Stream: TStream): Boolean; virtual;
		property      Name: AnsiString read fName write fName;
		property      UID: Cardinal read fUID;
	end;
	TUniList      = class
	private
		fData       : array of TUniEntity;
		Sorted      : Boolean;
		fCount      : Integer;
		procedure     Sort;
		function      getEntity(Index: Integer): TUniEntity;
		procedure     setCount(const Value: Integer);
	protected
		function      Managed: TClass; virtual;
	public
		function      Add: Integer;
		function      IndexOf(Name: AnsiString): Integer; overload;
		function      IndexOf(UID: Cardinal): Integer; overload;
		function      Delete(Index: Integer): Integer;
		procedure     Cleanup;

		function      LoadFromStream(Stream: TStream): Boolean; virtual;
		function      LoadFromFile(FName: AnsiString): Boolean;
		function      SaveToStream(Stream: TStream): Boolean; virtual;
		function      SaveToFile(FName: AnsiString): Boolean;

		function      GUID: Cardinal;

		property      Count: Integer read fCount write setCount;
		property      Entity[Index: Integer]: TUniEntity read getEntity; default;
	end;

	TManga        = class;
	TChapter      = class
	private
		fTitle      : AnsiString;
		fNumber     : Integer;
		fVolume     : Integer;
		fManga      : TManga;
	public
		property      Title: AnsiString read fTitle;
		property      Number: Integer read fNumber;
		property      Volume: Integer read fVolume;
		property      Manga : TManga read fManga;
	end;

	TManga        = class
	private
		fTitle      : AnsiString;
		fDescription: AnsiString;
		fSince      : Cardinal;
		fTill       : Cardinal;
		fReqAge     : Integer;
		fSource     : Cardinal;
		fAlt        : AnsiString;
	public
		constructor   Create;
		property      Title: AnsiString read fTitle write fTitle;
		property      Alt: AnsiString read fAlt write fAlt;
		property      Description: AnsiString read fDescription write fDescription;
		property      Source: Cardinal read fSource write fSource;
		property      ReqAge: Integer read fReqAge write fReqAge;
		property      Since: Cardinal read fSince write fSince;
		property      Till: Cardinal read fTill write fTill;
	end;

	TSourceReader = class
	private
		fSource     : Cardinal;
	public
		property      Source: Cardinal read fSource;
	end;
	TSource       = class(TUniEntity)
	private
		fSReader    : TSourceReader;
	public
		property      Reader: TSourceReader read fSReader;
	end;
	TSourcesList  = class(TUniList)
	private
		function      getEntity(Index: Integer): TSource;
	protected
		function      Managed: TClass; override;
	public
		property      Entity[Index: Integer]: TSource read getEntity; default;
	end;

	TMangaCollect = class(TUniList)
	private
		function      getManga(Index: Integer): TManga;
	protected
		function      Managed: TClass; override;
	public
		property      Manga[Index: Integer]: TManga read getManga; default;
	end;

implementation
uses
	WinAPI;

{ TUniEntity }

constructor TUniEntity.Create(UID: Cardinal);
begin
	fUID := UID;
end;

function TUniEntity.LoadFromStream(Stream: TStream): Boolean;
begin
	result := false;
end;

function TUniEntity.SaveToStream(Stream: TStream): Boolean;
begin
	result := false;
end;

{ TUniList }

function TUniList.Add: Integer;
begin
	result := Count;
	Count  := result + 1;
end;

function TUniList.Delete(Index: Integer): Integer;
begin
	result := Count - 1;
	fData[Index].Free;
	if Index < result then fData[Index] := fData[result];
	Count := result;
end;

function TUniList.getEntity(Index: Integer): TUniEntity;
begin
	result := fData[Index];
end;

function TUniList.GUID: Cardinal;
begin
	result := 0;
	repeat inc(result) until IndexOf(result) < 0;
end;

function TUniList.IndexOf(Name: AnsiString): Integer;
begin
	result := Count;
	if result > 0 then begin
		if not Sorted then Sort;
		while result > 0 do begin
			dec(result);
			if fData[result].Name = Name then exit;
		end;
	end;
	result := -1;
end;

function TUniList.IndexOf(UID: Cardinal): Integer;
var
	l, h: Integer;
	u   : Cardinal;
begin
	h := Count - 1;
	if h >= 0 then begin
		l := 0;
		if not Sorted then Sort;
		repeat
			result := (l + h) div 2;
			u := fData[result].UID;
			if UID = u then exit;
			if UID < u then
				h := result - 1
			else
				l := result + 1;
		until l > h;
	end;
	result := -1;
end;

procedure TUniList.setCount(const Value: Integer);
begin
	if fCount <> Value then begin
		fCount := Value;
		setLength(fData, Value);
		Sorted := Value < 2;
	end;
end;

procedure TUniList.Sort;
var
	i: Integer;
	t: TUniEntity;
begin
	repeat
		Sorted := true;
		for i := 0 to Count - 2 do
			if fData[i].UID > fData[i + 1].UID then begin
				t := fData[i + 1];
				fData[i + 1] := fData[i];
				fData[i] := t;
				Sorted := false;
			end;
	until Sorted;
end;

function TUniList.LoadFromFile(FName: AnsiString): Boolean;
var
	S: TStream;
begin
	try
		S := TFileStream.Create(FName, fmOpen);
		try
			result := LoadFromStream(S);
		finally
			S.Free;
		end
	except
		result := false;
	end;
end;

function TUniList.SaveToFile(FName: AnsiString): Boolean;
var
	S: TStream;
begin
	try
		S := TFileStream.Create(FName, fmCreateAlways);
		try
			result := SaveToStream(S);
		finally
			S.Free;
		end
	except
		result := false;
	end;
end;

function TUniList.LoadFromStream(Stream: TStream): Boolean;
var
	i: Integer;
	u: Cardinal;
	e: TUniEntity;
begin
	try
		Cleanup;
		with Stream do begin
			Read(@i, SizeOf(i));
			Count := i;
			while i > 0 do begin
				dec(i);
				Read(@u, SizeOf(Cardinal));
				e := TUniEntity(Managed).Create(u);
				result := e.LoadFromStream(Stream);
				if not result then exit;
				fData[Add] := e;
			end;
		end;
		result := true;
	except
		result := false;
	end;
end;

function TUniList.SaveToStream(Stream: TStream): Boolean;
var
	i: Integer;
begin
	try
		i := Count;
		with Stream do begin
			Write(@i, SizeOf(i));
			while i > 0 do begin
				dec(i);
				Write(@fData[i].UID, SizeOf(Cardinal));
				result := fData[i].SaveToStream(Stream);
				if not result then exit;
			end;
		end;
		result := true;
	except
		result := false;
	end;
end;

procedure TUniList.Cleanup;
var
	i: Integer;
begin
	for i := 0 to Count - 1 do fData[i].Free;
	Count := 0;
end;

function TUniList.Managed: TClass;
begin
	result := TUniEntity;
end;

{ TManga }

constructor TManga.Create;
begin

end;

{ TMangaCollec }

function TMangaCollect.getManga(Index: Integer): TManga;
begin
	result := TManga(fData[Index]);
end;

function TMangaCollect.Managed: TClass;
begin
	result := TManga;
end;

{ TSourcesList }

function TSourcesList.getEntity(Index: Integer): TSource;
begin
	result := TSource(fData[Index]);
end;

function TSourcesList.Managed: TClass;
begin
	result := TSource;
end;

end.
