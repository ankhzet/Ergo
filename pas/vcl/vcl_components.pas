unit vcl_components;
interface

type
	TComponent  = class
	private
		fComps    : Integer;
		fData     : array of TComponent;
		Sorted    : Boolean;
		fOwner    : TComponent;
		function    getComponent(Index: Integer): TComponent;
		procedure   setComps(const Value: Integer);
		procedure   setOwner(const Value: TComponent);
	protected
		procedure   Sort;
	public
		constructor Create(AOwner: TComponent); virtual;
		destructor  Destroy; override;

		function    Insert(Component: TComponent): Integer;
		function    Remove(Component: TComponent): Integer;
		procedure   RemoveAll;
		function    IndexOf(Component: TComponent): Integer;

		property    Owner: TComponent read fOwner write setOwner;
		property    Component[Index: Integer]: TComponent read getComponent; default;
		property    Components: Integer read fComps write setComps;
	end;

implementation

{ TComponent }

constructor TComponent.Create(AOwner: TComponent);
begin
	Owner := AOwner;
end;

destructor TComponent.Destroy;
begin
	if Owner <> nil then Owner.Remove(Self);
	inherited;
end;

function TComponent.getComponent(Index: Integer): TComponent;
begin
	if (Index < 0) or (Index >= Components) then
		result := nil
	else
		result := fData[Index];
end;

function TComponent.IndexOf(Component: TComponent): Integer;
var
	l, h: Integer;
begin
	h := Components - 1;
	if h >= 0 then begin
		l := 0;
		if not Sorted then Sort;
		repeat
			result := (l + h) div 2;
			if Cardinal(fData[result]) = Cardinal(Component) then exit;
			if Cardinal(fData[result]) < Cardinal(Component) then
				l := result + 1
			else
				h := result - 1;
		until l > h;
	end;
	result := -1;
end;

function TComponent.Insert(Component: TComponent): Integer;
begin
	result := IndexOf(Component);
	if result < 0 then begin
		result := Components;
		Components := result + 1;
		fData[result] := Component;
	end;
end;

function TComponent.Remove(Component: TComponent): Integer;
var
	i: Integer;
begin
	result := IndexOf(Component);
	if result < 0 then exit;
	i := Components - 1;
	if result <> i then fData[result] := fData[i];
	Components := i;
end;

procedure TComponent.RemoveAll;
begin
	while Components > 0 do fData[0].Free;
end;

procedure TComponent.setComps(const Value: Integer);
begin
	if fComps <> Value then begin
		fComps := Value;
		SetLength(fData, Value);
		Sorted := Value <= 1;
	end;
end;

procedure TComponent.setOwner(const Value: TComponent);
begin
	if fOwner <> Value then begin
		if fOwner <> nil then fOwner.Remove(Self);
		fOwner := Value;
		if fOwner <> nil then fOwner.Insert(Self);
	end;
end;

procedure TComponent.Sort;
var
	i: Integer;
	t: TComponent;
begin
	repeat
		Sorted := true;
		for i := 0 to Components - 2 do
			if Cardinal(fData[i]) > Cardinal(fData[i + 1]) then begin
				t            := fData[i + 1];
				fData[i + 1] := fData[i];
				fData[i]     := t;
				Sorted       := false;
			end;
	until Sorted;
end;

end.
