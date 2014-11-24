unit s_loaders;
interface
uses
		threads
	, functions
	, streams
	, s_engine
	, s_httpproxy
	, s_syncthreads
	;

const
	MAX_LOADERS = 28;

type
	PTask       =^TTask;
	TTask       = record
		Next      : PTask;
		Index     : Cardinal;
		Host      : AnsiString;
		URI       : AnsiString;
	end;
	TLoader     = class;
	TLdrThread  = class(TWorker)
	private
		fStarted  : Cardinal;
		lastrep   : Cardinal;
		LastPos   : Cardinal;
		Stream    : TStream;
		R         : THTTPImageDldr;
		function    DldCallback(Downloader: THTTPImageDldr): Boolean;
	public
		constructor Create; override;
		destructor  Destroy; override;
		procedure   Serve; override;
		function    Task: PTask; inline;

		property    Downloader: THTTPImageDldr read R;
		property    Started: Cardinal read fStarted;
	end;
	TLoader     = class(TSyncThread)
	protected
		function    Worker: TWClass; override;
		procedure   SortQueue; override;
	public
		function    SaveSchedule: Boolean;
		function    LoadSchedule: Boolean;
		procedure   Start; override;
		procedure   Stop; override;
		function    TaskToSavePath(T: PTask): AnsiString;
		function    TaskToLoadPath(T: PTask; out Host, URI: AnsiString): Boolean;
		function    Schedule(ID: Cardinal; H, U: AnsiString): PTask; overload;
	end;

var
	Loader: TLoader = nil;

const
	ID_PAGESPERCHAP  = 150;
	ID_CHAPSPERMANGA = 2000;
	ID_PAGESPERMANGA = ID_PAGESPERCHAP * ID_CHAPSPERMANGA;

function MDToID(M, C, I: Integer): Cardinal;
procedure IDToMD(ID: Cardinal; out M, C, I: Integer);

implementation
uses
		WinAPI
	, logs
	, file_sys
	, strings
	, parsers
	, s_config
	, s_serverreader
	, sql_constants
	;

function MDToID(M, C, I: Integer): Cardinal;
begin
	result := I + C * ID_PAGESPERCHAP + M * ID_PAGESPERMANGA;
end;

procedure IDToMD(ID: Cardinal; out M, C, I: Integer);
begin
	M  := ID div ID_PAGESPERMANGA;
	ID := ID mod ID_PAGESPERMANGA;
	C  := ID div ID_PAGESPERCHAP;
	I  := ID mod ID_PAGESPERCHAP;
end;

{ TLoader }

procedure AssumeDirExists(P: AnsiString);
var
	d: TStrings;
	i, l: Integer;
	s: AnsiString;
