unit c_webmodel;
interface
uses
	strings, c_http, c_buffers, c_manga, c_jenres, c_interactive_lists, sql_dbcommon;

type
	TInterfacedObject = class(TObject, IInterface)
	protected
		FRefCount: Integer;
		function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
		function _AddRef: Integer; stdcall;
		function _Release: Integer; stdcall;
	public
		procedure AfterConstruction; override;
		procedure BeforeDestruction; override;
		class function NewInstance: TObject; override;
		property RefCount: Integer read FRefCount;
	end;

	TProcType   = (pt_final, pt_process);
	IPlugin = interface
		['{8B2E0C8F-DE5E-41C5-BA3C-8C8938F6F6DB}']
		procedure   Action(r: TStrings; Processor: PReqProcessor);
		function    ctlToID(Action: AnsiString): Integer;
		procedure   serveAction(ID: Integer; r: TStrings; Processor: PReqProcessor);
		function    Name: PAnsiChar;
	end;

	IServer     = interface
		['{89EDEFFD-54F2-4F7C-A37E-3F4A02CB39E6}']
		function    getCTL(Index: Integer): IPlugin;
		function    getCtlNamed(Name: PAnsiChar): IPlugin;

		function    MangaData(ID: Integer; var Data: TManga): Boolean;
		function    SetMangaData(ID: Integer; Data: PManga): Boolean;

		function    Config(Key: PAnsiChar): PAnsiChar;
		procedure   ListModified;
		procedure   LoadMangaList;
		procedure   AquireProgress(Manga: PManga);
		function    GetList: PIList;
		procedure   getFilters(out yes, no: TJenreFilter);
		procedure   setFilters(out yes, no: TJenreFilter);
		procedure   getJenres(out Jenres: TJenres);
		function    SQL(Query: AnsiString): Cardinal;
		function    Fetch(f: PDBFetch; SQL: AnsiString; Colls: array of AnsiString): Integer;
		procedure   Log(Msg: AnsiString; Params: array of const);
		procedure   Stop;
		function    FetchLog(FromId: Integer; ToId: Integer = 0): PAnsiChar;
		function    LogLines: Integer;

		property    Ctl[Index: Integer]: IPlugin read getCTL; default;
		property    CtlNamed[Name: PAnsiChar]: IPlugin read getCtlNamed;
	end;

	TController = class(TInterfacedObject, IPlugin)
	private
		fReqServer: IServer;
	protected
		procedure   Action(r: TStrings; Processor: PReqProcessor); virtual;
		function    ctlToID(Action: AnsiString): Integer; virtual;
		procedure   serveAction(ID: Integer; r: TStrings; Processor: PReqProcessor); virtual;
	public
		constructor Create;
		function    Name: PAnsiChar; virtual;
		property    Server: IServer read fReqServer write fReqServer;
	end;

	TClousureCtl= class(TController)
	public
		procedure   Action(r: TStrings; Processor: PReqProcessor); override;
	end;

function action_split(var uri: AnsiString): AnsiString;
function CLSIDFromString(psz: PWideChar; out clsid: TGUID): HResult; stdcall;


implementation
uses
	functions;

function CLSIDFromString; external 'ole32.dll' name 'CLSIDFromString';

{ TController }

function action_split(var uri: AnsiString): AnsiString;
var
	i: Integer;
begin
	delete(URI, 1, 1);
	i := pos('/', URI);
	if i <= 0 then
		result := URI
	else
		result := copy(URI, 1, i - 1);

	delete(URI, 1, Length(result));
end;

procedure TController.Action(r: TStrings; Processor: PReqProcessor);
var
	i: Integer;
begin
	if length(r) = 0 then
		i := 0
	else begin
		i := ctlToID(r[0]);
		if i >= 0 then
			array_shift(r)
		else
			i := 0;
	end;
	serveAction(i, r, Processor);
end;

function TController.Name: PAnsiChar;
begin
	result := 'index';
end;

procedure TController.serveAction(ID: Integer; r: TStrings; Processor: PReqProcessor);
begin
	Processor.Status := 404;
end;

function TController.ctlToID(Action: AnsiString): Integer;
begin
	result := stringcase(@Action[1], ['index']);
end;

constructor TController.Create;
begin
end;

{ TClousureCtl }

function _cbp_process(B: PCacheBuffer): Boolean;
var
	t1, t2: AnsiString;
begin
	t2 := _cb_clear(b);
	with PReqProcessor(_cb_data(B))^ do
		repeat
			t1 := t2;
			t2 := TPLRE.ReplaceEx(t1, KeyReplacer);
		until t1 = t2;
	_cb_append(b, t2);
	result := true;
end;

procedure TClousureCtl.Action(r: TStrings; Processor: PReqProcessor);
var
	i: Integer;
begin
	_cb_new(Processor.IOBuffer, Cardinal(Processor));
	try
		_cb_add_onfin(Processor.IOBuffer, _cbp_process);
		if length(r) = 0 then
			i := 0
		else begin
			i := ctlToID(r[0]);
			if i >= 0 then
				array_shift(r)
			else
				i := 0;
		end;
		try
			serveAction(i, r, Processor);
		except
			on Ex: Exception do begin
				if @Processor.Formatter = @_JSON_Formatter then
					_cb_append(Processor.IOBuffer, '{"result": "err", "msg": "' + strsafe(Ex.Message) + '"}')
				else
					try
						Processor.KeyData.Add('content', '<div id="message" class="error"><span><span>' + Ex.Message + '</span></span></div>');
						_cb_outtemlate(Processor.IOBuffer, 'index');
					except
						Processor.Status := 500;
					end;
			end;
		end
	finally
		_cb_end(Processor.IOBuffer);
	end;
end;

{ TInterfacedObject }

function TInterfacedObject._AddRef: Integer;
begin
	result := 0;
end;

function TInterfacedObject._Release: Integer;
begin
	result := 0;
end;

procedure TInterfacedObject.AfterConstruction;
begin
end;

procedure TInterfacedObject.BeforeDestruction;
begin
end;

class function TInterfacedObject.NewInstance: TObject;
begin
	Result := inherited NewInstance;
	TInterfacedObject(Result).FRefCount := 1;
end;

function TInterfacedObject.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
	if GetInterface(IID, Obj) then
		Result := 0
	else
		Result := E_NOINTERFACE;
end;

end.
