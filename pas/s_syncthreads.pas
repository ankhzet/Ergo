unit s_syncthreads;
interface

type
	PTask       =^TTask;
	TTask       = record
		Next      : PTask;
	end;

	TSyncThread = class;
	TWorker     = class
	private
		eReady    : THandle;
		eLazy     : THandle;
		fPrev     : TWorker;
		fNext     : TWorker;
		fRunning  : Boolean;
		fStarted  : Boolean;
		fHandle   : THandle;
		fID       : Cardinal;
		fParent   : TSyncThread;
		fProcess  : Boolean;
		property    Prev: TWorker read fPrev;
		property    Next: TWorker read fNext;
		procedure   DoServe; virtual;
		procedure   DoTask(Task: PTask);
		procedure   ReSchedule;
	protected
		fTask     : PTask;
	public
		constructor Create; virtual;
		procedure   AfterConstruction; override;
		destructor  Destroy; override;
		function    WaitFor: LongWord;

		procedure   Start; virtual;
		procedure   Stop; virtual;
		procedure   Execute; virtual;
		procedure   Serve; virtual;
		function    Task: PTask;

		property    Handle: THandle read fHandle;
		property    ThrdID: Cardinal read fID;
		property    Started: Boolean read fStarted;
		property    Running: Boolean read fRunning;
		property    Process: Boolean read fProcess write fProcess;
	end;
	TWClass     = class of TWorker;

	TSyncThread = class(TWorker)
	private
		eLock     : THandle;
		eSchedule : THandle;
		Chain     : TWorker;
		eWorkers  : array [Byte] of TWorker;
		eReadies  : array [Byte] of THandle;
		fMax      : Integer;
		fAvail    : Integer;
		procedure   setMax(const Value: Integer);
		function    getWorker(Index: Integer): TWorker;
	protected
		fQueue    : Pointer;
		NeedSort  : Boolean;
		function    Worker: TWClass; virtual;
		procedure   SortQueue; virtual;
		procedure   Lock;
		procedure   Unlock;
		function    Insert: TWorker;
		procedure   Remove(Worker: TWorker);
		procedure   RebuildEvts;
		property    Queue: Pointer read fQueue;
		function    WaitScheduler(WaitSlices: Integer = 10): Boolean;
		procedure   ScheduleReady;
	public
		constructor Create; override;
		procedure   Execute; override;
		procedure   Stop; override;
		procedure   Schedule(Task: Pointer); overload;
		property    Max: Integer read fMax write setMax;
		property    Avail: Integer read fAvail;
		property    W[Index: Integer]: TWorker read getWorker; default;
	end;

implementation
uses
	WinApi;

function WorkerProc(Worker: TWorker): Integer;
begin
	result := 0;
	try
		try
			Worker.Execute;
		except
		end;
	finally
		Worker.Free;
		EndThread(result);
	end;
end;

{ TWorker }

procedure TWorker.AfterConstruction;
begin
	ResumeThread(fHandle);
end;

constructor TWorker.Create;
begin
	fStarted := false;
	eReady   := CreateEvent(nil, false, false, nil);
	eLazy    := CreateEvent(nil, false, false, nil);
	fHandle  := BeginThread(nil, 0, @WorkerProc, Pointer(Self), CREATE_SUSPENDED, fID);
end;

destructor TWorker.Destroy;
begin
	if fParent <> nil then fParent.Remove(Self);
	inherited;
end;

procedure TWorker.DoTask(Task: PTask);
begin
	fTask := Task;
	SetEvent(eReady);
end;

function TWorker.WaitFor: LongWord;
begin
	Stop;
	if GetCurrentThreadId <> ThrdID then
		result := WaitForSingleObject(fHandle, INFINITE)
	else
		result := 0;
end;

procedure TWorker.Execute;
begin
	fRunning := true;
	while not Started do
		if not Running then exit else sleep(1);

	repeat
		SetEvent(eLazy);
		while WaitForSingleObject(eReady, 10) <> WAIT_OBJECT_0 do
			if not Running then exit;

		DoServe;
		ReSchedule;
	until not Running;
