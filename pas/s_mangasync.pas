unit s_mangasync;
interface
uses
		logs
	, Threads
	, mt_engine
	, s_engine
	, s_serverreader
	, s_httpproxy
	, s_config
	;

const
	MAX_SYNCS = 1;

type
	TSynhronizer= class;
	TSyncThread = class(TThread)
	private
		eReady    : THandle;
		eAvail    : THandle;
		fSync     : Integer;
		Sync      : TSynhronizer;
		procedure   DoSync;
		function   _UpdChapter(Data: TList; Chapt: TChapter; R: TReader): Boolean;
	public
		constructor Create(Synhronizer: TSynhronizer);
		destructor  Destroy; override;
		procedure   Execute; override;
		procedure   SetSync(M: Integer);

		property    Manga: Integer read fSync;
	end;
	TSynhronizer= class
	private
		eThreads  : array [0..MAX_SYNCS - 1] of THandle;
		eSyncs    : array [0..MAX_SYNCS - 1] of TSyncThread;

		Syncs     : Integer;
	public
		constructor Create;
		destructor  Destroy; override;
		function    Sync(M: Integer): Boolean;
	end;

implementation
uses
		WinAPI
	, strings
	, s_loaders
	, sql_constants
	;

{ TSynhronizer }

constructor TSynhronizer.Create;
var
	i: Integer;
begin
	for i := 0 to MAX_SYNCS - 1 do TSyncThread.Create(Self);
end;

destructor TSynhronizer.Destroy;
var
	i: Integer;
begin
	for i := 0 to MAX_SYNCS - 1 do eSyncs[i].Terminate;
	inherited;
end;

function TSynhronizer.Sync(M: Integer): Boolean;
var
	t: Cardinal;
begin
	t := WaitForMultipleObjects(MAX_SYNCS, @eThreads[0], false, 0);
	result := t < MAX_SYNCS;
	if result then
		eSyncs[t].SetSync(M)
	else
		; //TODO: query sync
end;

{ TSyncThread }

constructor TSyncThread.Create(Synhronizer: TSynhronizer);
begin
	eAvail := CreateEvent(nil, false, false, nil);
	eReady := CreateEvent(nil, false, false, nil);
	Sync   := Synhronizer;
	with Sync do begin
		eSyncs[Syncs] := Self;
		eThreads[Syncs] := eAvail;
		inc(Syncs);
	end;
	inherited Create(false);
end;

destructor TSyncThread.Destroy;
begin
	CloseHandle(eAvail);
	CloseHandle(eReady);
	inherited;
end;

procedure TSyncThread.Execute;
begin
	repeat
		ResetEvent(eReady);
		SetEvent(eAvail);
		while WaitForSingleObject(eReady, 100) <> WAIT_OBJECT_0 do
			if Terminated then exit;

		DoSync;
	until Terminated;
end;

procedure TSyncThread.SetSync(M: Integer);
begin
	fSync := M;
	SetEvent(eReady);
end;

function TSyncThread._UpdChapter(Data: TList; Chapt: TChapter; R: TReader): Boolean;
var
	lnk, ttl: AnsiString;
	i, j: Integer;
	c: TChapter;
	s: TConfigNode;
	o: AnsiString;
	procedure UploadPages;
	var
		p, m: Integer;
		l   : TList;
		e   : TString;
		h, u: AnsiString;
	begin
		ll_write('Downloading chapt #%d of manga "%s":', [i, ttl]);
		p := s.Int['pages'];
		m := s.Int['mirror'];
		l := TList(s.Find('data'));
		e := TString(l.Childs);
		while e <> nil do begin
			Loader.TaskToLoadPath(
				Loader.Schedule(MDToID(
					Manga,
					Chapt.Int['id'],
					STI(e.Name)),
					Format('%d', [m]),
					e.Value
				)
			, h, u);
			ll_write('  http://%s%s (mirror #%d) ...', [h, u, m]);
			e := TString(e.Next);
		end;
		c.Int['pages']  := p;
		c['cached'] := 'true';
	end;
begin
	c := TChapter(Data.Get(Chapt.Name));
	if c = nil then begin
		c := TChapter.Create(Chapt.Name);
		Data.InsertChild(c);
		c['id']     := Chapt['id'];
		c['title']  := Chapt.Name;
		c['trans']  := Chapt['trans'];
		c['pages']  := '0';
		c['cached'] := 'false';
	end;
	result := true;
	if not c.Bool['cached'] then
		try
			s := TConfigNode.Create('');
			try
				ll_Write('Updating chap "%s" (%d) of "%s"...', [Chapt.Name, Chapt.Int['id'], ttl]);
				j := R.RetriveInfo(mi_chapter, s, lnk + '/' + Chapt.Name);
				o := '';
				case j of
					-1: o := 'request to source server "' + R.Server + '" failed';
					-2: o := 'parsing source server "' + R.Server + '" response failed';
					-3: o := 'exception while assigning response data';
					-4: o := 'specified manga (' + ttl + ') not found';
					 0: UploadPages;
				end;
				if o <> '' then
					ll_Write('Error: Can''t update chapter #%d of "%s", %s', [c.Int['id'], ttl, o])
				else
					ll_Write('Now chapter #%d of "%s" is up to date', [c.Int['id'], ttl]);
			finally
				s.Free;
			end;
		except
			result := false;
		end;
