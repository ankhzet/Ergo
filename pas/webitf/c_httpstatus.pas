unit c_httpstatus;
interface

function CodeStr(Code: Word): AnsiString;

implementation

function CodeStr(Code: Word): AnsiString;
begin
	case Code of
		100: result := 'Continue';// (Ђпродолжитьї).
		101: result := 'Switching Protocols';// (Ђпереключение протоколовї).
		102: result := 'Processing';//
		200: result := 'OK';// (Ђхорошої).
		201: result := 'Created';// (Ђсозданої).
		202: result := 'Accepted';// (Ђприн€тої).
		203: result := 'Non-Authoritative Information';// (Ђинформаци€ не авторитетнаї[источник не указан 33 дн€]).
		204: result := 'No Content';// (Ђнет содержимогої).
		205: result := 'Reset Content';// (Ђсбросить содержимоеї).
		206: result := 'Partial Content';// (Ђчастичное содержимоеї).
		207: result := 'Multi-Status';// (Ђмногостатусныйї).
		226: result := 'IM Used';//
		300: result := 'Multiple Choices';// (Ђмножество выборовї).
		301: result := 'Moved Permanently';// (Ђперемещено навсегдаї).
		302: result := 'Moved Temporarily';// (Ђнайденої).
		303: result := 'See Other';// (смотреть другое).
		304: result := 'Not Modified';// (не измен€лось).
		305: result := 'Use Proxy';// (Ђиспользовать проксиї).
		306: result := '';//Ч зарезервировано.
		307: result := 'Temporary Redirect';//
		400: result := 'Bad Request';// (Ђплохой запросї).
		401: result := 'Unauthorized';// (Ђнеавторизованї).
		402: result := 'Payment Required';// (Ђнеобходима оплатаї).
		403: result := 'Forbidden';// (Ђзапрещеної).
		404: result := 'Not Found';// (Ђне найденої).
		405: result := 'Method Not Allowed';// (Ђметод не поддерживаетс€ї).
		406: result := 'Not Acceptable';// (Ђне приемлемої).
		407: result := 'Proxy Authentication Required';// (Ђнеобходима аутентификаци€ проксиї).
		408: result := 'Request Timeout';// (Ђистекло врем€ ожидани€ї).
		409: result := 'Conflict';// (Ђконфликтї).
		410: result := 'Gone';// (ЂудалЄнї).
		411: result := 'Length Required';// (Ђнеобходима длинаї).
		412: result := 'Precondition Failed';// (Ђусловие ложної[источник не указан 33 дн€]).
		413: result := 'Request Entity Too Large';// (Ђразмер запроса слишком великї).
		414: result := 'Request-URI Too Long';// (Ђзапрашиваемый URI слишком длинныйї).
		415: result := 'Unsupported Media Type';// (Ђнеподдерживаемый тип данныхї).
		416: result := 'Requested Range Not Satisfiable';// (Ђзапрашиваемый диапазон не достижимї).
		417: result := 'Expectation Failed';// (Ђожидаемое не приемлемої[источник не указан 33 дн€]).
		422: result := 'Unprocessable Entity';// (Ђнеобрабатываемый экземпл€рї).
		423: result := 'Locked';// (Ђзаблокированої).
		424: result := 'Failed Dependency';// (Ђневыполненна€ зависимостьї).
		425: result := 'Unordered Collection';// (Ђнеупор€доченный наборї).
		426: result := 'Upgrade Required';// (Ђнеобходимо обновлениеї).
		449: result := 'Retry With';// (Ђповторить сї).
		456: result := 'Unrecoverable Error';//
		500: result := 'Internal Server Error';// (Ђвнутренн€€ ошибка сервераї).
		501: result := 'Not Implemented';// (Ђне реализованої).
		502: result := 'Bad Gateway';// (Ђплохой шлюзї).
		503: result := 'Service Unavailable';// (Ђсервис недоступенї).
		504: result := 'Gateway Timeout';// (Ђшлюз не отвечаетї).
		505: result := 'HTTP Version Not Supported';// (Ђверси€ HTTP не поддерживаетс€ї).
		506: result := 'Variant Also Negotiates';// (Ђвариант тоже согласованї[источник не указан 33 дн€]).
		507: result := 'Insufficient Storage';// (Ђпереполнение хранилищаї).
		509: result := 'Bandwidth Limit Exceeded';// (Ђисчерпана пропускна€ ширина каналаї).
		510: result := 'Not Extended';//

		else result := 'Unknown status';
	end;
end;

end.
