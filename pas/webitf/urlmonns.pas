unit UrlMonNs;

{	Updated 7/11/98

	Written by Mike Vance, Scoutship Technologies
		mvance@lightspeed.net
    http://userzweb.lightspeed.net/~friend/mike/delphi/

	Contains updated portions necessary for creating pluggable namespace handlers.

	This translation process has driven home to me the readability of
	Delphi syntax over C++.  The original C++ parameter definitions has been
  retained in comments for easy translation verification.

  Until my next project is released months from now I am going to be
  broke.  If this file has saved you some time then could you please send a
  few dollars (even one dollar is appreciated) to:
  	Mike Vance, 311 Jimmy Ct., Los Banos  CA  93635
}

interface

uses
  Windows, ActiveX, UrlMon;

const
	IID_IDataFilter: TGuid 						= '{69d14c80-c18e-11d0-a9ce-006097942311}';
  IID_IEncodingFilterFactory: TGuid	= '{70bdde00-c18e-11d0-a9ce-006097942311}';
  IID_IInternet: TGuid							= '{79eac9e0-baf9-11ce-8c82-00aa004ba90b}';
  IID_IInternetBindInfo: TGuid			= '{79eac9e1-baf9-11ce-8c82-00aa004ba90b}';
 	IID_IInternetProtocol: TGuid 			= '{79eac9e4-baf9-11ce-8c82-00aa004ba90b}';
  IID_IInternetProtocolInfo: TGuid	= '{79eac9ec-baf9-11ce-8c82-00aa004ba90b}';
 	IID_IInternetProtocolRoot: TGuid 	= '{79eac9e3-baf9-11ce-8c82-00aa004ba90b}';
 	IID_IInternetProtocolSink: TGuid 	= '{79eac9e5-baf9-11ce-8c82-00aa004ba90b}';
 	IID_IInternetSession: TGuid 			= '{79eac9e7-baf9-11ce-8c82-00aa004ba90b}';

	// OIBDG_FLAGS enumeration
	OIBDG_APARTMENTTHREADED	= $100; // One lousy value for the whole enumeration

  // PSUACTION Enumeration
  PSU_DEFAULT							= 1;
  PSU_SECURITY_URL_ONLY		= 2;

  // PI Flags Enumeration
  PI_PARSE_URL           = $1;
  PI_FILTER_MODE         = $2;
  PI_FORCE_ASYNC         = $4;
  PI_USE_WORKERTHREAD    = $8;
  PI_MIMEVERIFICATION    = $10;
  PI_CLSIDLOOKUP         = $20;
  PI_DATAPROGRESS        = $40;
  PI_SYNCHRONOUS         = $80;
  PI_APARTMENTTHREADED   = $100;
  PI_CLASSINSTALL        = $200;
  PD_FORCE_SWITCH        = $10000; // Yes, PD_ instead of PI_

  // Additions to INET_E_ constants
  INET_E_USE_DEFAULT_PROTOCOLHANDLER = $800C0011;
  INET_E_USE_DEFAULT_SETTING         = $800C0012;
  INET_E_DEFAULT_ACTION              = INET_E_USE_DEFAULT_PROTOCOLHANDLER;
  INET_E_QUERYOPTION_UNKNOWN         = $800C0013;
  INET_E_REDIRECTING                 = $800C0014;

  // Additions to BSCF enumeration
  BSCF_DATAFULLYAVAILABLE 					= $00000008;
  BSCF_AVAILABLEDATASIZEUNKNOWN			= $00000010;

  //Additions to BINDSTATUS enumeration
  BINDSTATUS_BEGINSYNCOPERATION 				= 15;
  BINDSTATUS_ENDSYNCOPERATION 					= 16;
  BINDSTATUS_BEGINUPLOADDATA 						= 17;
  BINDSTATUS_UPLOADINGDATA 							= 18;
  BINDSTATUS_ENDUPLOADDATA 							= 19;
  BINDSTATUS_PROTOCOLCLASSID	 					= 20;
  BINDSTATUS_ENCODING 									= 21;
  BINDSTATUS_VERIFIEDMIMETYPEAVAILABLE	= 22;
  BINDSTATUS_CLASSINSTALLLOCATION 			= 23;
  BINDSTATUS_DECODING 									= 24;
  BINDSTATUS_LOADINGMIMEHANDLER 				= 25;

	// BINDSTRING enumerations used by IInternetBindInfo
	BINDSTRING_HEADERS					= 1;
	BINDSTRING_ACCEPT_MIMES			= 2;
	BINDSTRING_EXTRA_URL				= 3;
	BINDSTRING_LANGUAGE					= 4;
	BINDSTRING_USERNAME					= 5;
	BINDSTRING_PASSWORD					= 6;
	BINDSTRING_UA_PIXELS				= 7;
	BINDSTRING_UA_COLOR					= 8;
	BINDSTRING_OS								= 9;
	BINDSTRING_USER_AGENT				= 10;
	BINDSTRING_ACCEPT_ENCODINGS	= 11;
	BINDSTRING_POST_COOKIE			= 12;
	BINDSTRING_POST_DATA_MIME		= 13;
	BINDSTRING_URL							= 14;

  // PARSEACTION enumeration
  PARSE_CANONICALIZE		= $1;
  PARSE_FRIENDLY				= $2;
  PARSE_SECURITY_URL		= $3;
  PARSE_ROOTDOCUMENT		= $4;
  PARSE_DOCUMENT				= $5;
  PARSE_ANCHOR					= $6;
  PARSE_ENCODE					= $7;
  PARSE_DECODE					= $8;
  PARSE_PATH_FROM_URL		=	$9;
  PARSE_URL_FROM_PATH		=	$10;
  PARSE_MIME						= $11;
  PARSE_SERVER					= $12;
  PARSE_SCHEMA					= $13;
  PARSE_SITE						= $14;
  PARSE_DOMAIN					= $15;
  PARSE_LOCATION				= $16;
  PARSE_SECURITY_DOMAIN	= $17;

  // QUERYOPTION Enumeration
  QUERY_EXPIRATION_DATE			= $1;
  QUERY_TIME_OF_LAST_CHANGE	= $2;
  QUERY_CONTENT_ENCODING		= $3;
  QUERY_CONTENT_TYPE				= $4;
  QUERY_REFRESH							= $5;
  QUERY_RECOMBINE						= $6;
  QUERY_CAN_NAVIGATE				= $7;
  QUERY_USES_NETWORK				= $8;
  QUERY_IS_CACHED						= $9;
  QUERY_IS_INSTALLEDENTRY		= $10;
  QUERY_IS_CACHED_OR_MAPPED	= $11;
  QUERY_USES_CACHE					= $12;

