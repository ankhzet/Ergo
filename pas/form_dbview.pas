unit form_dbview;

interface

uses
	sql_database, sql_constants
	, sql_dbsqladapter
	, sql_dbcommon,
	Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
	Dialogs, StdCtrls, ExtCtrls, ComCtrls, ActnList, Spin, Grids, ValEdit, jpeg;

type
	TDBViewer = class(TForm)
		ListBox1: TListBox;
		Panel1: TPanel;
    Button8: TButton;
		Button4: TButton;
    e1: TEdit;
    Edit4: TEdit;
		Button9: TButton;
    cbTables: TComboBox;
    lLog: TListBox;
    Splitter1: TSplitter;
    Button1: TButton;
    Button2: TButton;
    e2: TEdit;
		e3: TEdit;
    e4: TEdit;
    e5: TEdit;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    cbMangasID: TComboBox;
		Label1: TLabel;
    Label2: TLabel;
    mTitles: TMemo;
    Label3: TLabel;
    cbJenres: TListBox;
    mDescr: TMemo;
    Label4: TLabel;
		Button3: TButton;
    Update: TButton;
    Label5: TLabel;
    eShortcut: TEdit;
    bAssignShortcut: TButton;
    bOptimize: TButton;
    TabSheet3: TTabSheet;
		Panel2: TPanel;
    bSearchRelated: TButton;
    Button6: TButton;
    eMangaTitle: TEdit;
    Label6: TLabel;
    alActions: TActionList;
    Label7: TLabel;
		aAddSel: TAction;
    lvFixMangas: TListView;
    Button7: TButton;
    eMID: TEdit;
    Button10: TButton;
    aMIDPrev: TAction;
    aMIDNext: TAction;
		Label8: TLabel;
    eMShortcut: TEdit;
    pFixpreview: TPanel;
    pFixFirstPage: TPanel;
		procedure FormCreate(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
		procedure Button9Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure e1Click(Sender: TObject);
    procedure TabSheet1Show(Sender: TObject);
    procedure cbMangasIDChange(Sender: TObject);
		procedure UpdateClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure bAssignShortcutClick(Sender: TObject);
    procedure bOptimizeClick(Sender: TObject);
    procedure aAddSelUpdate(Sender: TObject);
    procedure bSearchRelatedClick(Sender: TObject);
		procedure lvFixMangasChange(Sender: TObject; Item: TListItem;
      Change: TItemChange);
		procedure eMIDChange(Sender: TObject);
    procedure aMIDPrevUpdate(Sender: TObject);
    procedure aMIDPrevExecute(Sender: TObject);
    procedure Button10Click(Sender: TObject);
		procedure TabSheet3Show(Sender: TObject);
    procedure aAddSelExecute(Sender: TObject);
	private
		function SQL(R: AnsiString): Cardinal; overload;
		function SQL(R: AnsiString; P: array of const): Cardinal; overload;
		procedure Log(Msg: AnsiString; Params: array of const);
		function loghdl(Msg: PChar): Boolean;
		procedure ShowResult;
		{ Private declarations }
	public
		tbl : PDBTable;
		DBChanged: Boolean;
		fmanga, fjenres, ftitles, f_mjenres: EDBFetch;
		iFixPreview: TPicture;
		iFixFirstPage: TPicture;
		procedure EnumDB;
		procedure ShowTbl;

		procedure modifPreview;
		procedure modifFirstPage;

		procedure AquireMangaData;
	end;

var
  DBViewer: TDBViewer;

implementation
uses
		strings
	, functions
	, file_sys
//	, logs
	, sql_interpreter
	, sql_Exceptions
	, s_config
	, opts
	, emu_types
	;

{$R *.dfm}

type
	TArr= array [Byte] of AnsiString;

function has(a: TArr; c: Integer; S: AnsiString): Integer;
begin
	result := c;
	while result > 0 do begin
		dec(result);
		if lstrcmpi(@a[result, 1], @s[1]) = 0 then exit;
	end;
	dec(result);
end;

function add(var a: TArr; var c: Integer; S: AnsiString): Integer;
begin
	result := c;
	a[result] := S;
	inc(c);
end;

procedure TDBViewer.Button3Click(Sender: TObject);
begin
	log(' -- save db: %b', [_db_save]);
	while DB.Tables <> nil do _table_free(DB.Tables);
	AquireMangaData;
end;

procedure TDBViewer.aAddSelExecute(Sender: TObject);
var
	m{, i, j, k, l}: Integer;
//	s1, s2: AnsiString;
//	t: TArr;
//	c: Integer;
//	s: TStrings;
begin
	m := STI(eMID.Text);
	if m <= 0 then exit;
	DBChanged := true;
	SQLCommand('delete from manga m where m.id = %d', [m]);
	SQLCommand('delete from titles t where t.manga = %d', [m]);
	SQLCommand('delete from m_jenres j where j.manga = %d', [m]);
	SQLCommand('delete from descrs d where d.manga = %d', [m]);
	SQLCommand('delete from links l where l.manga = %d', [m]);
	SQLCommand('delete from links l where l.link = ''%s''', [RecodeHTMLTags(eMShortcut.Text)]);

	SQLCommand(SQL_DELETEMANGA, [TBL_NAMES[TBL_MHIST], m]);
	SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_MHIST], m, UTCSecconds]);

	SQLCommand(SQL_INSERT_III, ['manga', m, 1, 1]);
	SQLCommand('insert into titles values (%d, ''%s'')', [m, RecodeHTMLTags(eMangaTitle.Text)]);

	SQLCommand('insert into descrs values (%d, '''')', [m]);
	SQLCommand('insert into links values (%d, ''%s'')', [m, RecodeHTMLTags(eMShortcut.Text)]);

//	bSearchRelatedClick(Sender);
end;

procedure TDBViewer.aAddSelUpdate(Sender: TObject);
begin
	(Sender as TAction).Enabled := lvFixMangas.Selected <> nil;
end;

procedure TDBViewer.aMIDPrevUpdate(Sender: TObject);
begin
	(Sender as TAction).Enabled := STI(eMID.Text) > 0;
end;

procedure TDBViewer.AquireMangaData;
var
	mc, ms: Integer;
	i, j, k, l, dl: Integer;
	s1, s2: AnsiString;
	t: TArr;
	tc: Integer;
begin
	log(' -- load db: %b', [_db_load]);
	mTitles.Clear;
	cbJenres.Clear;
	ms := STI(cbMangasID.Text);
	cbMangasID.Clear;
	cbMangasID.Text := '0';
	Fetch3(@ftitles, 'select from titles t', [], ['t.manga', 't.title']);
//	ftitles.Fetch2('select from titles t', ['t.manga', 't.title']);
	mc := Fetch3(@fmanga, 'select from manga m, descrs d where (m.id = d.manga)', [], ['m.id', 'd.content']);
	dl := 0;
	for i := 0 to mc - 1 do begin
		k := sti(fmanga.Rows[i, 0]);
		if Length(fmanga.Rows[i, 1]) > dl then dl := Length(fmanga.Rows[i, 1]);
		tc := 0;
		for j := 0 to ftitles.Count - 1 do begin
			s1 := ftitles.Rows[j, 1];
			if STI(ftitles.Rows[j, 0]) = k then
				if has(t, tc, s1) < 0 then begin
					l := Add(t, tc, s1);
					if isCyrylic(s1) and (l > 0) then begin
						s2   := t[0];
						t[0] := t[l];
						t[l] := s2;
					end;
				end;
		end;
		cbMangasID.Items.AddObject(its(k, 0, 3) + ': ' + t[0], TObject(k));
	end;
	cbMangasID.ItemIndex := 0;
	Fetch3(@fjenres, 'select from jenres j', [], ['j.id', 'j.name']);
	tc := 0;
	for j := 0 to fjenres.count - 1 do begin
		s1 := fjenres.Rows[j, 1];
		{k := }STI(fjenres.Rows[j, 0]);
		if has(t, tc, s1) < 0 then
			{l := }Add(t, tc, s1);
	end;
	cbJenres.Items.Text := join(#13#10, t);
	Fetch3(@f_mjenres, 'select from m_jenres m, jenres j where m.jenre = j.id', [], ['m.manga', 'm.jenre', 'j.name']);
	if ms <> 0 then
		cbMangasID.ItemIndex := cbMangasID.Items.IndexOfObject(TObject(ms));
	cbMangasIDChange(nil);
	Log('-- max description length: %d', [dl]);
end;

procedure TDBViewer.cbMangasIDChange(Sender: TObject);
var
	m: Integer;
	i, j, k, l: Integer;
	s1, s2: AnsiString;
	t: TArr;
	c: Integer;
	f: EDBFetch;
	ll: Boolean;
begin
	eShortcut.Clear;
	cbJenres.ClearSelection;
	mDescr.Text := '';
	m := STI(cbMangasID.Text);
	ll := Fetch3(@f, SQL_FETCHMANGA, ['links', m], ['manga', 'link']) = 1;
	if ll then begin
		eShortcut.Text := f.Rows[0, 1];
		bAssignShortcut.Enabled := not FileExists(OPT_MANGADIR + '\' + eShortcut.Text);
	end else
		eShortcut.Text := ITS(m, 0, 6);

	for i := 0 to fmanga.Count - 1 do
		if STI(fmanga.Rows[i, 0]) = m then begin
			mDescr.Text := fmanga.Rows[i, 1];

			c := 0;
			for j := 0 to ftitles.Count - 1 do begin
				s1 := ftitles.Rows[j, 1];
				if STI(ftitles.Rows[j, 0]) = m then
					if has(t, c, s1) < 0 then begin
						l := Add(t, c, s1);
						if isCyrylic(s1) and (l > 0) then begin
							s2   := t[0];
							t[0] := t[l];
							t[l] := s2;
						end;
					end;
			end;
			mTitles.Text := join(#13#10, t);

			for j := 0 to f_mjenres.count - 1 do begin
				s1 := f_mjenres.Rows[j, 2];
				k := STI(f_mjenres.Rows[j, 0]);
				if k = m then begin
					l := cbJenres.Items.IndexOf(s1);
					if l >= 0 then
						cbJenres.Selected[l] := true;
				end;
			end;

			break;
		end;
end;

procedure TDBViewer.UpdateClick(Sender: TObject);
var
	m, i, j{, k, l}: Integer;
	s1{, s2}: AnsiString;
	t: TArr;
	c: Integer;
	s: TStrings;
begin
	s := nil;
	m := STI(cbMangasID.Text);
	if m <= 0 then exit;
	SQLCommand('delete from manga m where m.id = %d', [m]);
	SQLCommand('delete from titles t where t.manga = %d', [m]);
	SQLCommand('delete from m_jenres j where j.manga = %d', [m]);
	SQLCommand('delete from descrs d where d.manga = %d', [m]);
	SQLCommand('delete from links l where l.manga = %d', [m]);

	SQLCommand(SQL_DELETEMANGA, [TBL_NAMES[TBL_MHIST], m]);
	SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_MHIST], m, UTCSecconds]);

	SQLCommand(SQL_INSERT_III, ['manga', m, 1, 1]);
	s := Explode(#13#10, Trim(mTitles.Text));
	for i := 0 to Length(s) - 1 do begin
//	for s1 in s do
		s1 := s[i];
		if Trim(s1) <> '' then
			SQLCommand('insert into titles values (%d, ''%s'')', [m, RecodeHTMLTags(Trim(s1))]);
	end;

	SQLCommand('insert into descrs values (%d, ''%s'')', [m, RecodeHTMLTags(Trim(mDescr.Text))]);
	SQLCommand('insert into links values (%d, ''%s'')', [m, AnsiString(eShortcut.Text)]);

	c := 0;
	for i := 0 to cbJenres.Items.Count - 1 do
		if cbJenres.Selected[i] then begin
			s1 := cbJenres.Items[i];
			for j := 0 to fjenres.Count - 1 do
				if fjenres.Rows[j, 1] = s1 then begin
					add(t, c, fjenres.Rows[j, 0]);
					break;
				end;
		end;

	for i := 0 to c - 1 do
		SQLCommand('insert into m_jenres values (%d, %d)', [m, STI(t[i])]);
end;

procedure TDBViewer.bAssignShortcutClick(Sender: TObject);
var
	m: Integer;
	s: AnsiString;
	f: File;
begin
	m := STI(cbMangasID.Text);
	if m <= 0 then exit;
	s := OPT_MANGADIR + '\';
	if FileExists(s + ITS(m, 0, 6)) and not FileExists(s + eShortcut.Text) then begin
		AssignFile(F, s + ITS(m, 0, 6));
		Rename(f, s + eShortcut.Text);
		bAssignShortcut.Enabled := not FileExists(s + eShortcut.Text);
	end;
end;

const
	STR_TYPES : set of TDBDataType = [dt_str, dt_longstr, dt_tinystr, dt_shortstr, dt_blob];
procedure TDBViewer.bOptimizeClick(Sender: TObject);
var
	f: EDBFetch;
	i, j, c, n, k: integer;
	lb: array [0..15] of Boolean;
	ll: array [0..15] of integer;
	ln: array [0..15] of integer;
	le: array [0..15] of TDBDataType;
	ld: array [0..15] of TDBDataType;
	s, t, d: ansistring;
	procedure OptimalType(t1: TDBDataType; s1: Integer; out t2: TDBDataType; out s2: Integer);
	var
		t: TDBDataType;
		s, s3: Integer;
	begin
		s := _db_datasize(t1);
		t2 := t1;
		s2 := s;
		for t := low(TDBDataType) to high(TDBDataType) do
		if t in STR_TYPES then begin
			s3 := _db_datasize(t);
			if (s3 < s2) and (s3 >= s1) then begin
				t2 := t;
				s2 := s3;
			end;
		end;
	end;
begin
	if tbl = nil then exit;
	s := '';
	log('-- optimizing `%s`', [tbl.name]);
	j := 0;
	k := tbl.Colls;
	for i := 0 to k - 1 do begin
		ll[i] := 0;
		le[i] := tbl.Coll[i].DataType;
		ln[i] := _db_datasize(le[i]);
		lb[i] := le[i] in STR_TYPES;
		s := join(',', [s, 't.' + tbl.Coll[i].Name]);
		inc(j, Byte(lb[i]));
	end;

	log('-- %d string collumns', [j]);
	if j <= 0 then exit;
	c := Fetch3(@f, 'select from %s t', [tbl.Name], Explode(',', s));
	log('-- %d rows', [c]);
	if c <= 0 then exit;
	n := c;
	while c > 0 do begin
		dec(c);
		i := k;
		while i > 0 do begin
			dec(i);
			if lb[i] then begin
				s := f.Rows[c, i];
				if Length(s) > ll[i] then ll[i] := Length(s);
			end;
		end;
	end;

	s := '';
	t := '';
	j := 0;
	for i := 0 to k - 1 do begin
		OptimalType(le[i], ll[i], ld[i], c);
		inc(j, Byte(le[i] <> ld[i]));
		if lb[i] then s := join(', ', [s, ITS(ll[i]) + '/' + ITS(ln[i])]);
		if lb[i] then t := join(', ', [t, ITS(ll[i]) + '/' + ITS(c)]);
	end;
	log('-- max lengths: %s', [s]);
	log('-- opt lengths: %s', [t]);
	log('-- optimizable columns: %d', [j]);
//	if j <= 0 then exit;

	s := '';
	t := '';
	d := tbl.Name;
	if d[1] <> '_' then d := '_' + d else d := copy(d, 2, maxint);
	for i := 0 to k - 1 do
		s := join(', ', [s, Format('add `%s` %s', [tbl.Coll[i].Name, _db_dataname(ld[i])])]);

	log('-- new table : alter table `%s` %s', [d, s]);
	SQLCommand('drop table `%s`', [d]);
	SQLCommand('create table `%s`', [d]);
	SQLCommand('alter table `%s` %s', [d, s]);
	c := n;
	t := '';
	d := Format('insert into `%s` values ', [d]);
	while c > 0 do begin
		dec(c);
		i := k;
		s := '';
		while i > 0 do begin
			dec(i);
			s := join(',', ['"' + f.Rows[c, i] + '"', s]);
		end;
		t := join(#13#10, [t, d + '(' + s + ');']);
	end;
	SQLCommand(t);
end;

procedure TDBViewer.Button1Click(Sender: TObject);
begin
	log(' -- load db: %b', [_db_load]);
	EnumDB;
	tbl := _table_find(cbTables.Text);
	ShowTbl;
end;

procedure TDBViewer.Button2Click(Sender: TObject);
begin
	log(' -- save db: %b', [_db_save]);
	while DB.Tables <> nil do _table_free(DB.Tables);
	log(' -- load db: %b', [_db_load]);
	EnumDB;
	tbl := _table_find(cbTables.Text);
	ShowTbl;
end;

procedure TDBViewer.Button4Click(Sender: TObject);
var
	a: array [0..5] of AnsiString;
begin
	if tbl = nil then exit;
	a[0] := e1.Text;
	if (a[0] = '0') or (STI(a[0], -1) <> -1) then
		a[0] := ITS(STI(a[0]) + 1);
	e1.Text := a[0];
	a[1] := e2.Text;
	a[2] := e3.Text;
	a[3] := e4.Text;
	a[4] := e5.Text;
	SQL('insert into `%s` values (''%s'')', [tbl.Name, join(''', ''', a)]);
	ShowTbl;
end;

var
	titles: array [0..500] of AnsiString;
	exist : array [0..500] of Boolean;
	ids   : array [0..500] of Integer;

procedure TDBViewer.bSearchRelatedClick(Sender: TObject);
var
	SR   : TSearchRec;
	f, tf: EDBFetch;
	l, n : AnsiString;
	li   : TListItem;
	nc, i: Integer;
	ul   : TStrings;
	procedure add(s: AnsiString);
	var
		id, i: Integer;
	begin
		titles[nc] := s;
		id := STI(s);
		ids[nc] := id;
		if ITS(id) <> s then begin
			id := 0;
			exist[nc] := Fetch3(@f, 'select from `%s` t where (t.link = \''%s\'') limit 1', [TBL_NAMES[TBL_LINKS], RecodeHTMLTags(s)], ['manga']) > 0;
			if exist[nc] then begin
				id := sti(f.Rows[0, 0]);
				s := its(id);
				for i := 0 to tf.Count - 1 do
					if tf.Rows[i, 0] = s then begin
						array_push(ul, s);
						break;
					end;
			end;

			ids[nc] := id;
		end;
		if id <> 0 then
			exist[nc] := Fetch3(@f, 'select from `%s` t where (t.id = %d) limit 1', [TBL_NAMES[TBL_MANGA], id], ['id']) > 0
		else
			exist[nc] := false;
//		if exist[nc] then d[nc] := id;

		inc(nc);
	end;
begin
	lvFixMangas.Clear;
	Fetch3(@tf, 'select from `%s` t', [TBL_NAMES[TBL_LINKS]], ['manga', 'link']);
	SetLength(ul, 0);

	nc := 0;
	if FindFirst(OPT_MANGADIR + '\*', faDirectory, SR) = 0 then begin
		repeat
			l := SR.Name;
			if (l = '.') or (l = '..') then continue;
			if SR.Attr and faDirectory = 0 then Continue;
			add(SR.Name);
		until FindNext(SR) <> 0;
		FindClose(SR);
	end;

	for i := 0 to tf.Count - 1 do
		if ContainsS(tf.Rows[i, 0], ul) < 0 then
			add(tf.Rows[i, 1]);

	for i := 0 to nc - 1 do begin
		n := titles[i];
		l := n;
		if exist[i] then l := ITS(ids[i], 0, 6) + ': ' + n else l := '';
		if not exist[i] then
			if ids[i] <> 0 then l := ITS(ids[i], 0, 6);

		li := lvFixMangas.Items.Add;
		li.Caption := l;
		li.Data := Pointer(ids[i]);
		li.SubItems.Add(n);
	end;
end;

function Capitalize(S: AnsiString): AnsiString;
var
	a: TStrings;
	i: Integer;
begin
	a := strSplit(' ', S);
	for i := 0 to Length(a) - 1 do
		a[i, 1] := UpCase(a[i, 1]);
	result := join(' ', a);
end;

function LowerID(ID: Integer): Integer;
var
	f: EDBFetch;
begin
	result := -1;
	if id <= 0 then exit;
	repeat
		dec(id);
		if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_TITLES], id], ['title']) > 0 then continue;
		break;
	until id <= 0;
	result := id;
end;

function HigherID(ID: Integer): Integer;
var
	f: EDBFetch;
begin
	repeat
		inc(id);
		if Fetch3(@f, SQL_FETCHMANGAL, [TBL_NAMES[TBL_TITLES], id], ['title']) > 0 then continue;
		break;
	until false;
	result := id;
end;

var

	prew: string;

procedure TDBViewer.lvFixMangasChange(Sender: TObject; Item: TListItem; Change: TItemChange);
var
	e, f: AnsiString;
	n: AnsiString;
	id, i: Integer;
begin
	if (Item = nil) or (Change <> ctState) then exit;
	n := Item.SubItems[0];
	if n = '' then begin
		n := Item.Caption;
		id := pos(': ', n);
		n := copy(n, id + 2, MaxInt);
	end;
	eMShortcut.Text := n;
	eMangaTitle.Text := Capitalize(n);
	id := Integer(Item.Data);
	if id = 0 then
		if ITS(sti(n), 0, 6) = n then
			id := sti(n);

	if id = 0 then
		if DBChanged then
			id := HigherID(0)
		else
			id := STI(eMID.Text);

	DBChanged := false;
	eMID.Text := ITS(iMax(0, id));

	Panel2.Update;
	try
		try iFixFirstPage.Graphic.Width := 0; except end;
		for i := 0 to length(graphic_ext) - 1 do begin
			e := graphic_ext[i];
			f := Format('%s\\%s\\%d.4\\%d.4\.%s', [OPT_MANGADIR, n, 1, 1, e]);
			if FileExists(f) then begin
				if prew <> f then
					iFixFirstPage.LoadFromFile(f);
					prew := f;
					modifFirstPage;
				break;
			end;
		end;
	except
		try
			iFixFirstPage.LoadFromFile(Format('%s\\previews\\unk.bmp', [OPT_DATADIR]));
			modifFirstPage;
		except
		end;
	end;
	modifFirstPage;
end;

procedure TDBViewer.modifFirstPage;
var
//	g: TGraphic;
	b: TBitmap;
	d1, d2, d3: HDC;
	s: single;
	iw, ih, w, h, rw, rh: Integer;
begin
	b := TBitmap.Create;
	try
	b.Assign(iFixFirstPage.Graphic);
	if b.Empty then exit;

	iw := b.Width;
	ih := b.Height;
	w  := iw;
	h  := ih;
	rw := pFixFirstPage.Width - 4;
	rh := pFixFirstPage.Height - 4;
	s := iw / ih;

	if h > rh then begin
		h := rh;
		w := trunc(h * s);
	end;

	if w > rw then begin
		w := rw;
		h := trunc(w / s);
	end;

	d1 := getdc(0);
	d2 := CreateCompatibleDC(d1);
	SelectObject(d2, b.Handle);

	d3 := GetDC(pFixFirstPage.Handle);

	SetStretchBltMode(d3, MAXSTRETCHBLTMODE);
	StretchBlt(d3, (rw - w) div 2 + 2, (rh - h) div 2 + 2, w, h,
		d2, 0, 0, iw, ih, SRCCOPY
	);

	ReleaseDC(pFixFirstPage.Handle, d3);

	DeleteObject(d2);

	releasedc(0, d1);
	finally
		b.Free;
	end;
end;

procedure TDBViewer.modifPreview;
var
	b: TBitmap;
	d1, d2, d3: HDC;
	s: single;
	iw, ih, w, h, rw, rh: Integer;
begin
	b := iFixPreview.Bitmap;
	if b.Empty then exit;

	iw := b.Width;
	ih := b.Height;
	w  := iw;
	h  := ih;
	rw := pFixpreview.Width - 4;
	rh := pFixpreview.Height - 4;
	s := iw / ih;

	if h > rh then begin
		h := rh;
		w := trunc(h * s);
	end;

	if w > rw then begin
		w := rw;
		h := trunc(w / s);
	end;

	d1 := getdc(0);
	d2 := CreateCompatibleDC(d1);
	SelectObject(d2, b.Handle);

	d3 := GetDC(pFixpreview.Handle);

	SetStretchBltMode(d3, MAXSTRETCHBLTMODE);
	StretchBlt(d3, (rw - w) div 2 + 2, (rh - h) div 2 + 2, w, h,
		d2, 0, 0, iw, ih, SRCCOPY
	);

	ReleaseDC(pFixpreview.Handle, d3);

	DeleteObject(d2);

	releasedc(0, d1);
end;

procedure TDBViewer.eMIDChange(Sender: TObject);
begin
	try
		iFixPreview.LoadFromFile(Format('%s\\previews\\%d.6.bmp', [OPT_DATADIR, STI(eMID.Text)]));
	except
		try
			iFixPreview.LoadFromFile(Format('%s\\previews\\unk.bmp', [OPT_DATADIR]));
		except
		end;
	end;
	modifPreview;
end;

procedure TDBViewer.aMIDPrevExecute(Sender: TObject);
var
	id: Integer;
begin
	id := STI(eMID.Text);
	if id <= 0 then exit;
	eMID.Text := its(LowerID(id));
end;

procedure TDBViewer.Button10Click(Sender: TObject);
var
	id: Integer;
begin
	id := STI(eMID.Text);
	eMID.Text := its(HigherID(id));
end;

procedure TDBViewer.Button9Click(Sender: TObject);
begin
	SQL(Edit4.Text);
	ShowResult;
end;

procedure TDBViewer.e1Click(Sender: TObject);
begin
	TEdit(Sender).SelectAll;
end;

procedure TDBViewer.Button8Click(Sender: TObject);
begin
	tbl := _table_find(cbTables.Text);
	ShowTbl;
end;

procedure TDBViewer.EnumDB;
var
	t: PDBTable;
	s: AnsiString;
begin
	s := cbTables.Text;
	t := DB.Tables;
	if (s = '') and (t <> nil) then s := t.Name;
	while t <> nil do begin
		cbTables.Items.Add(t.Name);
		t := t.Next;
	end;
	cbTables.ItemIndex := cbTables.Items.IndexOf(s);
end;

procedure TDBViewer.FormCreate(Sender: TObject);
var
	Config : TConfigNode;
begin
	iFixPreview := TPicture.Create;
	iFixFirstPage := TPicture.Create;
	tbl := nil;
	EnumDB;
	SetLogHandler(loghdl);
//	l_SetHandler(loghdl);
//	l_Start('data/logs');

	Config := TConfigNode.Create('config');
	if Config.LoadConfig('ergo.cfg') then begin
		SQL_DBPATH := Config['dbdir'];
		if Config['mangadir'] <> '' then OPT_MANGADIR := ExpandFileName(Config['mangadir']);
		if Config['datadir'] <> '' then OPT_DATADIR := ExpandFileName(Config['datadir']);
	end;
end;

function TDBViewer.loghdl(Msg: PChar): Boolean;
begin
	Log(Msg, []);
	result := false;
end;

function FillStr(l, r: AnsiString; J: AnsiChar; S: Integer): AnsiString;
begin
	dec(s, Length(l) + Length(r));
	if s > 0 then begin
		SetLength(result, s);
		while s > 0 do begin
			result[s] := J;
			dec(s);
		end;
	end else
		result := '';
	result := l + result + r;
end;

procedure TDBViewer.ShowTbl;
var
	i, j{, k}: Integer;
	C: PDBCollumn;
	S1, S2, S3: AnsiString;
//	R: Pointer;
begin
	ListBox1.Clear;
	if tbl = nil then Exit;
	s1 := '';
	s2 := '';
	for i := 0 to tbl.Colls - 1 do begin
		c := @tbl.coll[i];
		s1 := join(' | ', [s1, FillStr(C.Name, '', ' ', 12)]);
		s2 := join('-+-', [s2, FillStr('', '', '-', 12)]);
	end;
	ListBox1.Items.Add(S1);
	ListBox1.Items.Add(S2);

	for i := 0 to tbl.Rows - 1 do begin
		s2 := '';
		for j := 0 to tbl.Colls - 1 do begin
			s3 := PAnsiChar(_table_get_str(tbl, i, j));
			s2 := join(' | ', [s2, FillStr(s3, '', ' ', 12)]);
		end;
		ListBox1.Items.Add(S2);
	end;
end;

procedure TDBViewer.Log(Msg: AnsiString; Params: array of const);
begin
	lLog.Items.Add(Format(Msg, Params));
	lLog.ItemIndex := lLog.Count - 1;
end;

function TDBViewer.SQL(R: AnsiString): Cardinal;
var
	sql: TInterpreter;
	i: integer;
	WorkHeap, o: PDBOperation;
begin
	result := DB_OP_EXCEPTION;
	sql := TInterpreter.Create;
	R := R + ';';
	try
		try
			try
				if sql.Preprocess(@R[1], Pointer(WorkHeap)) then begin
					log('-- ' + R, []);
					o := WorkHeap;
					while o <> nil do begin
						result := _db_operate(o);
						log(' > %s', [_DB_STAT(result)]);
						if result <> DB_OK then break;
						o := o.Next;
					end;
				end;
			finally
				if WorkHeap <> nil then
					FreeMemory(WorkHeap);
			end;
		except
			on E: Exception do begin
				log('-- ' + R, []);
				log('-- Internal exception while executing request: %s', [E.Message]);
				exit;
			end;
			on E: TObject do begin
				log('-- ' + R, []);
				log('-- Internal exception while executing request: %s', [WideString(Exception(E).Message)]);
				exit;
			end;
		end;
		for i := 0 to sql.Errors - 1 do
			log('-- sql compilation error: %s', [Exception(sql.Error[i]).Message]);
	finally
		sql.Free;
	end;
end;

function TDBViewer.SQL(R: AnsiString; P: array of const): Cardinal;
begin
	result := SQL(Format(R, P));
end;

procedure TDBViewer.TabSheet1Show(Sender: TObject);
begin
	AquireMangaData;
end;

procedure TDBViewer.TabSheet3Show(Sender: TObject);
begin
	DBChanged := true;
	log(' -- load db: %b', [_db_load]);
end;

procedure TDBViewer.ShowResult;
var
	r, t: PDBSelResult;
	procedure DumpReqRes(R: PDBSelResult);
	type
		TIndex= array [0..0] of Integer;
		PIndex=^TIndex;
	var
		i, j, k, o: Integer;
		t: PDBTable;
		c: PDBCollumn;
		s, h, l: AnsiString;
		d: PIndex;
	begin
		s := '';
		l := '';
		for i := 0 to r.TableCnt - 1 do begin
			t := r.Tables[i].Table;
			for j := 0 to t.Colls - 1 do begin
				c := @t.Coll[j];
				h := FillStr(r.Tables[i].Alias + '.' + c.Name, '', ' ', 10);
				s := join(' | ', [s, h]);
				l := join('-+-', [l, '----------']);
			end;
		end;
		ListBox1.Items.Add(s);
		ListBox1.Items.Add(l);
		d := r.Rows;
		o := SizeOf(Integer) * r.TableCnt;
		for k := 0 to r.RowCnt - 1 do begin
			s := '';
			for i := 0 to r.TableCnt - 1 do begin
				t := r.Tables[i].Table;
				for j := 0 to t.Colls - 1 do begin
					{c := @t.Coll[j];}
					s := join(' | ', [s, FillStr(_table_get_str(t, d[i], j), '', ' ', 10)]);
				end;
			end;
			ListBox1.Items.Add(s);
			inc(Cardinal(d), o);
		end;
		ListBox1.Items.Add('');
	end;
begin
	ListBox1.Clear;
	r := DB.Requests;
	while r <> nil do begin
		DumpReqRes(r);
		t := r;
		r := r.Prev;
		_db_req_free(t);
	end;
end;

end.