end;

procedure TWorker.ReSchedule;
begin
	if Task = nil then exit;
	fParent.Schedule(Task);
	fTask := nil;
end;

procedure TWorker.DoServe;
begin
	try
		Serve;
		if fTask <> nil then begin
			Dispose(fTask);
			fTask := nil;
		end;
	except
	end;
end;

procedure TWorker.Serve;
begin

end;

procedure TWorker.Start;
begin
	fStarted := true;
end;

procedure TWorker.Stop;
begin
	fRunning := false;
end;

function TWorker.Task: PTask;
begin
	result := fTask;
end;

{ TSyncThread }

constructor TSyncThread.Create;
begin
	inherited;
	Chain    := nil;
	eLock    := CreateEvent(nil, false, True, nil);
	eSchedule:= CreateEvent(nil, false, false, nil);
end;

procedure TSyncThread.Execute;
var
	l: Cardinal;
	q: PTask;
begin
	fRunning := true;
	ScheduleReady;
	while not Started do
		if not Running then exit else sleep(1);

	repeat
		if not WaitScheduler then break;

		if (Queue <> nil) and Process and (Avail > 0) then begin
			Lock;
			try
				l := WaitForMultipleObjects(Avail, @eReadies[0], false, 0);
				if l < Avail then begin
					if NeedSort then SortQueue;
					q := fQueue;
					fQueue := q.Next;
					eWorkers[l].DoTask(q);
				end;
			finally
				Unlock;
			end;
		end;
		sleep(1);
		ScheduleReady;
	until not Running;
end;

function TSyncThread.getWorker(Index: Integer): TWorker;
begin
	result := eWorkers[Index];
end;

procedure TSyncThread.RebuildEvts;
var
	w: TWorker;
	i: Integer;
begin
	i := 0;
	w := Chain;
	while w <> nil do begin
		eWorkers[i] := w;
		eReadies[i] := w.eLazy;
		w := w.Next;
		inc(i);
	end;
	fAvail := i;
end;

procedure TSyncThread.Schedule(Task: Pointer);
begin
	if not WaitScheduler then exit;

	PTask(Task).Next := fQueue;
	fQueue    := Task;
	NeedSort  := true;
	ScheduleReady;
end;

procedure TSyncThread.ScheduleReady;
begin
	SetEvent(eSchedule);
end;

function TSyncThread.Insert: TWorker;
begin
	Lock;
	try
		result := Worker.Create;
		result.fParent := Self;
		result.fPrev := nil;
		result.fNext := Chain;
		if Chain <> nil then
			Chain.fPrev := result;
		Chain := result;
		RebuildEvts;
		result.Start;
	finally
		Unlock;
	end;
end;

procedure TSyncThread.Remove(Worker: TWorker);
begin
	Lock;
	try
		if Worker.Prev <> nil then Worker.Prev.fNext := Worker.Next;
		if Worker.Next <> nil then Worker.Next.fPrev := Worker.Prev;
		if Chain = Worker then Chain := Worker.Next;
		Worker.Stop;
		RebuildEvts;
	finally
		Unlock;
	end;
end;

procedure TSyncThread.setMax(const Value: Integer);
begin
	if fMax <> Value then begin
		fMax := Value;
		while fAvail > Value do Remove(Chain);
		while fAvail < Value do Insert;
	end;
end;

procedure TSyncThread.SortQueue;
begin

end;

procedure TSyncThread.Stop;
begin
	Max := 0;
	inherited;
end;

procedure TSyncThread.Lock;
begin
	while WaitForSingleObject(eLock, 10) <> WAIT_OBJECT_0 do
		if not Running then exit;
end;

procedure TSyncThread.Unlock;
begin
	SetEvent(eLock);
end;

function TSyncThread.WaitScheduler(WaitSlices: Integer): Boolean;
begin
	while WaitForSingleObject(eSchedule, WaitSlices) <> WAIT_OBJECT_0 do
		if not Running then exit(false);
	result := true;
end;

function TSyncThread.Worker: TWClass;
begin
	result := TWorker;
end;

end.
