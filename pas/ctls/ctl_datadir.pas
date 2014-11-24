unit ctl_datadir;
interface
uses
	c_httpheaders
, c_http
, c_webmodel
, strings
 ;

type
	TDataDir    = class(TController)
	private
	public
		function    ProcessAction(URI: AnsiString; Params: THTTPHeaders; Res: PHTTPResReq): TProcType; override;
		function    Name: PAnsiChar; override;
	end;


implementation
uses
		functions
	, file_sys
	, opts
	;

{ TDataDir }

function TDataDir.Name: PAnsiChar;
begin
	result := 'data';
end;

function TDataDir.ProcessAction(URI: AnsiString; Params: THTTPHeaders; Res: PHTTPResReq): TProcType;
var
	r, e: AnsiString;
begin
	result := pt_process;
	r := action_split(URI);
	case stringcase(@r[1], [nil, 'index']) of
		0, 1: begin
			KeyData.Add('content', '<div class="block">Here must be dir listing</div>');
		end;
		else begin
			uri := '/' + r + uri;
			e := AcceptInclude(uri);
			if e <> '' then
				if TransferFile(Res, e) then
					result := pt_final
				else
			else
				res.Status := 404;
		end;
	end;
end;

end.
