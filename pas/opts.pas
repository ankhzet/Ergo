unit opts;
interface

var
	OPT_PREVIEWS: boolean = true;
	OPT_MANGADIR: AnsiString = 'manga';
	OPT_DATADIR : AnsiString = 'data';

	WEB_ITF_IP  : AnsiString = '127.0.0.1';
	WEB_ITF_LOCL: AnsiString = '127.0.0.1';
	WEB_ITF_PORT: Integer    = 2012;

const
	graphic_ext: array [0..5] of PAnsiChar = ('jpeg', 'jpg', 'png', 'gif', 'bmp', 'pdf');

	SD_CREDITS = 'credits';
	SD_JUNK    = 'junk';
	SD_ARCHIVE = 'archives';
	SDIRS      : array [0..2] of PAnsiChar = (SD_CREDITS, SD_JUNK, SD_ARCHIVE);
	ARCHS      : array [0..3] of PAnsiChar = ('rar', 'zip', 'tar', 'arj');

	J_READED    = 55;
	J_COMPLETED = 56;
	J_SUSPENDED = 60;

	SIZE_IMGNAME = 3;
	SIZE_CHPNAME = 4;
	SIZE_MANNAME = 6;

	COPT_MANGADIR = $000001;
	COPT_DATADIR  = $000002;

implementation

end.
