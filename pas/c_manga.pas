unit c_manga;
interface
uses
	strings
, c_interactive_lists
, c_jenres
;

type
	TFilters    = (f_jenres, f_status);
	TFilter     = set of TFilters;
	TJenreFilter= set of Byte;
	PManga      =^TManga;
	TManga      = record
		mID       : Cardinal;
		mNew      : Boolean;
		mTitles   : TStrings;
		mJenres   : TStrings;
		mJIDS     : TJenresArray;
		mDescr    : AnsiString;
		mStatus   : Cardinal;
		mLink     : AnsiString;
		mServer   : AnsiString;
		mSrc      : Integer;
		mComplete : Boolean;
		rSuspended: Boolean;
		mArchives : Integer;
		mArchTotal: Integer;
		rChapter  : Single;
		pChapter  : Single;
		pPage     : Integer;
		rReaded   : Boolean;
		Filtered  : Boolean;
		mChaps    : Integer;
		pIcon     : AnsiString;
		pILItem   : PILItem;
		Reserver  : array [Byte] of Byte;
	end;

function _manga_pick(List: PIList; ID: Cardinal): PManga;

implementation

function _manga_pick(List: PIList; ID: Cardinal): PManga;
	function filter(Item: PILItem; Data: Pointer): Boolean;
	begin
		result := PManga(Item.Data).mID = PCardinal(Data)^;
	end;
begin
	result := PManga(_il_pick(List, @filter, @ID));
	if result <> nil then
		result := PManga(PILItem(result).Data);
end;

end.
