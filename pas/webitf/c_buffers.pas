unit c_buffers;
interface

type
	PCacheBuffer = Pointer;//^TCacheBuffer;
	TBufProcessor= function (Buffer: PCacheBuffer): Boolean;


function _cb_init(var chainhead: PCacheBuffer; Output: Pointer): PCacheBuffer;
function _cb_new(var c: PCacheBuffer; D: Cardinal): PCacheBuffer;
procedure _cb_append(c: PCacheBuffer; S: AnsiString);
procedure _cb_outtemlate(c: PCacheBuffer; tpl: AnsiString);
procedure _cb_end(var c: PCacheBuffer);
function _cb_add_onapp(c: PCacheBuffer; p: TBufProcessor): TBufProcessor;
function _cb_add_onfin(c: PCacheBuffer; p: TBufProcessor): TBufProcessor;
function _cb_clear(c: PCacheBuffer): AnsiString;
function _cb_data(c: PCacheBuffer): Cardinal;

implementation
uses
	c_http,
	functions, strings, c_httpheaders, winsock1;

type
	PTCacheBuffer=^TCacheBuffer;
	TCacheBuffer = record
		Prev       : PCacheBuffer;
		Buffer     : AnsiString;
		_appp,_finp: TBufProcessor;
		Data       : Cardinal;
	end;

function _cb_add_onapp(c: PCacheBuffer; p: TBufProcessor): TBufProcessor;
begin
	result := PTCacheBuffer(c)._appp;
	PTCacheBuffer(c)._appp := p;
end;

function _cb_add_onfin(c: PCacheBuffer; p: TBufProcessor): TBufProcessor;
begin
	result := PTCacheBuffer(c)._finp;
	PTCacheBuffer(c)._finp := p;
end;

procedure _cb_append(c: PCacheBuffer; S: AnsiString);
begin
	PTCacheBuffer(c).Buffer := PTCacheBuffer(c).Buffer + S;
	if Assigned(PTCacheBuffer(c)._appp) then
		PTCacheBuffer(c)._appp(c);
end;

procedure _cb_outtemlate(c: PCacheBuffer; tpl: AnsiString);
var
	s: AnsiString;
begin
	tpl := AcceptInclude(tpl + '.tpl');
	if tpl <> '' then
		if ProcessTemplate(tpl, s) then begin
			_cb_append(c, S);
			exit;
		end;

	raise Exception.Create('<div id="message" class="error"><span><span>Template "%s" not found!</span></span></div>', [tpl])
end;

procedure _cb_flush(c: PCacheBuffer);
begin
	if Assigned(PTCacheBuffer(c)._finp) then
		if not PTCacheBuffer(c)._finp(c) then exit;

	if PTCacheBuffer(c).Buffer <> '' then begin
		if PTCacheBuffer(c).Prev <> nil then
			_cb_append(PTCacheBuffer(c).Prev, PTCacheBuffer(c).Buffer);
		PTCacheBuffer(c).Buffer := '';
	end;
end;

function _cbp_send(c: PCacheBuffer): Boolean;
var
	l: Integer;
	proc: PReqProcessor;
begin
	proc := PReqProcessor(PTCacheBuffer(c).Data);
	if proc.Status <> 200 then begin
		proc.Contents := UTF8Encode(PTCacheBuffer(c).Buffer);
		result := true;
		exit;
	end;

	if Assigned(proc.Formatter) then
		PTCacheBuffer(c).Buffer := proc.Formatter(PTCacheBuffer(c).Buffer, proc.FmtData);

	PTCacheBuffer(c).Buffer := UTF8Encode(PTCacheBuffer(c).Buffer);
	l := Length(PTCacheBuffer(c).Buffer);
	proc.ResHeaders.Add(HTTPHDR_CONTENT_LEN, its(l));
	proc.SendResponse;
	result := (l <= 0) or (send(proc.Socket, PTCacheBuffer(c).Buffer[1], l, 0) = l);
end;

function _cbp_flush(c: PCacheBuffer): Boolean;
begin
	result := PTCacheBuffer(c).Prev <> nil;
	if result then
		_cb_append(PTCacheBuffer(c).Prev, PTCacheBuffer(c).Buffer);

	PTCacheBuffer(c).Buffer := '';
end;

function _cb_new(var c: PCacheBuffer; D: Cardinal): PCacheBuffer;
begin
	new(PTCacheBuffer(result));
	FillChar(result^, SizeOf(TCacheBuffer), 0);
	PTCacheBuffer(result).Prev := c;
	PTCacheBuffer(result).Data := D;
	PTCacheBuffer(result)._finp := _cbp_flush;
	c := result;
end;

function _cb_init(var chainhead: PCacheBuffer; Output: Pointer): PCacheBuffer;
begin
	result := _cb_new(chainhead, Cardinal(Output));
	_cb_add_onfin(result, _cbp_send);
end;

procedure _cb_end(var c: PCacheBuffer);
var
	t: PCacheBuffer;
begin
	_cb_flush(c);
	t := c;
	c := PTCacheBuffer(c).Prev;
	Dispose(PTCacheBuffer(t));
end;

function _cb_clear(c: PCacheBuffer): AnsiString;
begin
	result := PTCacheBuffer(c).Buffer;
	PTCacheBuffer(c).Buffer := '';
end;

function _cb_data(c: PCacheBuffer): Cardinal;
begin
	result := PTCacheBuffer(c).Data;
end;

end.
