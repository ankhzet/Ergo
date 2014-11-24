unit ComTestNs;

interface

uses
  SysUtils,	// For Beep() function
  Windows,
  ComObj,		// For TComObject
  UrlMon,
  UrlMonNs, // Extensions to Delphi UrlMon.pas
  ActiveX, 	// For IClassFactory
  Classes;	// for TMemoryStream

const
  ClSID_TComQueryNamespace: TGUID = '{28369340-10C6-11D2-BDD7-4CF90AC10627}';

type
  TComQueryNamespace = class(TComObject, IInternetProtocol)
  	protected
      FProtSink : IInternetProtocolSink;
      FURL : string;
      FMemStrm : TMemoryStream;
      function ParseURL(URL : string) : Boolean;
      procedure AddTrace(ATrace : string);
	  public
    	procedure Initialize; override;
      destructor Destroy; override;
     	// IInternetProtocolRoot methods
      function Start(
          szUrl: PWChar;														// [in] LPCWSTR szUrl
          const pOIProtSink: IInternetProtocolSink;	// [in] IInternetProtocolSink __RPC_FAR *pOIProtSink,
          const pOIBindInfo: IInternetBindInfo; 		// [in] IInternetBindInfo __RPC_FAR *pOIBindInfo
          const grfPI: DWORD;												// [in] DWORD grfPI
          const dwReserved: DWORD										// [in] DWORD dwReserved
        ): HResult; stdcall;
      function Continue(
          var pProtocolData: TProtocolData	// [in] PROTOCOLDATA __RPC_FAR *pProtocolData
        ): HResult; stdcall;
      function Abort(
          const hrReason: HResult;	// [in] HRESULT hrReason
          const dwOptions: DWORD		// [in] DWORD dwOptions
        ): HResult; stdcall;
      function Terminate(
          const dwOptions: DWORD		// [in] DWORD dwOptions
        ) : HResult; stdcall;
      function Suspend: HResult; stdcall;
      function Resume: HResult; stdcall;

      // IInternetProtocol methods
      function Read(
          pv : Pointer;							// [in/out] void __RPC_FAR *pv
          const cb: ULONG;		// [in] ULONG cb
          out pcbRead: ULONG	// [out] ULONG __RPC_FAR *pcbRead
        ): HResult; stdcall;
      function Seek(
          dlibMove: TLargeInteger;						// [in] LARGE_INTEGER dlibMove
          const dwOrigin: DWORD;							// [in] DWORD dwOrigin
          out plibNewPosition: TLargeInteger	// [out] ULARGE_INTEGER __RPC_FAR *plibNewPosition
        ): HResult; stdcall;
      function LockRequest(
          const dwOptions: DWORD		// [in] DWORD dwOptions
        ): HResult; stdcall;
      function UnlockRequest: HResult; stdcall;
	end;

implementation

uses
	NsFactory,
  ComServ, // For TComObjectFactory in initization section
  Math;

////////////////////////////////////////////////////////////////////////////////

procedure TComQueryNamespace.Initialize;
begin
	inherited;
  FMemStrm := TMemoryStream.Create;
end;

////////////////////////////////////////////////////////////////////////////////

destructor TComQueryNamespace.Destroy;
begin
  FMemStrm.Free;
	inherited;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Start(
    szUrl: PWChar;														// [in] LPCWSTR szUrl
    const pOIProtSink: IInternetProtocolSink;	// [in] IInternetProtocolSink __RPC_FAR *pOIProtSink,
    const pOIBindInfo: IInternetBindInfo; 		// [in] IInternetBindInfo __RPC_FAR *pOIBindInfo
    const grfPI: DWORD;												// [in] DWORD grfPI
    const dwReserved: DWORD										// [in] DWORD dwReserved
  ): HResult; stdcall;

var
  LBindInfo : TBindInfo;
  BINDF : DWORD;
  HTMLText : string;

	// generates a HTML paragraph
  function MakeParagraph(AParagraph : string) : string;
  begin
  	Result := '<p>' + AParagraph + '</p>';
  end;

  // generate a string of any data passed in the request
  // TODO - cope with other data types other than HGlobal
  function GetData : string;
  begin
    Result := '';
    if LBindInfo.stgmedData.tymed = TYMED_HGLOBAL then
    begin
    	if (LBindInfo.stgmedData.hGlobal <> 0) then
      begin
        Result := Copy(StrPas(PChar(LBindInfo.stgmedData.hGlobal)), 1, GlobalSize(LBindInfo.stgmedData.hGlobal));
      end;
    end;
  end;

  // returns the data type of the operation
  function GetDataType : string;
  begin
    case LBindInfo.stgmedData.tymed of
    	TYMED_NULL : Result := 'None';
    	TYMED_GDI : Result := 'GDI';
      TYMED_MFPICT : Result := 'Metafile picture';
      TYMED_ENHMF : Result := 'Enhanced metafile';
      TYMED_HGLOBAL : Result := 'Global memory';
      TYMED_FILE : Result := 'File';
      TYMED_ISTREAM : Result := 'IStream interface';
      TYMED_ISTORAGE : Result := 'IStorage interface';
    else
    	Result := 'Unknown';
    end;
  end;

  // generate a string to represent the type of this operation
  function GetOperation : string;
  begin
  	case LBindInfo.dwBindVerb of
    	BINDVERB_GET : Result := 'Get';
      BINDVERB_POST : Result := 'Post';
      BINDVERB_PUT : Result := 'Put';
      BINDVERB_CUSTOM : Result := LBindInfo.szCustomVerb;
    else
    	Result := 'Unknown';
    end;
  end;

