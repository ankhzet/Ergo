unit NsFactory;

{
	Authored 7/3/98 by Mike Vance, Scoutship Technologies - mvance@lightspeed.net

	Use instead of TComObject to correct TComObject's error of never
  adding the critical "ThreadingModel" registry entry.
  It also register/unregisters the HKEY_CLASSES_ROOT\PROTOCOLS\Name-Space Handler\
  values necessary to installing a permanent namespace, but you can disable that
  by modifying the code if you so wish.
}

interface

uses
	ComObj;

type
	TNsFactory = class (TComObjectFactory)
		procedure UpdateRegistry(bRegister: boolean); override;
  end;

////////////////////////////////////////////////////////////////////////////////

implementation

uses
	Registry, Windows, SysUtils;

const
	keyNsHandler = 'PROTOCOLS\Handler\';

procedure PermNsRegByName(sProtocol, sName: string; ClassId: TGuid);
begin
	with TRegistry.Create do
  	try
      try
        RootKey := HKEY_CLASSES_ROOT;

        // Register ftp handler
        OpenKey(Format(keyNsHandler + '%s', [sProtocol]), true);
        WriteString('', sName);
        WriteString('CLSID', GuidToString(ClassId));
        CloseKey;
      except
        raise Exception.CreateFmt('Failed to register name-space handler "%s"',
            [sName]);
		  end;
    finally
		  Free;
    end;
end;

////////////////////////////////////////////////////////////////////////////////

procedure PermNsUnregByName(sProtocol, sName: string);
var
	sKey: string;
begin
	with TRegistry.Create do
  try
    RootKey := HKEY_CLASSES_ROOT;
    sKey := Format(keyNsHandler + '%s', [sProtocol]);
		if KeyExists(sKey) then
    	DeleteKey(sKey);
  finally
		Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////

procedure TNsFactory.UpdateRegistry(bRegister: Boolean);
var
	sClassId: string;
begin
	sClassId := GUIDToString(ClassID);
	inherited UpdateRegistry(bRegister);
	if bRegister then
  begin
  	// Register
		CreateRegKey('CLSID\' + sClassId + '\InprocServer32',
    		'ThreadingModel', 'Apartment');
    // Namespace handler registry entries
		PermNsRegByName('ework', ClassName, ClassId);
  end
  else
  begin
		// Unregister
  	// Don't bother unregistering any values under HKEY_CLASSES_ROOT\CLSID\{MyClassId}
    //		because parent method has already deleted that key
		PermNsUnregByName('ework', ClassName);
  end
end;

end.
