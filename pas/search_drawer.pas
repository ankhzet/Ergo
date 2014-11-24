unit search_drawer;
interface
uses
		page_drawer
	, vcl_edit
	, vcl_reportbox
	, s_config
	;

type
	TSerchRec     = record
		src         : Integer;
		Title       : AnsiString;
		Link        : AnsiString;
	end;
	TRecs         = array of TSerchRec;

	TSearchPage   = class(TPage)
	private
		res        : TConfigNode;
		List       : TRecs;
		e          : TEdit;
		l1, l2     : TReportBox;
		procedure    AquireList;
		procedure    ApplyFilter;
		procedure    EChanged(Sender: TObject);
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
		WinAPI
	, strings
	, s_engine
	, plate_drawer
	, functions
	, fyzzycomp
	;

{ TSearchPage }

procedure TSearchPage.Action(UID: Cardinal);
begin
	case UID of
		SB_CLOSE: Reader.ActivePage := rp_home;
	end;
end;

procedure TSearchPage.ApplyFilter;
var
	i, j, k: Integer;
	l: TItemList;
	t: AnsiString;
	r: TStats;
begin
	t := e.Caption;
	l := l1.Items;
	j := l.Add(t);
	try
		i := FyzzyAnalyze(l, j, 1 {seMatcing.Value{}, r);
		l2.Items.Count := 0;
		//		lbFilterList.Clear;
		t := '';
		k := l.Count;
		while k > 0 do begin
			dec(k);
			if k = j then continue;
			if R[k].R > 0 then begin
				l2.Items.Add(l1.Items[k]);
//				lbFilterList.Items.AddObject(lbSearchList.Items[k], lbSearchList.Items.Objects[k]);
				if k = i then
					t := l2.Items[k];
			end;
		end;
		if l2.Items.Count = 0 then begin
			l2.Visible := false;
			l1.Visible := true;
		end else
//			lbFilterList.ItemIndex := lbFilterList.Items.IndexOf(t);
	finally
		l.Delete(j);
	end;
end;

procedure TSearchPage.AquireList;
var
	i: Integer;
	l: TConfigNode;
	s: TString;
	function Add(src: Integer; Title, Link: AnsiString): Integer;
	begin
		result := Length(List);
		SetLength(List, result + 1);
		List[result].src := src;
		List[result].Title := Title;
		List[result].Link := Link;
	end;
begin
	SetLength(List, 0);
	if Request('{a=search;}', res) then begin
		l := TConfigNode(res.Find('dmangas').Childs);
		while l <> nil do begin
			i := STI(l.Name);
			s := TString(l.Childs);
			while s <> nil do begin
				Add(i, S.Value, s.Name);
				L1.Items.Add(Format('%d3: "%s" at [%s]', [i, s.Value, s.Name]));
//				lbSearchList.Items.AddObject(Format('%d3: "%s" at [%s]', [i, s.Value, s.Name]), TString.Create(s.Name));
				s := TString(s.Next);
			end;
			l := TConfigNode(l.Next);
		end;
	end;
end;

constructor TSearchPage.Create(Reader: TReader);
begin
	inherited;
	res := TConfigNode.Create('');
end;

destructor TSearchPage.Destroy;
begin
	res.Free;
	inherited;
end;

procedure TSearchPage.EChanged(Sender: TObject);
var
	filter: Boolean;
begin
	filter := Length(TEdit(Sender).Caption) > 2;
	if filter then begin
		l1.Visible := false;
		l2.Visible := true;
		ApplyFilter;
	end else begin
		l2.Visible := false;
		l1.Visible := true;
	end;
end;

procedure TSearchPage.InitSB;
begin
	e := TEdit.Create(Reader);
	e.Left := 10;
	e.Top := RD_TOPPLANE + 10;
	e.Width := Width - 20;
	e.Height := 20;
	e.Focused := true;
	e.OnChange := EChanged;

	l2 := TReportBox.Create(Reader);
	l2.Visible := false;
	l2.Left := 10;
	l2.Top := e.Top + e.Height + 10;
	l2.Width := Width - 20;
	l2.Height := Height - 10 - l2.Top;
	l1 := TReportBox.Create(Reader);
	l1.Left := 10;
	l1.Top := e.Top + e.Height + 10;
	l1.Width := Width - 20;
	l1.Height := Height - 10 - l1.Top;
end;

procedure TSearchPage.NavigateTo(From: TRPages);
begin
	AquireList;
end;

procedure TSearchPage.Size(W, H: Integer);
begin
	inherited;
	if (e = nil) or (l1 = nil) then exit;
	e.Width := Width - 20;
	l1.Width := e.Width;
	l1.Height := imax(0, Height - 10 - l1.Top);
	l2.Width := e.Width;
	l2.Height := imax(0, Height - 10 - l2.Top);
end;

end.
