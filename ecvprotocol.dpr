library ecvprotocol;
{$R *.res}

uses
	c_protocolhandler;

begin
end.

(*

Workflow:

1. Initialization
2. Enter msg loop
	2.1 On connect:
		2.1.1 Check App is running
			if not running
				2.1.1.1 Launch app
				2.1.1.1 Wait, till app is ready for incoming msgs
		2.1.2 Install joint between app & caller
