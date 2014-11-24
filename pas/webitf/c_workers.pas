unit c_workers;
interface

type
	PWorkerData   =^TWorkerData;
	TWorkerData   = object
		Terminated  : Boolean;
		ThrdHandle  : THandle;
		ThrdID      : Cardinal;
		procedure     Terminate;
	end;

	TThread       = function(Data: PWorkerData): Boolean;
	PThreadChunk  =^TThreadChunk;
	TThreadChunk  = record Data: Pointer; Thread: TThread; end;

procedure BeginWorkerThread(Thread: TThread; Data: PWorkerData);

implementation
uses
	WinAPI;

procedure t_ThreadWorker(Data: Pointer); stdcall;
begin
	try
		try
			PThreadChunk(Data).Thread(PPointer(Data)^);
		except
		end;
	finally
		Dispose(PThreadChunk(Data));
		EndThread(0);
	end;
end;

procedure BeginWorkerThread(Thread: TThread; Data: PWorkerData);
var
	Chunk: PThreadChunk;
begin
	new(Chunk);
	Chunk.Data   := Data;
	Chunk.Thread := Thread;
	Data.Terminated := false;
	Data.ThrdHandle := CreateThread(nil, 60 * 1024, @t_ThreadWorker, Chunk, 0, Data.ThrdID);
end;

{ TWorkerData }

procedure TWorkerData.Terminate;
begin
	Terminated := true;
	if ThrdHandle <> 0 then begin
		WaitForSingleObject(ThrdHandle, INFINITE);
		CloseHandle(ThrdHandle);
		ThrdHandle := 0;
	end;
end;

end.