end;

procedure TSyncThread.DoSync;
var
	ttl, lnk: AnsiString;
	s: TConfigNode;
	e: TReader;
	src, upd: Integer;
	o: AnsiString;
	v: Boolean;
	f: TDBFetch;
	procedure UpdateChapters;
	var
		c: TChapter;
		d: TList;
	begin
//		d := TList(TChapters(Manga.Find('chaps')));
		if TChapters(d).Int['count'] > 0 then begin
			ll_Write('Chapters is up to date...');
			exit
		end;
		d := TList(d.Find('data'));
		c := TChapter(s.Find('chaps').Childs);
		while c <> nil do begin
			if not _UpdChapter(d, c, e) then break;
			c := TChapter(c.Next);
		end;
		if c <> nil then
			ll_Write('Failed update...');
	end;
	procedure UpdateInfo;
	var
		c: TChapter;
	begin
//		Manga.Name := Manga['id'];
//		Manga['uptodate'] := '1';
//		Manga['title']    := s['title'];
//		Manga['desc']     := s['desc'];
//		s.List['alts'].AssignTo(TList(Manga.Find('alts')));
//		s.List['jenres'].AssignTo(TList(Manga.Find('jenr')));
		c := TChapter(s.List['chaps'].Childs);
		o := '';
		case E.RetriveInfo(mi_chapters, s, lnk + '/' + c.Name) of
			-1: begin o := 'request to source server "' + e.Server + '" failed'; {goto e2}; end; // req error
			-2: begin o := 'parsing source server "' + e.Server + '" response failed'; {goto e2}; end; // parsing error
			-3: begin o := 'exception while assigning response data'; {goto e2}; end; // assignment exception
			-4: begin o := 'specified manga (' + ttl + ') not found'; {goto e2}; end; // assignment exception
			 0: UpdateChapters;
		end;
		if o <> '' then
			ll_Write('Error: Can''t update [%s(#%d)], %s', [ttl, Manga, o])
		else
			ll_Write('Now "%s" is up to date', [ttl]);
	end;
label
	e1, e2, ext;
begin
	if f.Fetch('select from `%s` m, `%s` l, `%s` t where (m.id = %d) and (l.manga = %d) and (t.manga = %d) limit 1', [
			TBL_NAMES[TBL_MANGA],
			TBL_NAMES[TBL_LINKS],
			TBL_NAMES[TBL_TITLES],
			Manga, Manga, Manga
		], ['m.src', 'm.update', 'l.link', 't.title']) = 1 then begin
		src := f.Int[0];
		upd := f.Int[1];
		lnk := f.Str[2];
		ttl := f.Str[3];
	end else begin
		ll_Write('Request to update [manga:#%d] faied: no manga with such ID...', [Manga]);
		fSync := 0;
		exit;
	end;
	ll_Write('Updating [%s(#%d)]...', [ttl, Manga]);
	e := Readers.Find(src);
	if e = nil then begin
		ll_Write('Error: Can''t update [%s(#%d)], unknown source id #%d', [ttl, Manga, src]);
		fSync := 0;
		exit;
	end;

	v := true;
	s := TConfigNode.Create('');
	try
		o := '';
		case E.RetriveInfo(mi_manga, s, lnk) of
			 0: UpdateInfo;
			-1: o := 'request to source server "' + e.Server + '" failed'; // req error
			-2: o := 'parsing source server "' + e.Server + '" response failed'; // parsing error
			-3: o := 'exception while assigning response data'; // assignment exception
			-4: begin
				v := false;
				o := 'specified manga (' + ttl + ') not found';
			end;
		end;
		if o <> '' then ll_Write('Error: Can''t update [%s(#%d)], %s', [ttl, Manga, o]);
	finally
		s.Free;
		if (not v) and (upd = 0) then begin
			SQLCommand(SQL_DELETEID, [TBL_NAMES[TBL_MANGA], Manga]);
			SQLCommand(SQL_DELETEMANGA, [TBL_NAMES[TBL_LINKS], Manga]);
			SQLCommand(SQL_DELETEMANGA, [TBL_NAMES[TBL_TITLES], Manga]);
		end;
		fSync := 0;
	end;
end;

end.