begin
	AddTrace('IN IInternetProtocolRoot::Start - szURL = ' + szURL + ' grfPI = ' +
  	IntToStr(grfPI));

  FProtSink := pOIProtSink;

  ParseURL(szURL);

  // get the bind information
  LBindInfo.cbSize := SizeOf(LBindInfo);
  pOIBindInfo.GetBindInfo(BINDF, LBindInfo);

  // generate the HTML
  HTMLText := '<HTML>' + MakeParagraph(FURL) +
  MakeParagraph('Operation - ' + GetOperation) +
  MakeParagraph('Data type - ' + GetDataType) +
  MakeParagraph('Data - ' + GetData) + '</HTML>';

  FMemStrm.Clear;
  FMemStrm.WriteBuffer(Pointer(HTMLText)^, Length(HTMLText));
  FMemStrm.Position := 0;

  // report that all the data has been got
  AddTrace('IN IInternetProtocolSink::ReportData - ulProgress = ' + IntToStr(FMemStrm.Size));
  FProtSink.ReportData(BSCF_FIRSTDATANOTIFICATION or BSCF_LASTDATANOTIFICATION
  	or BSCF_DATAFULLYAVAILABLE, FMemStrm.Size, FMemStrm.Size);

  Result := S_OK;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Continue(
    var pProtocolData: TProtocolData	// [in] PROTOCOLDATA __RPC_FAR *pProtocolData
  ): HResult; stdcall;
begin
	AddTrace('IN IInternetProtocolRoot::Continue');
	Result := E_FAIL;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Abort(
    const hrReason: HResult;	// [in] HRESULT hrReason
    const dwOptions: DWORD		// [in] DWORD dwOptions
  ): HResult; stdcall;
begin
	AddTrace('IN IInternetProtocolRoot::Abort');
	Result := S_OK;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Terminate(
    const dwOptions: DWORD		// [in] DWORD dwOptions
  ) : HResult; stdcall;
begin
  AddTrace('IN IInternetProtocolRoot::Terminate');
	Result := S_OK;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Suspend: HResult; stdcall;
begin
	AddTrace('IN IInternetProtocolRoot::Suspend');
	Result := E_NOTIMPL;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Resume: HResult; stdcall;
begin
	AddTrace('IN IInternetProtocolRoot::Resume');
	Result := E_NOTIMPL;
end;

////////////////////////////////////////////////////////////////////////////////
// this should return S_OK if there is still data to come and S_FALSE once the
// data has all been read

function TComQueryNamespace.Read(
    pv : Pointer;							// [in/out] void __RPC_FAR *pv
    const cb: ULONG;		// [in] ULONG cb
    out pcbRead: ULONG	// [out] ULONG __RPC_FAR *pcbRead
  ): HResult; stdcall;

begin
	AddTrace('IN IInternetProtocol::Read - cb = ' + IntToStr(cb));

  Result := S_OK;

  // calcualte the ammount of data to be read
	pcbRead := Min(FMemStrm.Size-FMemStrm.Position, cb);

  // read in the data
  if (FMemStrm.Position < FMemStrm.Size) then
    FMemStrm.ReadBuffer(pv^, pcbRead);

  // have we finished?
  if (FMemStrm.Position = FMemStrm.Size) then
  begin
    FProtSink.ReportResult(S_OK, 0, nil);
  	Result := S_FALSE;
  end;

  AddTrace('OUT Read - pcbRead = ' + IntToStr(pcbRead) + ' Result = ' +
  	IntToStr(Result) + ' FMemStrm.Position = ' + IntToStr(FMemStrm.Position));
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.Seek(
    dlibMove: TLargeInteger;						// [in] LARGE_INTEGER dlibMove
    const dwOrigin: DWORD;							// [in] DWORD dwOrigin
    out plibNewPosition: TLargeInteger	// [out] ULARGE_INTEGER __RPC_FAR *plibNewPosition
  ): HResult; stdcall;
begin
	AddTrace('IN IInternetProtocol::Seek');
	Result := E_NOTIMPL;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.LockRequest(
    const dwOptions: DWORD		// [in] DWORD dwOptions
  ): HResult; stdcall;
begin
	AddTrace('IN IInternetProtocol::LockRequest');
	Result := S_OK;
end;

////////////////////////////////////////////////////////////////////////////////

function TComQueryNamespace.UnlockRequest: HResult; stdcall;
begin
	AddTrace('IN IInternetProtocol::UnlockRequest');
	Result := S_OK;
end;

////////////////////////////////////////////////////////////////////////////////
// helper functions

function TComQueryNamespace.ParseURL(URL : string) : Boolean;
begin
	AddTrace('IN ParseURL');

  // dunnow how this could happen
  if (Pos(':', URL) = 0) then
  begin
  	Result := False;
    Exit;
  end;

  // strip off the ework:
  FURL := Copy(URL, Pos(':', URL)+1, Length(URL));
  Result := True;
end;

////////////////////////////////////////////////////////////////////////////////

procedure TComQueryNamespace.AddTrace(ATrace : string);
begin
	asm int 3 end;
  OutputDebugString(PChar(Atrace));
end;

////////////////////////////////////////////////////////////////////////////////

initialization
  TNsFactory.Create(ComServer, TComQueryNamespace, ClSID_TComQueryNamespace,
		'TestNamespace',													// Name
    'TestNamespaceHandler',		// Description
		ciMultiInstance).UpdateRegistry(true);

end.

