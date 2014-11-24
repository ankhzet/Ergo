unit c_interactive_lists;
interface
uses
	WinAPI;

type
	PILItem     =^TILItem;
	PIList      =^TIList;
	TForEachCallBack = procedure (Item: PILItem; Data: Pointer; var Continue: Boolean);
	TItemCallBack = procedure (Item: PILItem);
	TILItem     = record
		Prev, Next: PILItem;
		Data      : Cardinal;
	end;
	TIList      = record
		Head      : PILItem;
		Semaphore : THandle;
		Init      : TForEachCallBack;
		Release   : TForEachCallBack;
	end;

function _il_new(Init, Release: TForEachCallBack): PIList;
function _il_armor(l: PIList; ReadOnly: Boolean = true): Boolean;
function _il_release(l: PIList): Boolean;
function _il_append(l: PIList; Data: Cardinal): PILItem;
function _il_remove(l: PIList; Item: PILItem; Armored: Boolean = false): Boolean;
function _il_iterate(l: PIList; CallBack: TForEachCallBack; Data: Pointer; ReadOnly: Boolean = true): PILItem;
function _il_free(var l: PIList): Boolean;

implementation

function _il_new(Init, Release: TForEachCallBack): PIList;
begin
	new(result);
	result.Head := nil;
	result.Semaphore := CreateEvent(nil, false, false, nil);
	result.Init := Init;
	result.Release := Release;
end;

function _il_armor(l: PIList; ReadOnly: Boolean = true): Boolean;
var
	Status: Cardinal;
begin
	repeat
		Status := WaitForSingleObject(l.Semaphore, 500);
	until Status <> WAIT_TIMEOUT;
	result := Status = WAIT_OBJECT_0;
end;

function _il_release(l: PIList): Boolean;
begin
	result := SetEvent(l.Semaphore);
end;

function _il_append(l: PIList; Data: Cardinal): PILItem;
var
	r: Boolean;
begin
	result := nil;
	if not _il_armor(l, false) then exit;

	try
		new(result);
		result.Prev := l.Head;
		result.Next := nil;
		result.Data := Data;
		r := true;
		l.Init(result, l, r);
		if r then begin
			if result.Prev <> nil then result.Prev.Next := result;
			l.Head := result;
		end else
			Dispose(result);
	finally
		_il_release(l);
	end;
end;

function _il_remove(l: PIList; Item: PILItem; Armored: Boolean): Boolean;
var
	p, n: PILItem;
	r   : Boolean;
begin
	result := Armored or _il_armor(l, false);
	try
		if not result then exit;
		r := true;
		l.Release(Item, l, r);
		if r then begin
			p := Item.Prev;
			n := Item.Next;
			if p <> nil then p.Next := n;
			if n <> nil then n.Prev := p else l.Head := p;
			Dispose(Item);
		end;
	finally
		if not Armored then _il_release(l);
	end;
end;

function _il_iterate(l: PIList; CallBack: TForEachCallBack; Data: Pointer; ReadOnly: Boolean = true): PILItem;
var
	i  : PILItem;
	cnt: Boolean;
begin
	result := l.Head;
	if result = nil then exit;
	if not _il_armor(l, ReadOnly) then exit;

	try
		cnt := true;
		while result <> nil do begin
			i := result;
			result := result.Prev;
			CallBack(i, Data, cnt);
			if not cnt then break;
		end;
	finally
		_il_release(l);
	end;
end;

function _il_free(var l: PIList): Boolean;
var
	i, t: PILItem;
begin
	result := _il_armor(l, false);
	if not result then exit;
	try
		while (l.Head) <> nil do begin
			result := _il_remove(l, l.Head, true);
			if not result then break;
		end;
	finally
		if result then begin
			CloseHandle(l.Semaphore);
			Dispose(l);
			l := nil;
		end;
	end;
end;

end.
