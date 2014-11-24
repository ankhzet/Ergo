unit form_main;

interface

uses
	Windows, Messages, Graphics, Controls, Forms, StdCtrls, Classes, ExtCtrls, ComCtrls, Spin,
	Dialogs,
	s_config
	, parsers
	, s_httpproxy
	, strings;

type
	TMainViewer = class(TForm)
    lLog: TListBox;
    Splitter1: TSplitter;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Label1: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit4: TEdit;
    mSrvResp: TMemo;
    RadioGroup2: TRadioGroup;
    RadioGroup1: TRadioGroup;
    Memo1: TMemo;
    PageControl2: TPageControl;
    tsMangaList: TTabSheet;
    lbSrvCachedManga: TListBox;
    tsMangaSearch: TTabSheet;
    lbSearchList: TListBox;
    eListFilter: TEdit;
    lbFilterList: TListBox;
    seMatcing: TSpinEdit;
    tsMangaDescr: TTabSheet;
    Image1: TImage;
    lMangaTitle: TLabel;
    lMangaAlts: TLabel;
    lMangaJenres: TLabel;
    mMangaDesc: TMemo;
    Button6: TButton;
    Button7: TButton;
    lMangaStatus: TLabel;
    TabSheet3: TTabSheet;
    mESQL: TMemo;
    Button1: TButton;
    Panel1: TPanel;
    procedure tsMangaSearchShow(Sender: TObject);
    procedure lbSrvCachedMangaDblClick(Sender: TObject);
    procedure eListFilterChange(Sender: TObject);
    procedure lbFilterListDblClick(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure tsMangaListShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure eListFilterKeyPress(Sender: TObject; var Key: Char);
	private
		fManga: Integer;
		function InitTbl(T: Cardinal): Boolean;
		function Request(M: AnsiString; c: TConfigNode): Boolean;
		procedure setManga(const Value: Integer);
	public
		r   : TClientRequest;
		res : TConfigNode;
		red : TReader;

		procedure LoadMangaList(Node: TObject);
		procedure LoadSearchList(Node: TObject);
		procedure UpdateMangaDef(Node: TObject);

		procedure ShowMangaDef;

		procedure Log(Msg: AnsiString; Params: array of const); overload;
		function  Log(Msg: AnsiString): Boolean; overload;
		property  Manga: Integer read fManga write setManga;
	end;

var
	MainViewer: TMainViewer;

implementation
uses
		functions
	, logs
	, s_engine
	, sql_constants
	, mt_engine
	, mt_waiter
	, fyzzycomp

	;

{$R *.dfm}

procedure TMainViewer.Button1Click(Sender: TObject);
begin
	SQLCommand(trim(mESQL.Text));
end;

procedure TMainViewer.Button6Click(Sender: TObject);
var
	l: AnsiString;
	f: TDBFetch;
begin
	if f.Fetch('select from `%s` m, `%s` l where (m.id = %d) and (l.manga = m.id) limit 1',
		['manga', 'links', Manga],
		['m.src', 'l.link']
	) = 1 then begin
		Request('{a=load;d{link="' + f[1] + '";src=' + f[0] + ';all=true;};};', res);
	end else
		log('-- wtf? oO Can''t resolve manga SRC and LINK');
end;

procedure TMainViewer.eListFilterChange(Sender: TObject);
var
	i, j, k: Integer;
	l: TItemList;
	t: AnsiString;
	r: TStats;
begin
	t := eListFilter.Text;
	if Length(t) < 2 then begin
		lbSearchList.Visible := true;
		lbFilterList.Visible := false;
		exit;
	end;
	lbSearchList.Visible := false;
	lbFilterList.Visible := true;
	l := TItemList.Create;
	with lbSearchList do
		for j := 0 to Items.Count - 1 do
			l.Add(Items[j]);
	j := l.Add(t);
	try
		i := FyzzyAnalyze(l, j, seMatcing.Value, r);
		lbFilterList.Clear;
		t := '';
		k := l.Count;
		while k > 0 do begin
			dec(k);
			if k = j then continue;
			if R[k].R > 0 then begin
				lbFilterList.Items.AddObject(lbSearchList.Items[k], lbSearchList.Items.Objects[k]);
				if k = i then
					t := lbSearchList.Items[k];
			end;
		end;
		if lbFilterList.Count = 0 then begin
			lbSearchList.Visible := true;
			lbFilterList.Visible := false;
		end else
			lbFilterList.ItemIndex := lbFilterList.Items.IndexOf(t);
	finally
		l.Free;
	end;
end;

procedure TMainViewer.eListFilterKeyPress(Sender: TObject; var Key: Char);
begin
	if KEY <> #13 then exit;
	Request('{a=load;d{link="' + eListFilter.Text + '";src=' + ITS(1) + ';};};', res);
end;

procedure TMainViewer.FormCreate(Sender: TObject);
var
	i: Integer;
begin
	l_SetHandler(log);
	l_Start('logs');
	fManga := 0;
	tsMangaDescr.TabVisible := false;
	R := TClientRequest.Create;
	res := TConfigNode.Create('');
	for i := TBL_MANGA to TBL_MAX do
		if SQLFAIL(SQLCommand('status table `%s`', [TBL_NAMES[i]])) then InitTbl(i);

end;

procedure TMainViewer.FormDestroy(Sender: TObject);
begin
	l_SetHandler(nil);
end;

function TMainViewer.InitTbl(T: Cardinal): Boolean;
var
	n: AnsiString;
begin
	n := TBL_NAMES[T];
	SQLCommand('drop table `%s`;', [n]);
	SQLCommand('create table `%s`;', [n]);
	SQLCommand('alter table `%s` %s;', [n, TBL_SCHEMA[t]]);
end;

function TMainViewer.Log(Msg: AnsiString): Boolean;
begin
	lLog.Items.Add(Msg);
	lLog.ItemIndex := lLog.Count - 1;
end;

procedure TMainViewer.Log(Msg: AnsiString; Params: array of const);
begin
	Log(Format(Msg, Params));
end;

const
	REQ_OK       = $000000;
	REQ_LIST     = $000001;
	REQ_MANGA    = $000002;
	REQ_IMAGE    = $000003;
	REQ_SEARCH   = $000004;
	REQ_LOAD     = $000005;
	REQ_ERR      = $000006;

	REQ_MAX      = REQ_ERR;

	ERR_OK       = $000000;
	ERR_NOMANGA  = $000001;
	ERR_NOCHAPTER= $000002;
	ERR_NOIMAGE  = $000003;
	ERR_LOADING  = $000004;

	ERR_REQUEST  = $000020;
	ERR_SERVEREXC= $000021;

	MSG_OK       = $000001;

	REQ_STRINGS  : array [REQ_OK .. REQ_MAX] of PAnsiChar = (
		'ok',
		'list',
		'manga',
		'image',
		'search',
		'load',
		'err'
	);
	ERR_INDICES  : array [0 .. 6] of Cardinal = (
		ERR_OK,
		ERR_NOMANGA,
		ERR_NOCHAPTER,
		ERR_NOIMAGE,
		ERR_LOADING,
		ERR_REQUEST,
		ERR_SERVEREXC
	);

function ActionToCode(A: AnsiString): Cardinal;
begin
	result := REQ_MAX;
	while result > 0 do begin
		if lstrcmpia(@A[1], REQ_STRINGS[result]) = 0 then exit;
		dec(result);
	end;
end;

function ErrToIndex(Code: Cardinal): Cardinal;
begin
	result := 7;
	while result > 0 do begin
		if ERR_INDICES[result] = Code then exit;
		dec(result);
	end;
end;

function TMainViewer.Request(M: AnsiString; c: TConfigNode): Boolean;
var
	P: TTokenizer;
begin
	result := false;
	try
		if R.Request(STI(Edit2.Text), Edit1.Text, M, 1000) then begin
			Log('Req [%s] success...', [M]);
			mSrvResp.Text := PAnsiChar(R.Data);
			try
				P := TTokenizer.Create;
				try
					P.Init(PAnsiChar(RecodeHTMLTags(PAnsiChar(R.Data))));
					C.RemoveChilds;
					C.ReadFromParser(P);
				finally
					P.Free;
				end;
				Memo1.Text := C.ToString;

				RadioGroup1.ItemIndex := ActionToCode(C['a']);
				if RadioGroup1.ItemIndex = REQ_ERR then
					RadioGroup2.ItemIndex := ErrToIndex(c.Int['d'])
				else
					RadioGroup2.ItemIndex := 0;
				if c['m'] <> '' then Edit4.Text := c['m'];
				result := true;
			except
				on E: Exception do begin
					Log('Error parsing response: %s', [E.Message]);
				end;
				on E: TObject do begin
					Log('Unknown exception class %s while parsing response', [E.ClassName]);
				end;
			end;
		end else
			Log('Request fail...', []);
	except
		on E: Exception do Log('Request fail: %s', [E.Message]);
	end;
end;

procedure TMainViewer.setManga(const Value: Integer);
begin
	if fManga <> Value then begin
		fManga := Value;
		ShowMangaDef;
		tsMangaDescr.TabVisible := Value <> 0;
	end;
end;

procedure TMainViewer.ShowMangaDef;
var
	src, upd: Integer;
	ssrc, t : AnsiString;
	link    : AnsiString;
	i, j, k : Integer;
	ttls    : array of AnsiString;
	jenres  : array of record id: Integer; j, d: AnsiString; end;
	descr   : AnsiString;
	f       : TDBFetch;
begin
	src := 0;
	upd := 0;
	descr := '';
	ssrc  := 'server';
	link  := '';
	if f.Fetch(SQL_FETCHIDL, ['manga', Manga], ['t.src', 't.update']) = 1 then begin
		src := f.Int[0];
		upd := f.Int[1];
		if f.Fetch(SQL_FETCHMANGA, ['titles', Manga], ['t.title']) > 0 then begin
			j := f.Count;
			SetLength(ttls, j);
			i := 0;
			while i < j do begin
				ttls[i] := f.Rows[i, 0];
				inc(i);
			end;
		end;

		if f.Fetch('select from `%s` j, `%s` m where (m.manga = %d) and (m.jenre = j.id)', ['jenres', 'm_jenres', Manga], ['j.id', 'j.name', 'j.descr']) > 0 then begin
			j := f.Count;
			SetLength(jenres, j);
			i := 0;
			while i < j do begin
				jenres[i].id := STI(f.Rows[i, 0]);
				jenres[i].j  := f.Rows[i, 1];
				jenres[i].d  := f.Rows[i, 2];
				inc(i);
			end;
		end;

		if f.Fetch(SQL_FETCHMANGAL, ['descrs', Manga], ['t.content']) = 1 then descr := f[0];
		if f.Fetch(SQL_FETCHIDL   , ['sources', src], ['t.name']) = 1 then ssrc := f[0];
		if f.Fetch(SQL_FETCHMANGAL, ['links', Manga], ['t.link']) = 1 then link := f[0];
	end;
	j := Length(ttls);
	if j > 0 then begin
		lMangaTitle.Caption := ttls[0];
		i := 0;
		t := '';
		while i < j do begin
			t := strJoin(#13#10, [t, ttls[i]]);
			inc(i);
		end;
		lMangaAlts.Caption := t;
	end;
	j := Length(jenres);
	if j > 0 then begin
		i := 0;
		t := '';
		while i < j do begin
			with jenres[i] do
				t := strJoin(#13#10, [t, Format(' <a href="/jenres/%d">%s</a>', [id, j])]);
			inc(i);
		end;
		lMangaJenres.Caption := t;
	end;
	lMangaStatus.Caption := Format(' Last update was $%d.8 on [http://%s/%s]', [upd, ssrc, link]);
	mMangaDesc.Text := descr;
end;

function isCyrylic(S: AnsiString): Boolean;
var
	c: AnsiChar;
begin
	for c in s do
		if UpCase(c) in ['À'..'ß', '¨', 'ª', '¯', '²'] then
			exit(true);

	result := false;
end;

const news:array[boolean]of ansistring=('     ', ' NEW ');
procedure TMainViewer.LoadMangaList(Node: TObject);
var
	c, j, n, k: integer;
	s: array [word] of AnsiString;
	e: array [word] of word;
	d: array [word] of integer;
	u: array [word] of Boolean;
	i: TString;
	f: TDBFetch;
	b: Boolean;
	function has(id: integer): integer;
	begin
		result := n;
		while result > 0 do begin
			dec(result);
			if d[result] = id then exit;
		end;
		result := -1;
	end;
begin
	n := 0;
	if f.Fetch('select from `%s` m, `%s` t where t.manga = m.id;', [TBL_NAMES[TBL_MANGA], TBL_NAMES[TBL_TITLES]], ['m.id', 't.title']) > 0 then begin
		for c := 0 to f.Count - 1 do begin
			j := sti(f.Rows[c, 0]);
			k := has(j);
			if k < 0 then begin
				d[n] := j;
				s[n] := f.Rows[c, 1];
				u[n] := false;
				e[n] := n;
				inc(n);
			end else
				if (not isCyrylic(s[k])) and isCyrylic(f.Rows[c, 1]) then
					s[k] := f.Rows[c, 1];
		end;
	end;
	if Request('{a=list;}', res) then begin
		i := TString(res.List['d'].Childs);
		while i <> nil do begin
			j := STI(i.Name);
			if has(j) < 0 then begin
				d[n] := j;
				s[n] := i.Value;
				u[n] := true;
				e[n] := n;
				inc(n);
			end;
			i := TString(i.Next);
		end;
	end;

	repeat
		b := true;
		c := n;
		while c > 1 do begin
			dec(c);
			if d[e[c - 1]] < d[e[c]] then begin
				j := e[c];
				e[c] := e[c - 1];
				e[c - 1] := j;
				b := false;
			end;
		end;
	until b;

	lbSrvCachedManga.Clear;
	while n > 0 do begin
		dec(n);
		c := e[n];
		lbSrvCachedManga.Items.AddObject(Format('%s%s', [news[u[c]], DecodeHTMLTags(s[c])]), Pointer(d[c]));
	end;
end;

procedure TMainViewer.LoadSearchList(Node: TObject);
var
	i: Integer;
	l: TList;
	s: TString;
begin
	lbSearchList.Clear;
	if Request('{a=search;}', res) then begin
		l := TList(res.Find('dmangas').Childs);
		while l <> nil do begin
			i := STI(l.Name);
			s := TString(l.Childs);
			while s <> nil do begin
				lbSearchList.Items.AddObject(Format('%d3: "%s" at [%s]', [i, s.Value, s.Name]), TString.Create(s.Name));
				s := TString(s.Next);
			end;
			l := TList(TMTNode(l).Next);
		end;
	end;
	eListFilter.SetFocus;
end;

procedure TMainViewer.UpdateMangaDef(Node: TObject);
var
	i, id: Integer;
	link, s : AnsiString;
	m, t : TConfigNode;
	f    : TDBFetch;
begin
	i := lbSrvCachedManga.ItemIndex;
	if i < 0 then exit;
	id := Integer(lbSrvCachedManga.Items.Objects[i]);
	log('-- retriving #%d.3', [id, link]);

	i := 0;
	if Request('{a=updates;d=' + its(id) + ';}', res) then begin
		i := res.Int['d'];
		if f.Fetch('select from manga m where (m.id = %d) and (m.update = %d) limit 1;', [id, i], ['m.id']) = 0 then
			i := 0
		else
			log('-- up to date...', []);
	end;

	if i = 0 then
	if Request('{a=manga;d=' + its(id) + ';}', res) then begin
		m := TConfigNode(res.Find('d').Childs);

		SQLCommand(SQL_DELETEID   , ['manga', id]);
		SQLCommand(SQL_DELETEMANGA, ['links', id]);
		SQLCommand(SQL_DELETEMANGA, ['titles', id]);
		SQLCommand(SQL_DELETEMANGA, ['m_jenres', id]);
		SQLCommand(SQL_DELETEMANGA, ['descrs', id]);

		SQLCommand('insert into `%s` values (%d, %d, 1);', ['manga', id, m.Int['src']]);
		SQLCommand(SQL_INSERT_IS, ['links', id, m['link']]);

		t := TConfigNode(m.Find('alts').Childs);
		while t <> nil do begin
			if t.Name <> '#' then
				for s in Explode(#13#10, t.Name) do
					SQLCommand(SQL_INSERT_IS, ['titles', id, Trim(s)]);
			t := TConfigNode(t.Next);
		end;
		t := TConfigNode(m.Find('jenr').Childs);
		while t <> nil do begin
			if t.Name <> '#' then
				for s in Explode(#13#10, t.Name) do
					if f.Fetch('select from jenres j where j.name = "%s" limit 1;', [Trim(s)], ['j.id']) = 1 then
						SQLCommand(SQL_INSERT_II, ['m_jenres', id, f.Int[0]]);

			t := TConfigNode(t.Next);
		end;

		SQLCommand(SQL_INSERT_IS, ['descrs', id, m['desc']]);
	end;
	Manga := id;
end;

procedure TMainViewer.tsMangaListShow(Sender: TObject);
begin
	if (res <> nil) and (res.State = ns_normal) then
		TSafeExecute.Create(res, LoadMangaList, [
			lbSrvCachedManga.Handle
		]);

//	red.ActivePage := rp_home;
end;

procedure TMainViewer.tsMangaSearchShow(Sender: TObject);
begin
	if res.State = ns_normal then
		TSafeExecute.Create(res, LoadSearchList, [
			tsMangaSearch.Handle
		]);
end;

procedure TMainViewer.lbFilterListDblClick(Sender: TObject);
var
	L: TListBox;
	P: TTokenizer;
	i: Integer;
	c: TString;
begin
	l := TListBox(Sender);
	i := l.ItemIndex;
	if i < 0 then exit;
	c := TString(l.Items.Objects[i]);
	Request('{a=load;d{link="' + c.name + '";src=' + ITS(1) + ';};};', res);
end;

procedure TMainViewer.lbSrvCachedMangaDblClick(Sender: TObject);
begin
	if res.State = ns_normal then
		TSafeExecute.Create(res, UpdateMangaDef, [
			lbSrvCachedManga.Handle
		]);
	tsMangaDescr.Show;
end;

end.