type
	PPWChar = ^PWChar; // For translating purposes.  Pointer to pointer of string

  PProtocolData = ^TProtocolData;
  TProtocolData = packed record
    grfFlags  : DWORD  ;
    dwState   : DWORD  ;
    pData     : Pointer ;
    cbData    : ULONG  ;
  end;

  // Forward declarations
  IInternetProtocol = interface;
  IInternetProtocolSink = interface;

  // PROTOCOLFILTERDATA structure
  PProtocolFilterData = ^TProtocolFilterData;
  TProtocolFilterData = packed record
    cbSize: DWORD;
		pProtocolSink: IInternetProtocolSink;
		pProtocol: IInternetProtocol;
		pUnk: IUnknown;
    dwFilterFlags: DWORD;
  end;

  // Updated TBindInfo structure
  PBindInfo = ^TBindInfo;
  TBindInfo = packed record
    cbSize: ULONG;
    szExtraInfo: PWChar;
    stgmedData: TStgMedium;
    grfBindInfoF: DWORD;
    dwBindVerb: DWORD;
    szCustomVerb: PWChar;
    cbstgmedData: DWORD;
		// Beyond this point are the added variables
    dwOptions: DWORD;
    dwOptionsFlags: DWORD;
    dwCodePage: DWORD;
    securityAttributes: TSecurityAttributes;
    iid: TIID;	// IID iid.  Alex verified change of iid to TIID
    pUnk: IUnknown;
    dwReserved: DWORD;
  end;

	// DATAINFO struct used by IEncodingFilterFactory interface methods
 	TDataInfo = packed record
    ulTotalSize: ULONG;
    ulavrPacketSize: ULONG;
    ulConnectSpeed: ULONG;
    ulProcessorSpeed: ULONG;
  end;


	// IInternet is an empty interface
  IInternet = interface(IUnknown)
  end;

  IInternetBindInfo = interface(IUnknown)
    ['{79eac9e1-baf9-11ce-8c82-00aa004ba90b}']
    function GetBindInfo(
    		var grfBINDF: DWORD; 			// [out] DWORD __RPC_FAR *grfBINDF
        var pbindinfo: TBindInfo  // [in/out] BINDINFO __RPC_FAR *pbindinfo
    	): HResult; stdcall;

    function GetBindString(
    		const ulStringType: ULONG;	// [in] ULONG ulStringType,
        var ppwzStr: PWChar;				// [in/out] LPOLESTR __RPC_FAR *ppwzStr
        const cEl: ULONG;						// [in] ULONG cEl
        var pcElFetched: ULONG			// [in/out] ULONG __RPC_FAR *pcElFetched
      ): HResult; stdcall;
  end;

  IInternetProtocolRoot = interface(IUnknown)
    ['{79eac9e3-baf9-11ce-8c82-00aa004ba90b}']
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
  end;

  IInternetProtocol = interface(IInternetProtocolRoot)
    ['{79eac9e4-baf9-11ce-8c82-00aa004ba90b}']
    function Read(
    		pv : Pointer;					// [in/out] void __RPC_FAR *pv
        const cb: ULONG;		// [in] ULONG cb
        out pcbRead : ULONG	// [out] ULONG __RPC_FAR *pcbRead
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

  IInternetProtocolInfo = interface(IUnknown)
    ['{79eac9ec-baf9-11ce-8c82-00aa004ba90b}']
    function ParseUrl(
    		pwzUrl: PWChar;							// [in] LPCWSTR pwzUrl
        const ParseAction: Integer;	// [in] PARSEACTION ParseAction
    		const dwParseFlags: DWORD; 	// [in] DWORD dwParseFlags
        out pwzResult: PWChar;			// [out] LPWSTR pwzResult
        const cchResult: DWORD;		 	// [in] DWORD cchResult
        out pcchResult: DWORD;			// [out] DWORD __RPC_FAR *pcchResult
        const dwReserved: DWORD		 	// [in] DWORD dwReserved
      ): HResult; stdcall;
    function CombineUrl(
    		pwzBaseUrl: PWChar;						// [in] LPCWSTR pwzBaseUrl
        pwzRelativeUrl: PWChar;				// [in] LPCWSTR pwzRelativeUrl
    		const dwCombineFlags: DWORD;	// [in] DWORD dwCombineFlags
        out pwzResult: PWChar;				// [out] LPWSTR pwzResult
        const cchResult: DWORD;				// [in] DWORD cchResult
        out pcchResult: DWORD;				// [out] DWORD __RPC_FAR *pcchResult
        const dwReserved: DWORD				// [in] DWORD dwReserved
      ): HResult; stdcall;
    function CompareUrl(
    		pwzUrl1: PWChar;							// [in] LPCWSTR pwzUrl1
        pwzUrl2: PWChar;							// [in] LPCWSTR pwzUrl2
        const dwCompareFlags: DWORD		// [in] DWORD dwCompareFlags
      ): HResult; stdcall;
    function QueryInfo(
    		pwzUrl: PWChar;							// [in] LPCWSTR pwzUrl
        const QueryOption: Integer;	// [in] QUERYOPTION OueryOption
    		const dwQueryFlags: DWORD;	// [in] DWORD dwQueryFlags
        var pBuffer;								// [in/out] LPVOID pBuffer
        const chBuffer: DWORD; 			// [in] DWORD cbBuffer
        var pcbBuf: DWORD;					// [in/out] DWORD __RPC_FAR *pcbBuf
        const dwReserved: DWORD			// [in] DWORD dwReserved
      ): HResult; stdcall;
  end;

  IInternetProtocolSink = interface(IUnknown)
    ['{79eac9e5-baf9-11ce-8c82-00aa004ba90b}']
    function Switch(
    		var pProtocolData: TProtocolData	// [in] PROTOCOLDATA __RPC_FAR *pProtocolData
      ): HResult; stdcall;
    function ReportProgress(
    		const ulStatusCode: ULONG;	// [in] ULONG ulStatusCode
        szStatusText: PWChar				// [in] LPCWSTR szStatusText
      ): HResult; stdcall;
    function ReportData(
    		const grfBSCF: DWORD;				// [in] DWORD grfBSCF
        const ulProgress: ULONG;		// [in] ULONG ulProgress
        const ulProgressMax: ULONG	// [in] ULONG ulProgressMax
      ): HResult; stdcall;
    function ReportResult(
    		const hrResult: HResult;	// [in] HRESULT hrResult
        const dwError: DWORD;			// [in] DWORD dwError
    		szResult: PWChar					// [in] LPCWSTR szResult
      ): HResult; stdcall;
  end;

  // Cross-checked with Alex but have questions on some parameters
  IInternetSession = interface(IUnknown)
    ['{79eac9e7-baf9-11ce-8c82-00aa004ba90b}']
    function RegisterNameSpace(
    		const pCF: IClassFactory;		// [in] IClassFactory __RPC_FAR *pCF
        const rclsid: TCLSID;				// [in] REFCLSID rclsid
	      pwzProtocol: PWChar;				// [in] LPCWSTR pwzProtocol
        const cPatterns: ULONG;			// [in] ULONG cPatterns
  	   	ppwzPatterns: PPWChar;			// [in] const LPCWSTR __RPC_FAR *ppwzPatterns
        const dwReserved: DWORD			// [in] DWORD dwReserved
      ): HResult; stdcall;
    function UnregisterNameSpace(
    		const pCF: IClassFactory;		// [in] IClassFactory __RPC_FAR *pCF
        pwzProtocol: PWChar					// [in] LPCWSTR pszProtocol
      ): HResult; stdcall;
    function RegisterMimeFilter(
    		const pCF: IClassFactory;		// [in] IClassFactory __RPC_FAR *pCF
        const rclsid: TCLSID;				// [in] REFCLSID rclsid
  	    pwzType: PWChar							// [in] LPCWSTR pwzType
      ): HResult; stdcall;
    function UnregisterMimeFilter(
    		const pCF: IClassFactory;	// [in] IClassFactory __RPC_FAR *pCF
        pwzType: PWChar						// [in] LPCWSTR pwzType
      ): HResult; stdcall;
    function CreateBinding(
    		pBC: Pointer;												// [in] LPBC pBC
        szUrl: PWChar;											// [in] LPCWSTR szUrl
	      const pUnkOuter: IUnknown;					// [in] IUnknown __RPC_FAR *pUnkOuter
        out ppUnk: IUnknown;								// [out] IUnknown __RPC_FAR *__RPC_FAR *ppUnk
  	    out ppOInetProt: IInternetProtocol;	// [out] IInternetProtocol __RPC_FAR *__RPC_FAR *ppOInetProt
        const dwOption: DWORD								// [in] DWORD dwOption
      ): HResult; stdcall;
    function SetSessionOption(
    		const dwOption: DWORD;				// [in] DWORD dwOption
        var pBuffer;									// [in] LPVOID pBuffer
	      const dwBufferLength: DWORD;	// [in] DWORD dwBufferLength
        const dwReserved: DWORD				// [in] DWORD dwReserved
      ): HResult; stdcall;
    function GetSessionOption(
    		const dwOption: DWORD;			// [in] DWORD dwOption
        var pBuffer;								// [in/out] LPVOID pBuffer
	      var dwBufferLength: DWORD;	// [in/out] DWORD __RPC_FAR *pdwBufferLength
        const dwReserved: DWORD			// [in] DWORD dwReserved
      ): HResult; stdcall;
  end;

function CoInternetGetProtocolFlags(
		pwzUrl: PWChar;					// LPCWSTR pwzUrl
    pdwFlags: PDWORD;				// DWORD *pdwFlags
		const dwReserved: DWORD	// DWORD dwReserved
  ): HResult; stdcall;

function CoInternetGetSession(
		const dwSessionMode: DWORD;								// DWORD dwSessionMode
    var ppIInternetSession: IInternetSession;	// IInternetSession **ppIInternetSession
    const dwReserved : DWORD									// DWORD dwReserved
  ): HResult; stdcall;

function CoInternetParseUrl(
		pwzUrl: PWChar;							// LPCWSTR pwzUrl
    const ParseAction: integer;	// PARSEACTION ParseAction
    const dwFlags: DWORD;				// DWORD dwFlags
    pszResult: PWChar;					// LPWSTR pszResult
    const cchResult: DWORD;			// DWORD cchResult
    pcchResult: PDWORD;					// DWORD *pcchResult
    const dwReserved: DWORD			// DWORD dwReserved
  ): HResult; stdcall;

implementation

// Note that if '.dll' is omitted then code will not compile under NT
function CoInternetGetProtocolFlags; external 'urlmon.dll';
function CoInternetGetSession; external 'urlmon.dll';
function CoInternetParseUrl; external 'urlmon.dll';

end.
