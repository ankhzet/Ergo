unit rss_agregator;
interface
uses
		XMLToolkit
	;

(*

title>етрџ! Уыртр 21!</title>
<description><![CDATA[<div align="center"><span id="eMessage549445" style="font-size: 10pt"><img alt="" src="http://i29.fastpic.ru/big/2011/1126/37/75126ec599eeb38d8d644a9e34e72537.png" border-left-color: rgb(0, 0, 0); border-left-width: 2px; border-left-style: solid; border-right-color: rgb(0, 0, 0); border-right-width: 2px; border-right-style: solid; " align="absmiddle" width="410px"></span></div><div align="center"><span style="font-size: 10pt;">...]]></description>
<link>http://rikudou.ru/news/khvaja_glava_21/2011-12-15-1773</link>
<category>Hwaja</category>
<dc:creator>Хтр</dc:creator>
<guid>http://rikudou.ru/news/2011-12-15-1773</guid>
<pubDate>Wed, 14 Dec 2011 20:08:12 GMT</pubDate>

*)


type
	PFeed         =^TFeed;
	TFeed         = record
		Title       : AnsiString;
		Dscr        : AnsiString;
		Link        : AnsiString;
		Category    : AnsiString;
		Creator     : AnsiString;
		GUID        : AnsiString;
		PubDate     : Cardinal;
	end;
	TRSSChanel    = class
	private
		fLink       : AnsiString;
		fTitle      : AnsiString;
		fBuild      : Cardinal;
		fID         : Cardinal;
		fFeeds      : Integer;
		Actual      : Integer;
		procedure     setFeeds(const Value: Integer);
		function      getFeed(Index: Integer): PFeed;
		function      RegFeed(AFeed: TXMLNode): Integer;
	public
		fData       : array of TFeed;
		procedure     AquireFromDB;
		procedure     AquireFromXML(XMLData: PAnsiChar);
		property      Link: AnsiString read fLink write fLink;
		property      ID: Cardinal read fID;
		property      Build: Cardinal read fBuild;
		property      Title: AnsiString read fTitle;
		property      Feeds: Integer read fFeeds write setFeeds;
		property      Feed[Index: Integer]: PFeed read getFeed; default;
	end;
	TRSSAgregator = class
	private
	public
	end;

implementation
uses
		sql_constants
	, strings
	;

{ TRSSChanel }

const
	Str_Month: ansistring = 'JanFebMarAprMayJunJulAugSepOctNovDec';

function RFC1123ToCardinal(Date: ansistring): Cardinal;
var
  day, month, year: Integer;
  strMonth: ansistring;
  Hour, Minute, Second: Integer;
begin
	try
		day := STI(Copy(Date, 6, 2));
		strMonth := Copy(Date, 9, 3);
		month := pos(strMonth, Str_Month) div 3 + 1;
		year := STI(Copy(Date, 13, 4));
		hour := STI(Copy(Date, 18, 2));
		minute := STI(Copy(Date, 21, 2));
		second := STI(Copy(Date, 24, 2));
		Result := second + 60 * (minute + 60 * (hour + 24 * (day + 31 * (month + 12 * (year - 1990)))));
	except
		Result := 0;
	end;
end;

procedure TRSSChanel.AquireFromXML(XMLData: PAnsiChar);
var
	XML: TXMLNode;
	P: TXMLParser;
	procedure DoAquire;
	var
		Channel, c: TXMLNode;
		OldBuild, b, b1: Cardinal;
	begin
		OldBuild := Build;
		b1 := OldBuild;
		Channel := XML['rss']['channel'];
		fTitle := Channel['title'].ToString;
//		fLink  := Channel['link'].ToString;

		for c in Channel.fChilds do
			if c.Name = 'item' then begin
				b := RFC1123ToCardinal(c['pubdate'].ToString);
				if b > b1 then b1 := b;
				if b > OldBuild then
					RegFeed(c);
			end;
		SQLCommand(SQL_DELETEID, [TBL_NAMES[TBL_RSS], ID]);
		SQLCommand(SQL_INSERT + '(%d, "%s", "%s", %d)', [TBL_NAMES[TBL_RSS], ID, Link, Title, b1]);
	end;
begin
	XML := TXMLNode.Create(nil, 'xml');
	try
		P := TXMLParser.Create;
		try
			try
				if P.Execute(XMLData, XML) then ;
			except

			end;
			DoAquire;
		finally
			P.Free;
		end;
	finally
		XML.Free;
	end;
end;

procedure TRSSChanel.AquireFromDB;
var
	f: TDBFetch;
	procedure AquireFeeds;
	var
		i: Integer;
	begin
		f.Fetch(SQL_SELECT + ' where (t.chanel = %d) order by t.pubdate reverse', [TBL_NAMES[TBL_RSSFDS], ID], ['title', 'dscr', 'link', 'creator', 'category', 'guid', 'pubdate']);
		Feeds := f.Count;
		for i := 0 to f.Count - 1 do
			with f, Feed[i]^ do begin
				Title    := Rows[i, 0];
				Dscr     := Rows[i, 1];
				Link     := Rows[i, 2];
				Creator  := Rows[i, 4];
				Category := Rows[i, 3];
				GUID     := Rows[i, 5];
				PubDate  := STI(Rows[i, 6]);
			end;
	end;
begin
	f.Fetch(SQL_SELECT + ' where t.`link` = "%s"', [TBL_NAMES[TBL_RSS], Link], ['id', 'title', 'build']);
	if f.Count = 1 then begin
		fID    := f.Int[0];
		fTitle := f.Str[1];
		fBuild := f.Int[2];
		AquireFeeds;
	end else begin
		Feeds := 0;
		fID    := 0;
		fTitle := fLink;
		fBuild := 0;
	end;
end;

function TRSSChanel.getFeed(Index: Integer): PFeed;
begin
	result := @fData[Index];
end;

function TRSSChanel.RegFeed(AFeed: TXMLNode): Integer;
var
	Ttl, Dscr, Lnk, Guid, Crtr, Cat: AnsiString;
	PubDate: Cardinal;
begin
	Ttl     := StrValue(AFeed['title']);
	Dscr    := StrValue(AFeed['description']);
	Lnk     := StrValue(AFeed['link']);
	Guid    := StrValue(AFeed['guid'], Lnk);
	Crtr    := StrValue(AFeed['dc:creator'], 'unknown');
	Cat     := StrValue(AFeed['category']);
	PubDate := RFC1123ToCardinal(StrValue(AFeed['pubdate']));
	// chanel int, title str, dscr shortstr, guid str, link str, creator tinystr, category tinystr, pubdate int
	SQLCommand(SQL_INSERT + '(%d, "%s", "%s", "%s", "%s", "%s", "%s", %d)', [
			TBL_NAMES[TBL_RSSFDS]
		, ID
		, Ttl
		, Dscr
		, Lnk, Guid
		, Crtr
		, Cat
		, PubDate
		]);
end;

procedure TRSSChanel.setFeeds(const Value: Integer);
begin
	if fFeeds <> Value then begin
		if (Value > Actual) or (Value < Actual - $1F) then Actual := Value + $F;
		fFeeds := Value;
		setLength(fData, Actual);
	end;
end;

end.
