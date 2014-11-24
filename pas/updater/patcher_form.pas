unit patcher_form;

interface

uses
	Windows, Classes, Controls, StdCtrls, Forms
	, core_patcher;

type
	TMainViewer = class(TForm)
		bMakePatch: TButton;
		eVHi: TEdit;
		eVLow: TEdit;
		Label1: TLabel;
		bWriteVersion: TButton;
		lbLog: TListBox;
    mDirs: TMemo;
    mFiles: TMemo;
		procedure bMakePatchClick(Sender: TObject);
		procedure bWriteVersionClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
	private
		fVersion: TAppVersion;
		function LogHandler(LogStr: PAnsiChar): Boolean;
		function GetCurrentVersion(out v: TAppVersion): Boolean;
	public
		procedure Log(Msg: AnsiString; Params: array of const);
		property CurrentVersion: TAppVersion read fVersion;
	end;

var
	MainViewer: TMainViewer;

implementation
uses
	functions, strings, file_sys, streams, packages, EMU_Types;

{$R *.dfm}

const
	Sizes: array [0..5] of AnsiString = (
		'Байт', 'КБ', 'МБ', 'ГБ', 'ТБ', 'ЕБ'
	);
procedure TMainViewer.bMakePatchClick(Sender: TObject);
var
	p: TPackage;
	t1, t2: AnsiString;
	n: Cardinal;
	files: TStrings;
	i: Integer;

	procedure ProcessFile(fil: AnsiString);
	var
		r: TStrings;
		n: AnsiString;
		f, t: TFolder;
		e: TFile absolute f;
		u: TFile absolute t;
		i: Integer;
		s: TStream;
	begin
		f := TFolder(p[p.IndexOf(0)]);
		r := Explode('\', fil);
		repeat
			n := array_shift(r);
			i := f.IndexOf(n);
			if i >= 0 then
				f := TFolder(p[p.IndexOf(f[i])])
			else
				if Length(r) > 0 then begin // this is folder
					t := TFolder(p[p.NewFile(TFolder)]);
					with t do begin
						Name := n;
						f.AddChild(ID);
						f := t;
					end
				end else begin // this is file!
					u := TFile(p[p.NewFile(TFile)]);
					with u do begin
						Name := n;
						s := TFileStream.Create(CoreDir + fil, fmOpen);
						try
							Size := s.Size;
							Data := ReallocMemory(Data, Size);
							DataAquired := true;
							if Size <> s.Read(Data, Size) then
								raise Exception.Create('Ошибка чтения [%s]!', [fil]);

							array_push(files, 'file' + its(Length(files) + 1) + ' = ''' + fil + '''');
							Log(' -- добавлено [%s]...', [fil]);
						finally
							s.Free;
						end;
						f.AddChild(ID);
					end;
					exit;
				end;
		until Length(r) <= 0;
	end;

	procedure ProcessDir(dir: AnsiString);
	var
		sr: TSearchRec;
	begin
		if FindFirst(dir + '\*', faAnyFile, SR) = 0 then
			repeat
				if (SR.Name = '.') or (SR.Name = '..') then continue;
				if SR.Attr and faDirectory <> 0 then
					ProcessDir(dir + '\' + SR.Name)
				else
					ProcessFile(dir + '\' + SR.Name);
			until FindNext(SR) <> 0;
	end;
begin
	try
		Log('Сборка патча для версии v%d\.%d', [CurrentVersion.VHi, CurrentVersion.VLow]);

		t1 := Format('%s%s', [CoreDir, 'updater.stub']);
		t2 := Format('%secvPatch[to v%d\.%d].exe', [CoreDir, CurrentVersion.VHi, CurrentVersion.VLow]);
		CopyFile(PChar(t1), PChar(t2), false);
		p := TPackage.Create(
			t2
		, BaseAppExeName
		, fmOpenReadWrite
		, false
		);
		try
			p.BaseOffset := p.Size;
			p.Position := 0;
			p.Write(@CurrentVersion, SizeOf(TVersion));
			p.BaseOffset := p.Size;
			p.Position := 0;
			with TFolder(p[p.NewFile(TFolder)]) do begin
				Name := 'patch';
				ID := 0;
			end;

			with mDirs.Lines do
				for i := 0 to Count - 1 do
						ProcessDir(Strings[i]);
			with mFiles.Lines do
				for i := 0 to Count - 1 do
						ProcessFile(Strings[i]);

			with p[p.NewFile(TFile)] do begin
				Name := PATCH_DESCRIPTOR;
				TFolder(p[p.IndexOf(0)]).AddChild(ID);
				t1 := 'patch {add {' + join(';', files) + ';}; remove {};}';
				SetData(PChar(t1), Length(t1));
			end;


			Log('Сохранение файла: %b', [p.Save]);
			Log(' -- результирующий размер файла: %s', [ChunkSizeStr(p.Position + p.BaseOffset, Sizes)]);

			n := p.Position;
			p.Write(@n, SizeOf(n));
		finally
			p.Free;
		end;
	except

	end;
end;

procedure TMainViewer.bWriteVersionClick(Sender: TObject);
var
	s: TStream;
begin
	fVersion.VLow := sti(eVLow.Text);
	fVersion.VHi  := STI(eVHi.Text);

	try
		s := TFileStream.Create(BaseAppName, fmOpenReadWrite);
		try
			s.Position := s.Size;
			s.Write(@fVersion, SizeOf(fVersion));
			Log('Сигнанура версии (%d\.%d) приложения записана.', [CurrentVersion.VHi, CurrentVersion.VLow]);
		finally

		end;
	except

	end;
end;

function TMainViewer.GetCurrentVersion(out v: TAppVersion): Boolean;
var
	s: TStream;
begin
	result := false;
	try
		s := TFileStream.Create(BaseAppName, fmOpen);
		try
			s.Position := s.Size - SizeOf(v);
			if s.Read(@v, SizeOf(v)) <> SizeOf(v) then
				raise Exception.Create('Нет доступа к исполняемому файлу приложения!');
		finally
			s.Free;
		end;
		result := true;
	except
		on E: TObject do
			Log('Ошибка:\n%s', [Exception(e).Message]);
	end;
end;

procedure TMainViewer.Log(Msg: AnsiString; Params: array of const);
begin
	lbLog.Items.Add(Format(Msg, Params));
	lbLog.ItemIndex := lbLog.Count - 1;
end;

procedure TMainViewer.FormCreate(Sender: TObject);
begin
	SetLogHandler(LogHandler);
	GetCurrentVersion(fVersion);
	log('Текущая версия приложения: %d\.%d', [CurrentVersion.VHi, CurrentVersion.VLow]);
end;

function TMainViewer.LogHandler(LogStr: PAnsiChar): Boolean;
begin
	Log(LogStr, []);
	result := true;
end;

end.
