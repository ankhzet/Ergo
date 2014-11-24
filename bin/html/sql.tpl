<form id="import" action="?action=execute" method="post">
	<label>Запрос:</label>
	<textarea name="query">{%request[query]%}</textarea><br />
	<input type="submit" value="Выполнить" /><br />
</form>
<hr />
<label style="color: red; font-weight: bold;">{%error%}</label>