begin
	try
		P := ExpandFileName(ExtractFileDir(P));
		d := Explode('\', P);
		i := 0;
		l := Length(d);
		s := '';
		while i < l do begin
			if d[i] <> '' then begin
				if s <> '' then s := s + '\';
				s := s + d[i];
				if not FileExists(s) then
					MkDir(s);
			end;
			inc(i);
		end;
	except

	end;
end;

type
	PTA =^TTA;
	TTA = array [0..0] of PTask;

const
	INSERTION_SORT_THRESHOLD = 32;

procedure QSort(a: PTA; left, right: Integer; leftmost: Boolean);
var
	l, i, j, s: Integer;
	e1, e2, e3, e4, e5: Integer;
	le, gt, k: Integer;
	p1, p2: PTask;
	t   : PTask;               // a^
label
	out1, out2;
begin
//	l_Write('%d, %d, %b', [left, right, leftmost]);
	l := right - left + 1;

	// Use insertion sort on tiny arrays
	if (l < INSERTION_SORT_THRESHOLD) then begin
		if not leftmost then
			for i := left + 1 to right do begin
				t := a[i];
				j := i - 1;
				while t.Index < a[j].Index do begin
					a[j + 1] := a[j];
					dec(j);
				end;
				a[j + 1] := t;
			end
		else begin
			i := left;
			j := i;
			while i < right do begin
				t := a[i + 1];
				while t.Index < a[j].Index do begin
					a[j + 1] := a[j];
					if j = left then break;
					dec(j);
				end;
				a[j + 1] := t;
				inc(i);
				j := i;
			end
		end;
		exit;
	end;

	s := (l shr 3) + (l shr 6) + 1;
	e3 := (left + right) shr 1;
	e2 := e3 - s;
	e1 := e2 - s;
	e4 := e3 + s;
	e5 := e4 + s;

	if a[e2].Index < a[e1].Index then begin
		t := a[e2]; a[e2] := a[e1]; a[e1] := t;
	end;
	if a[e3].Index < a[e2].Index then begin
		t := a[e3]; a[e3] := a[e2]; a[e2] := t;
		if t.Index < a[e1].Index then begin
			a[e2] := a[e1]; a[e1] := t;
		end;
	end;
	if a[e4].Index < a[e3].Index then begin
		t := a[e4]; a[e4] := a[e3]; a[e3] := t;
		if t.Index < a[e2].Index then begin
			a[e3] := a[e2]; a[e2] := t;
			if t.Index < a[e1].Index then begin
				a[e2] := a[e1]; a[e1] := t;
			end;
		end;
	end;
	if a[e5].Index < a[e4].Index then begin
		t := a[e5]; a[e5] := a[e4]; a[e4] := t;
		if t.Index < a[e3].Index then begin
			a[e4] := a[e3]; a[e3] := t;
			if t.Index < a[e2].Index then begin
				a[e3] := a[e2]; a[e2] := t;
				if t.Index < a[e1].Index then begin
					a[e2] := a[e1]; a[e1] := t;
				end;
			end;
		end;
	end;

	p1 := a[e2];
	p2 := a[e4];

	le := left;
	gt := right;

	if p1.Index <> p2.Index then begin
		a[e2] := a[left];
		a[e4] := a[right];
		inc(le);
		dec(gt);
		while a[le].Index < p1.Index do inc(le);
		while a[gt].Index > p2.Index do dec(gt);

	out1:
		k := le;
		while k <= gt do begin
			t := a[k];
			if t.Index < p1.Index then begin
				a[k]  := a[le];
				a[le] := t;
				inc(le);
			end else if (t.Index > p2.Index) then begin
				while a[gt].Index > p2.Index do begin
					dec(gt);
					if gt = k then goto out1;
				end;
				if a[gt].Index < p1.Index then begin
					a[k] := a[le];
					a[le] := a[gt];
					inc(le);
				end else
					a[k] := a[gt];

				a[gt] := t;
				dec(gt);
			end;
			inc(k);
		end;
		a[left] := a[le - 1]; a[le - 1] := p1;
		a[right]:= a[gt + 1]; a[gt + 1] := p2;
		QSort(a, left, le - 2, leftmost);
		QSort(a, gt + 2, right, false);

		if (le < e1) and (e5 < gt) then begin
			while a[le].Index = p1.Index do inc(le);
			while a[gt].Index = p2.Index do dec(gt);


		out2:
			k := le;
			while k <= gt do begin
				t := a[k];
				if t.Index < p1.Index then begin
					a[k]  := a[le];
					a[le] := t;
					inc(le);
				end else if (t.Index = p2.Index) then begin
					while a[gt].Index = p2.Index do begin
						dec(gt);
						if gt = k then goto out2;
					end;
					if a[gt].Index = p1.Index then begin
						a[k] := a[le];
						a[le] := a[gt];
						inc(le);
					end else
						a[k] := a[gt];

					a[gt] := t;
					dec(gt);
				end;
				inc(k);
			end;
		end;
		QSort(a, le, gt, false);
	end else begin
		for k := left to gt do begin
			if a[k].Index = p1.Index then continue;

			t := a[k];
			if t.Index < p1.Index then begin
				a[k]  := a[le];
				a[le] := t;
				inc(le);
			end else begin
				while a[gt].Index > p1.Index do
					dec(gt);

				if a[gt].Index < p1.Index then begin
					a[k] := a[le];
					a[le] := a[gt];
					inc(le);
				end else
					a[k] := a[gt];

				a[gt] := t;
				dec(gt);
			end;
		end;
		QSort(a, left, le - 1, leftmost);
		QSort(a, gt + 1, right, false);
	end;
end;

function TLoader.LoadSchedule: Boolean;
var
	c: TConfigNode;
	S: TStream;
	T: TTokenizer;
	b: PByte;
	procedure ReadSchedule;
	var
		t, n: TConfigNode;
	begin
		n := TConfigNode(c.Childs);
		while n <> nil do begin
			Schedule(n.int['id'], n.Str['host'], n.Str['uri']);
			t := n;
			n := TConfigNode(n.Next);
			t.Free;
		end;
	end;
begin
//	l_Write('Loading schedule...');
	try
		c := TConfigNode.Create('schedule');
		try
			S := TFileStream.Create(CoreDir + 'data\schedule.txt', fmOpen);
			try
				b := GetMemory(S.Size + 1);
				try
					S.Read(b, S.Size);
					PByte(Cardinal(b) + S.Size)^ := 0;
					T := TTokenizer.Create;
					try
						T.Init(PAnsiChar(b));
						c.ReadFromParser(T);
					finally
						T.Free;
					end;
				finally
					FreeMemory(b);
				end;
			finally
				S.Free;
			end;
			ReadSchedule;
			result := true;
//			l_Write('  loaded...');
		finally
			c.Free;
		end;
	except
		result := false;
//		l_Write('  error loading schedule!');
	end;
end;

function TLoader.SaveSchedule: Boolean;
var
	S, E: TStream;
	A: AnsiString;
	c: TConfigNode;
	procedure ReadSchedule;
	var
		t: PTask;
		n: TConfigNode;
		i: Integer;
	begin
		i := 0;
//		SortQueue;
		if not WaitScheduler then exit;
		t := Queue;
		while t <> nil do begin
			inc(i);
			n := TConfigNode.Create(ITS(i));
			n.AddParam(TString, 'id');
//			n.AddParam(TString, 'chap');
//			n.AddParam(TString, 'src');
			n.AddParam(TString, 'host');
			n.AddParam(TString, 'uri');

			n.Int['id']   := t.Index; //MDToID(t.ID, t.Chapter, t.Manga);
//			n.Int['chap'] := t.Chapter;
//			n.Int['src']  := t.Src;
			n.Str['host'] := t.Host;
			n.Str['uri']  := t.URI;
			c.InsertChild(n);
			t := t.Next;
		end;
		ScheduleReady;
	end;
begin
//	l_Write('Saving schedule backup...');
	// backup
	A := Format('%sdata\\schedules\\%s.txt', [CoreDir, MSecToStr2]);
	AssumeDirExists(A);
	try
		S := TFileStream.Create(A, fmCreate);
		try
			E := TFileStream.Create(CoreDir + 'data\schedule.txt', fmOpen);
			try
				SetLength(A, E.Size);
				E.Read(@A[1], E.Size);
			finally
				E.Free;
			end;
			S.Write(@A[1], Length(A));
		finally
			S.Free;
		end;
	except

	end;

//	l_Write('Saving schedule...');
	try
		C := TConfigNode.Create('schedule');
		try
			ReadSchedule;
			A := c.ToString;
			S := TFileStream.Create(CoreDir + 'data\schedule.txt', fmCreate);
			try
				S.Write(@A[1], Length(A));
			finally
				S.Free;
			end;
			result := true;
//			l_Write('  saved...');
		finally
			C.Free;
		end;
	except
//		l_Write('  error saving schedule...');
		result := false;
	end;
end;

function TLoader.Schedule(ID: Cardinal; H, U: AnsiString): PTask;
begin
	New(result);
	result.Index := ID;
	result.Host  := H;
	result.URI   := U;
	Schedule(result);
end;

procedure TLoader.SortQueue;
var
	a: PTA; // 65k  a^
	i, s: Integer;
	t: PTask;
begin
	s := $1F;
	a := GetMemory(s * 4 + 16);
	try
		i := 0;
		t := fQueue;
		while t <> nil do begin
			if i > s then begin
				s := (i div $1F + 2) * $1F;
				a := ReallocMemory(a, s * 4);
			end;
			a[i] := t;
			inc(i);
			t := t.Next;
		end;
		if i <= 1 then exit;
		try
			QSort(a, 0, i - 1, true);
		except
		end;
		t := nil;
		while i > 0 do begin
			dec(i);
			a[i].Next := t;
			t := a[i];
		end;
		fQueue := t;
	finally
		FreeMemory(a);
		NeedSort := false;
	end;
end;

procedure TLoader.Start;
begin
	inherited;
	LoadSchedule;
end;

procedure TLoader.Stop;
begin
	inherited;
	SaveSchedule;
end;

function TLoader.TaskToLoadPath(T: PTask; out Host, URI: AnsiString): Boolean;
var
	_m, _c, _i, s: Integer;
	l: AnsiString;
	m: TManga;
	c: TChapter;
	r: TReader;
	f: TDBFetch;
begin
	result := false;
	IDToMD(T.Index, _m, _c, _i);
	if f.Fetch('select from `%s` m, `%s` l where (m.id = %d) and (l.manga = %d) limit 1', [
		TBL_NAMES[TBL_MANGA],
		TBL_NAMES[TBL_LINKS],
		_m, _m
	], ['m.src', 'l.link']) = 1 then begin
		s := f.Int[0];
		l := f.Str[0];
	end else
		exit;

	r := TReader(Readers.Find(s));
	if r =nil then exit;

	if f.Fetch(SQL_FETCHMANGA + ' and (t.id = %d) limit 1', [TBL_NAMES[TBL_CHAPT], _m, _c], ['t.name']) <> 1 then
		exit;

	Host := r.MakeHost(T.Host);
	URI  := '/' + l + '/' + f.Str[0] + '/' + T.URI;
end;

function TLoader.TaskToSavePath(T: PTask): AnsiString;
var
	m, c, i: Integer;
begin
	IDToMD(T.Index, m, c, i);
	result := Format('data\\%d0.6\\%d0.4\\%d0.4\.%s', [
		m, c, i, ExtractFileExt(T.URI)
	]);
end;

function TLoader.Worker: TWClass;
begin
	result := TLdrThread;
end;

{ TLdrThread }

constructor TLdrThread.Create;
begin
	inherited Create;
	R := THTTPImageDldr.Create;
end;

destructor TLdrThread.Destroy;
begin
	R.Free;
	inherited;
end;

function TLdrThread.DldCallback(Downloader: THTTPImageDldr): Boolean;
var
	t: Cardinal;
	m, c, p: Integer;
begin
	result := Running;
	with Downloader do
		if (GetTickCount - lastrep > 5000) or
			((not result) and ((ReqDld - DataOffset) - LastPos > 0)) then begin
			lastrep := GetTickCount;
//			t := (lastrep - Downloader.ReqStart);

			IDToMD(PTask(Task).Index, m, c, p);
			t := R.DataDownloaded - LastPos;
			if t > 0 then begin
				Stream.Write(PByte(Cardinal(Data) + LastPos), t);
				LastPos := R.DataDownloaded;
			end;
		end;
end;

procedure TLdrThread.Serve;
var
	Path: AnsiString;
	H, U: AnsiString;
	fi  : TImageInfo;
	E   : Integer;
	function DLDFrom: Integer;
	var
		F   : File of Byte;
	begin
		if FileExists(Path) then begin
			Assign(F, Path);
			{$I-}
			Reset(F);
			if IOResult = 0 then begin
				result := FileSize(F);
				Close(F);
			end else
				result := -1;
			{$I+}
		end else
			result := -1;
	end;
label
	done;
begin
	try
		fStarted := GetTickCount;
		if not Loader.TaskToLoadPath(Task, H, U) then
//			l_Write('  Image data not available...')
		else
//		l_Write('Downloading "%s"...', [U]);
		if not R.GetInfo(nil, H, U, fi) then
//			l_Write('  Image not available...')
		else begin
			Path := Loader.TaskToSavePath(Task);
			AssumeDirExists(Path);
			E := DLDFrom;
			if e < 0 then
				e := 0
			else
				if e >= fi.FileSize then begin
//					l_Write('Already up to date...');
					goto done;
				end;

			try
				Stream := TFileStream.Create(path, fmOpenAlways);
				Stream.Position := e;
				try
					lastrep := GetTickCount;
					LastPos := 0;
					if R.Download(DldCallback, H, U, e, 1000) then begin
						e := Stream.Write(PByte(Cardinal(R.Data) + LastPos), R.DataDownloaded - LastPos);
						inc(LastPos, e);
//						l_Write('Downloaded "%s" -> "%s"...', [U, path]);
					end;
				finally
					Stream.Free;
				end;
			except
//				l_Write('Internal exception while performing download task!');
			end;

			done:
		end;
	except
		on E: Exception do;
//			l_write('Exception in TLdrThread.ProcessTask: ' + E.Message);
		on E: TObject do
//			l_write('Exception in TLdrThread.ProcessTask');
	end;
	R.ResetStats;
end;

function TLdrThread.Task: PTask;
begin
	result := PTask(fTask);
end;

end.
