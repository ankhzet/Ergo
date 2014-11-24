unit rss_drawer;
interface
uses
		plate_drawer
	, page_drawer
	, vcl_edit
	, vcl_button
	, vcl_listbox
	, s_config
	, homepage_drawer
	;

type
	TRSSPage     = class(TPage)
	private
		eL         : TEdit;
		LL         : TListBox;
		b1         : TButton;
		procedure    Add(Sender: TObject);
	public
		constructor  Create(Reader: TReader); override;
		destructor   Destroy; override;
		procedure    Size(W, H: Integer); override;
		procedure    InitSB; override;
		procedure    NavigateTo(From: TRPages); override;
		procedure    Action(UID: Cardinal); override;
	end;


implementation
uses
		functions
	, strings
	, sql_constants
	, s_httpproxy
	, rss_agregator
	;

{ TSearchPage }

procedure TRSSPage.Action(UID: Cardinal);
begin
	case UID of
		SB_CLOSE: Reader.ActivePage := rp_home;
	end;
end;

constructor TRSSPage.Create(Reader: TReader);
begin
	inherited;

end;

destructor TRSSPage.Destroy;
begin

	inherited;
end;

procedure TRSSPage.Add(Sender: TObject);
var
	f: TDBFetch;
	i, id: Integer;
	s, d: AnsiString;
begin
	s := Trim(el.Caption);
	if s = '' then begin
		Reader.LogMSG := 'Empty links not allowed...';
		exit;
	end;
	f.Fetch(SQL_SELECT + ' order by t.id', [TBL_NAMES[TBL_RSS]], ['t.id']);
	if f.Count > 0 then id := f.Int[0] + 1 else id := 1;
	SQLCommand(SQL_INSERT + '(%d, "%s", "%s", 0)', [TBL_NAMES[TBL_RSS], id, s, s]);
	NavigateTo(rp_rss);
end;

procedure TRSSPage.InitSB;
begin
	el := TEdit.Create(Reader);
	el.Left := 10;
	el.Top := RD_TOPPLANE + 10;
	el.Width := Width - 120;
	el.Height := 20;
	el.Focused := true;

	b1 := TButton.Create(Reader);
	b1.Left := Width - 10 - 90;
	b1.Top := RD_TOPPLANE + 10;
	b1.Width := 90;
	b1.Height := 20;
	b1.Caption := 'Добавить';
	b1.OnClick := Add;

	LL := TListBox.Create(Reader);
	LL.Left := 10;
	LL.Top := RD_TOPPLANE + 40;
	LL.Width := Width - 20;
	LL.Height := Height - LL.Top - 10;
end;

procedure SplitUriHost(URL: AnsiString; out Host, URI: AnsiString);
var
	p, i, l: Integer;
begin
	URL := LowerCase(URL);
	p := 1;
	if pos('http://', URL) > 0 then inc(p, 7);
	i := p;
	l := Length(URL);
	while (i <= l) and not (URL[i] in ['/']) do inc(i);
	while (i <= l) and not (URL[i] in ['/', '\']) do inc(i);
	Host := copy(URL, p, i - p);
	URI  := copy(URL, i, maxint);
end;

procedure TRSSPage.NavigateTo(From: TRPages);
var
	f: TDBFetch;
	R: TRowFetch;
	H, U: AnsiString;
	P: THTTPProxy;
	RSS: TRSSChanel;
	e: PFeed;
	i: Integer;
begin
	inherited;
	LL.Items.Count := 0;
	f.Fetch(SQL_SELECT, [TBL_NAMES[TBL_RSS]], ['link']);
	if f.Count <= 0 then exit;
	P := THTTPProxy.Create;
	try
		RSS := TRSSChanel.Create;
		try
			for R in f.Rows do begin
					RSS.Link := R[0];
					RSS.AquireFromDB;
					SplitUriHost(RSS.Link, H, U);
					LL.Items.Add(Format('[%s] %s', [H, U]));
					if P.Request(H, U) then
						RSS.AquireFromXML(P.Content);
					RSS.AquireFromDB;
					for i := 0 to RSS.Feeds - 1 do
						with RSS[i]^ do
							LL.Items.Add(Format('  %s [%s]', [Title, Link]));
			end;
		finally
			RSS.Free;
		end;
	finally
		P.Free;
	end;
end;

procedure TRSSPage.Size(W, H: Integer);
begin
	inherited;

end;

end.
