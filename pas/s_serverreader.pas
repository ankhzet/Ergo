unit s_serverreader;
interface
uses
	mt_engine, s_engine, s_config, s_httpproxy;

type
	TPTKind     = (ptk_helper, ptk_between);
	TPTKinds    = set of TPTKind;
	TReader     = class;
	TParseToken = class
	private
		fPrefix   : AnsiString;
		fSource   : AnsiString;
		fPostfix  : AnsiString;
		fReader   : TReader;
		fName     : AnsiString;
		fParsed   : Boolean;
		fContent  : AnsiString;
		fKind     : TPTKinds;
	public
		constructor Create(R: TReader; Name, Src, Pre, Post: AnsiString; Kind: TPTKinds = []);
		procedure   Init;
		function    ParseData(Data: AnsiString): Integer;

		property    Reader: TReader read fReader;
		property    Name: AnsiString read fName;
		property    Source: AnsiString  read fSource;
		property    Prefix: AnsiString  read fPrefix;
		property    Postfix: AnsiString read fPostfix;

		property    Content: AnsiString read fContent;

		property    Parsed: Boolean read fParsed;
		property    Kind: TPTKinds read fKind;
	end;

	TMangaInfo  = (mi_manga, mi_chapter, mi_chapters, mi_mangalist);
	TReader     = class(THTTPProxy)
	private
		fCount    : Integer;
		fData     : array of TParseToken;
		Sorted    : Boolean;
		procedure   Sort;

		function    getToken(Index: Integer): TParseToken;
		procedure   setCount(const Value: Integer);
	protected
		procedure   InitReader; virtual;
		function    ZipPage(Data: AnsiString): AnsiString;

		function    RetriveMangaDesc(Manga: AnsiString; Info: TConfigNode): Integer; virtual;
		function    RetriveMangaChaps(Manga: AnsiString; Info: TConfigNode): Integer; virtual;
		function    RetriveMangaChap(Manga: AnsiString; Info: TConfigNode): Integer; virtual;
		function    RetriveMangas(Info: TConfigNode): Integer; virtual;
	public
		constructor Create; override;
		function    DataToString: AnsiString;
		function    RegisterToken(Name, Src, Pre, Post: AnsiString; Kind: TPTKinds = []): Integer;

		function    RetriveInfo(What: TMangaInfo; Info: TConfigNode; Req: AnsiString = ''): Integer;

		function    MakeHost(H: AnsiString): AnsiString; virtual;
		function    MakeURI(U, Link: AnsiString; Chap: Integer): AnsiString; virtual;
		function    ParsePage(Data: AnsiString): Boolean;
		function    IndexOf(Token: AnsiString): Integer;
		function    Server: AnsiString; virtual;
		function    MakeMangaURL(Manga: AnsiString): AnsiString; virtual;
		function    MakeChaptURL(Chapter: Integer): AnsiString; virtual;
		function    MakePageURL(Page: Integer): AnsiString; virtual;

		property    Tokens: Integer read fCount write setCount;
		property    Token[Index: Integer]: TParseToken read getToken; default;
	end;
	TManga24Rdr = class(TReader)
	private
	protected
		procedure   InitReader; override;
	public
		function    MakeHost(H: AnsiString): AnsiString; override;
		function    MakeURI(U, Link: AnsiString; Chap: Integer): AnsiString; override;
		function    Server: AnsiString; override;
	end;
	TReaders    = class(TParamNode)
	private
	public
		Mangas    : TConfigNode;
		function    Register(Reader: TReader): TReader;
		function    Find(Server: AnsiString): TReader; overload;
		function    Find(UID: Cardinal): TReader; overload;
	end;

var
	Readers: TReaders = nil;

implementation
uses
	WinAPI, strings;

{ TParseToken }

constructor TParseToken.Create(R: TReader; Name, Src, Pre, Post: AnsiString; Kind: TPTKinds);
begin
	fParsed := false;
	fReader := R;
	fName   := Name;
	fSource := Src;
	fPrefix := Pre;
	fPostfix:= Post;
	fKind   := Kind;
end;

procedure TParseToken.Init;
begin
	fParsed := false;
	fContent:= '';
end;

function Trim(s: AnsiString): AnsiString;
var
	i, j: Integer;
