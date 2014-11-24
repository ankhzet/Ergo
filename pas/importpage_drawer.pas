unit importpage_drawer;
interface
uses
		page_drawer
	, plate_drawer
	, vcl_edit
	, vcl_button
	, vcl_reportbox
	, s_config
	, homepage_drawer
	;

type
	TImportPage  = class(TPage)
	private
		eL, eD     : TEdit;
		b1         : TButton;
		procedure    Add(Sender: TObject);
	public
		procedure    InitSB; override;
		function     Action(UID: Cardinal): Boolean; override;
	end;


implementation
uses
		functions
	, strings
	, sql_constants;

{ TSearchPage }

function TImportPage.Action(UID: Cardinal): Boolean;
begin
	result := true;
	case UID of
		SB_CLOSE: Reader.ActivePage := rp_home;
		else result := false;
	end;
end;

procedure TImportPage.Add(Sender: TObject);
var
	f: TDBFetch;
	i, id: Integer;
	s, d: AnsiString;
begin
	s := RecodeHTMLTags(Trim(el.Caption));
	d := RecodeHTMLTags(Trim(ed.Caption));
	if s = '' then begin
		Reader.LogMSG := 'Empty titles not allowed...';
		exit;
	end;
	id := 0;
	if f.fetch('select from `manga` m', ['m.id']) > 0 then begin
		for i := 0 to f.Count - 1 do
			id := imax(id, STI(f.Rows[i, 0]));
	end;
	inc(id);

	SQLCommand(SQL_DELETEID   , ['manga', id]);
	SQLCommand(SQL_DELETEMANGA, ['links', id]);
	SQLCommand(SQL_DELETEMANGA, ['titles', id]);
	SQLCommand(SQL_DELETEMANGA, ['m_jenres', id]);
	SQLCommand(SQL_DELETEMANGA, ['descrs', id]);

	SQLCommand('insert into `%s` values (%d, %d, 1);', [TBL_NAMES[TBL_MANGA], id, 0]);
	SQLCommand('insert into `%s` values (%d, 0, 0);', [TBL_NAMES[TBL_STATES], id]);
	SQLCommand(SQL_INSERT_IS, [TBL_NAMES[TBL_TITLES], id, s]);
	SQLCommand(SQL_INSERT_IS, [TBL_NAMES[TBL_LINKS], id, LowerCase(s)]);
	SQLCommand(SQL_INSERT_IS, [TBL_NAMES[TBL_DESCRS], id, d]);
	SQLCommand(SQL_INSERT_II, [TBL_NAMES[TBL_MHIST], id, UTCSecconds]);
	try
		Reader.ActivePage := rp_home;
	except

	end;
	Reader.Selected := Reader.Plates.Order[Reader.Plates.IndexOf(id)];
end;

procedure TImportPage.InitSB;
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


	ed := TEdit.Create(Reader);
	ed.Left := 10;
	ed.Top := RD_TOPPLANE + 40;
	ed.Width := Width - 20;
	ed.Height := 120;
end;

end.