begin
	i := 1;
	j := Length(s);
	while (i <= j) and (s[i] in [#9, #10, #13, #32]) do inc(i);
	while (i <= j) and (s[j] in [#9, #10, #13, #32]) do dec(j);
	if i <= j then
		SetString(result, PAnsiChar(@s[i]), j - i + 1)
	else
		result := '';
end;

function TParseToken.ParseData(Data: AnsiString): Integer;
var
	i, j, k, l: Integer;
	S: TParseToken;
label
	next, again;
begin
	if Source <> '' then begin
		i := Reader.IndexOf(Source);
		if i < 0 then; //TODO: Raise error or fail result
		S := Reader[i];
		if not S.Parsed then
			S.ParseData(Data); //TODO: error or fail result
		Data := S.Content;
	end;

	result := 0;
	i := pos(Prefix, Data);
	if i > 0 then begin
		l := Length(data);
		inc(i, Length(Prefix));
		result := pos(Postfix, PAnsiChar(@Data[i])) - 1;
		j := i;
		next:
		while j < i + result do begin
			if Data[j] = '"' then begin // found " search forward
				k := j + 1;
				again:
				while (k < i + result) do begin
					if data[k] = '"' then begin// enclosed ", search next
						j := k + 1;
						goto next;
					end;
					inc(k);
				end;
				// unclosed ", shifting [result] pointer
				inc(result, pos(Postfix, PAnsiChar(@Data[i + result + 1])));
				if result > l - i then begin // found [Postfix] past [eof]
					result := 0;
					break;
				end;
				goto again; // must find closing ", or [eof]
			end;
			inc(j);
		end;
		fContent := Trim(copy(Data, i, result));
		inc(result, i + Length(Postfix));
	end else
		fContent := '';
	fParsed  := true;
end;

{ TReader }

procedure TReader.InitReader;
begin

end;

constructor TReader.Create;
begin
	inherited Create;
	Name := Server;
	InitReader;
end;

function TReader.getToken(Index: Integer): TParseToken;
begin
	result := fData[Index];
end;

function TReader.IndexOf(Token: AnsiString): Integer;
var
	l, h, c: Integer;
begin
	h := Tokens - 1;
	if h >= 0 then begin
		l := 0;
		if not Sorted then Sort;
		repeat
			result := (l + h) div 2;
			c := lstrcmpi(@fData[result].Name[1], @Token[1]);
			if c = 0 then exit;
			if c < 0 then
				l := result + 1
			else
				h := result - 1;
		until l > h;
	end;
	result := -1;
end;

procedure TReader.setCount(const Value: Integer);
begin
	if fCount <> Value then begin
		fCount := Value;
		setLength(fData, Value);
		Sorted := Value < 2;
	end;
end;

procedure TReader.Sort;
var
	i: Integer;
	t: TParseToken;
begin
	repeat
		Sorted := true;
		for i := 0 to Tokens - 2 do begin
			if lstrcmpi(@fData[i].Name[1], @fData[i + 1].Name[1]) > 0 then begin
				t := fData[i + 1];
				fData[i + 1] := fData[i];
				fData[i] := t;
				Sorted := false;
			end
		end;
	until Sorted;
end;

function TReader.ParsePage(Data: AnsiString): Boolean;
var
	i: integer;
begin
	i := Tokens;
	while i > 0 do begin
		dec(i);
		fData[i].Init;
	end;

	if not Sorted then Sort;
	i := Tokens;
	while i > 0 do begin
		dec(i);
		if ptk_helper in fData[i].Kind then continue;

		fData[i].ParseData(Data);
	end;
	result := true;
end;

function TReader.Server: AnsiString;
begin
	result := '?dummy server reader';
end;

function TReader.MakeHost(H: AnsiString): AnsiString;
begin
end;

function TReader.MakeURI(U, Link: AnsiString; Chap: Integer): AnsiString;
begin
end;

function TReader.MakeChaptURL(Chapter: Integer): AnsiString;
begin
	Str(Chapter, result);
	while Length(result) < 3 do result := '0' + result;
	result := '/' + result;
end;

function TReader.MakeMangaURL(Manga: AnsiString): AnsiString;
begin
	result := '/' + Manga;
end;

function TReader.MakePageURL(Page: Integer): AnsiString;
begin
	Str(Page, result);
	while Length(result) < 3 do result := '0' + result;
	result := '/' + result;
end;

function TReader.RegisterToken(Name, Src, Pre, Post: AnsiString; Kind: TPTKinds): Integer;
begin
	result := Tokens;
	Tokens := result + 1;
	fData[result] := TParseToken.Create(Self, Name, Src, Pre, Post, Kind);
end;

function TReader.ZipPage(Data: AnsiString): AnsiString;
var
	i, l, r: Integer;
	c      : AnsiChar;
	procedure Add;
	begin
		inc(r);
		result[r] := c;
	end;
begin
	i := 1;
	l := Length(Data);
	SetLength(result, l * 2);
	r := 0;
	try
		while i <= l do begin
			c := Data[i];
			case c of
				#13: if (i < l) and (Data[i + 1] = #10) then inc(i);
				#9 : ;
				' ': if (i < l) and (not (Data[i + 1] in [#9, #10, #13, #32])) then Add;
				'''': begin
					c := '&'; Add;
					c := 'q'; Add;
					c := 't'; Add;
					c := ';'; Add;
				end;
				else Add;
			end;
			inc(i);
		end;
	except
		r := r;
	end;
	SetLength(result, r);
end;

function TReader.RetriveInfo(What: TMangaInfo; Info: TConfigNode; Req: AnsiString): Integer;
begin
	if Req <> '' then Req := LowerCase(Req);
	case What of
		mi_manga    : result := RetriveMangaDesc(Req, Info);
		mi_chapter  : result := RetriveMangaChap(Req, Info);
		mi_chapters : result := RetriveMangaChaps(Req, Info);
		mi_mangalist: result := RetriveMangas(Info);
		else          result := 0;
	end;
end;

function TReader.RetriveMangaChap(Manga: AnsiString; Info: TConfigNode): Integer;
var
	E   : AnsiString;
	i, j: Integer;
	t1,
	t2,
	t3  : TParseToken;
	S   : PAnsiChar;
	l   : TList;
begin
	if Request(Server, MakeMangaURL(Manga)) then begin
		E := ZipPage(Content);

		with Info do begin
			AddParam(TString, 'mirror');
			AddParam(TString, 'pages');
			AddParam(TList  , 'data');
			t1 := Token[IndexOf('pages_m')];
			t1.ParseData(E);
			Int['mirror'] := sti(T1.Content);

			T1 := Token[IndexOf('pages_all')];
			i := T1.ParseData(E);
			if i > 0 then
				try
					l := TList(Info.Find('data'));
					l.Pairs := true;
					S := @T1.Content[1];
					T1 := Token[IndexOf('pages_i')];
					T2 := Token[IndexOf('pages_s')];
//					T3 := Token[IndexOf('chaps_t_t')];
					j := 0;
					repeat
						i := T1.ParseData(S);
						if i <= 0 then break;
						inc(j);
						T2.ParseData(T1.Content);
//						T3.ParseData(T1.Content);
						l.Add(ITS(j), T2.Content);
						S := PAnsiChar(Cardinal(S) + i);
					until false;
					Int['pages'] := j;
					result := 0;
				except
					result := -3;
				end
			else
				result := -2;
		end;
	end else
		result := -1;
end;

function TReader.RetriveMangaChaps(Manga: AnsiString; Info: TConfigNode): Integer;
var
	E   : AnsiString;
	i   : Integer;
	t1,
	t2,
	t3  : TParseToken;
	S   : PAnsiChar;
	C   : TChapter;
	l   : TList;
begin
	if Request(Server, MakeMangaURL(Manga)) then begin
		E := ZipPage(Content);

		T1 := Token[IndexOf('chaps_t_all')];
		i := T1.ParseData(E);
		if i > 0 then
			try
				l := TList(Info.Find('chaps'));
//				Pairs := true;
				S := @T1.Content[1];
				T1 := Token[IndexOf('chaps_t_i')];
				T2 := Token[IndexOf('chaps_t_n')];
				T3 := Token[IndexOf('chaps_t_t')];
				repeat
					i := T1.ParseData(S);
					if i <= 0 then break;
					T2.ParseData(T1.Content);
					T3.ParseData(T1.Content);
					c := TChapter(l.Get(t2.Content));
					if c <> nil then
						c['title'] := t3.Content;
					S := PAnsiChar(Cardinal(S) + i);
				until false;
				result := 0;
			except
				result := -3;
			end
		else
			result := -2;
	end else
		result := -1;
end;

function TReader.RetriveMangaDesc(Manga: AnsiString; Info: TConfigNode): Integer;
var
	E   : AnsiString;
	i, j: Integer;
	t1,
	t2,
	t3  : TParseToken;
	S   : PAnsiChar;
	C   : TChapter;
	procedure ParseLists(L: TList; S: AnsiString; Sep: AnsiChar);
	var
		p: PAnsiChar;
		t: AnsiString;
	begin
		p:= @S[1];
		t := '';
		while p^ <> #0 do begin
			if p^ = Sep then begin

				L.Add(Trim(t));
				t := '';
			end else
				t := t + p^;
			inc(p);
		end;
		if t <> '' then L.Add(Trim(T));
	end;
begin
	if Request(Server, MakeMangaURL(Manga)) then begin
		E := ZipPage(Content);
{		i := IndexOf('charset');
		if i >= 0 then Token[i].ParseData(E);
		if ((i >=0) and Contains('utf-8', [PAnsiChar(Token[i].Content)]))
			or Contains('utf-8', [PAnsiChar(Headers.GetHeader('content-type'))]) then
				E := Utf8ToAnsi(E);  }

		if ParsePage(E) then
			with Info do try
				AddParam(TString, 'title');
				AddParam(TList  , 'alts');
				AddParam(TString, 'desc');
				AddParam(TList  , 'trans');
				AddParam(TList  , 'jenres');
				AddParam(TList  , 'chaps');

				Str['title']    := Token[IndexOf('title')].Content;
				ParseLists(List['alts'], Token[IndexOf('altnames')].Content + ', ' + Str['title'], ',');
				Str['desc']     := Token[IndexOf('desc')].Content;
				T1 := Token[IndexOf('jenres_all')];
				i := T1.ParseData(E);
				if i > 0 then
					with TList(Find('jenres')) do try
						S := @T1.Content[1];
						T1 := Token[IndexOf('jenres_i')];
						T2 := Token[IndexOf('jenres_l')];
//							T3 := Token[IndexOf('jenres_t')];

						repeat
							i := T1.ParseData(S);
							if i <= 0 then break;
							T2.ParseData(T1.Content);
//								T3.ParseData(T1.Content);
							Add(t2.Content{, T3.Content});
							S := PAnsiChar(Cardinal(S) + i);
						until false;
					except
						result := -3;
						exit;
					end
				else begin
					result := -2;
					exit;
				end;

				T1 := Token[IndexOf('chaps_all')];
				i := T1.ParseData(E);
				if i > 0 then
					with TList(Find('chaps')) do try
						ClassRef := TChapter;
						S := @T1.Content[1];
						T1 := Token[IndexOf('chaps_i')];
						T2 := Token[IndexOf('chaps_n')];
						T3 := Token[IndexOf('chaps_t')];

						j := 0;
						repeat
							i := T1.ParseData(S);
							if i <= 0 then break;
							T2.ParseData(T1.Content);
							T3.ParseData(T1.Content);
							c := TChapter.Create(T2.Content);
							c['id'] := ITS(j);
							inc(j);
							c['trans'] := t3.Content;
							InsertChild(c);
							S := PAnsiChar(Cardinal(S) + i);
						until false;
						c := TChapter(Childs);
						while c <> nil do begin
							c.Int['id'] := j - c.Int['id'];
							c := TChapter(c.Next);
						end;
					except
						result := -3;
						exit;
					end
				else begin
					result := -2;
					exit;
				end;
				result := 0;
			except
				result := -3;       // result: Assignment exception
				exit;
			end
		else
			result := -2;         // result: Parse fail
	end else
		if RespCode <> 404 then
			result := -1          // result: Request failed
		else
			result := -4;         // result: Manga not found
end;

function TReader.RetriveMangas(Info: TConfigNode): Integer;
var
	E: AnsiString;
	S: PAnsiChar;
	i: Integer;
	t1, t2, t3: TParseToken;
begin
	if Request(Server, '/') then begin
		E := ZipPage(Content);
{		i := IndexOf('charset');
		if i >= 0 then Token[i].ParseData(E);
		if ((i >=0) and Contains('utf-8', [PAnsiChar(Token[i].Content)]))
			or Contains('utf-8', [PAnsiChar(Headers.GetHeader('content-type'))]) then
				E := Utf8ToAnsi(E);     }

		T1 := Token[IndexOf('list_all')];
		i := T1.ParseData(E);
		if i > 0 then
			with TList(Info.InsertChild(TList.Create(ITS(UID)))) do begin
				Pairs := true;
				try
					S := @T1.Content[1];
					T1 := Token[IndexOf('list_i')];
					T2 := Token[IndexOf('list_r')];
					T3 := Token[IndexOf('list_t')];

					repeat
						i := T1.ParseData(S);
						if i <= 0 then break;
						T2.ParseData(T1.Content);
						T3.ParseData(T1.Content);
						Add(t2.Content, T3.Content);
						S := PAnsiChar(Cardinal(S) + i - 1);
					until false;
				except
					result := -3;
				end;
			end
		else
			result := -2;
	end else
		result := -1;
end;

function TReader.DataToString: AnsiString;
var
	i: Integer;
begin
	i := Tokens;
	while i > 0 do begin
		dec(i);
		with fData[i] do
			if Parsed and not (ptk_helper in Kind) then
			result := strJoin(';', [result, Name + ': "' + Content + '"']);
	end;
	result := '{' + result + '}';
end;

{ TManga24Rdr }

procedure TManga24Rdr.InitReader;
begin
	RegisterToken('charset', '', 'charset=', '"');
	RegisterToken('title', '', '<h1>', '</h1>');
	RegisterToken('altnames', '', '<h3>', '</h3>');
	RegisterToken('desc', '', '</p><p>', '</p><p> Перевод');

	RegisterToken('chaps_t_all', '', '<div id="chapters">', '<div id="menu">', [ptk_helper]);
	RegisterToken('chaps_t_i', '', '<option value', '/option>', [ptk_helper]);
	RegisterToken('chaps_t_n', '', '="', '"', [ptk_helper]);
	RegisterToken('chaps_t_t', '', '>', '<', [ptk_helper]);

	RegisterToken('pages_all', '', 'images: [', 'page: ', [ptk_helper]);
	RegisterToken('pages_m', '', 'mirror: ', ',', [ptk_helper]);
	RegisterToken('pages_i', '', '[', ']', [ptk_helper]);
	RegisterToken('pages_s', '', '"', '"', [ptk_helper]);
	RegisterToken('pages_d', '', ',', '', [ptk_helper]);

	RegisterToken('chaps_all', '', 'Главы на русском:', '</em></li></ul></div>', [ptk_helper]);
	RegisterToken('chaps_i', '', '<li><em', '/em>', [ptk_helper]);
	RegisterToken('chaps_n', '', '>', '<', [ptk_helper]);
	RegisterToken('chaps_t', '', 'от ', '</i>', [ptk_helper]);

	RegisterToken('jenres_all', '', 'Жанр: ', '</p>', [ptk_helper]);
	RegisterToken('jenres_i', '', '<a href=', '/a>', [ptk_helper]);
	RegisterToken('jenres_l', '', 'genres/', '/"', [ptk_helper]);
	RegisterToken('jenres_t', '', '>', '<', [ptk_helper]);

	RegisterToken('list_all', '', 'Выберите мангу:</option>', '</select>', [ptk_helper]);
	RegisterToken('list_i', '', '<option value=', '/option>', [ptk_helper]);
	RegisterToken('list_r', '', '/', '/">', [ptk_helper]);
	RegisterToken('list_t', '', '>', '<', [ptk_helper]);
end;

function TManga24Rdr.MakeHost(H: AnsiString): AnsiString;
begin
	result := 'img' + H + '.' + Server;
end;

function TManga24Rdr.MakeURI(U, Link: AnsiString; Chap: Integer): AnsiString;
begin
	result := '/' + Link + MakeChaptURL(Chap) + '/' + U;
end;

function TManga24Rdr.Server: AnsiString;
begin
	result := 'manga24.ru';
end;

{ TReaders }

function TReaders.Find(Server: AnsiString): TReader;
begin
	result := TReader(inherited Find(Server));
end;

function TReaders.Find(UID: Cardinal): TReader;
begin
	result := TReader(inherited Find(UID));
end;

function TReaders.Register(Reader: TReader): TReader;
begin
	result := Find(Reader.Name);
	if result <> nil then exit;

	InsertChild(Reader);
end;

initialization
	Readers := TReaders.Create('');
finalization
	Readers.Free;
end.
