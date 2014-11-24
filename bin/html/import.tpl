<form id="import" action="?action=add" method="post">
	<label>Название(я) манги:</label>
	<textarea style="height: 70px;" type="text" name="title">{%request[title]%}</textarea><br />
	<label>Описание:</label>
	<textarea name="descr">{%request[descr]%}</textarea><br />
	<input type="submit" value="Добавить" /><br />
</form>
<hr />
<label style="color: red; font-weight: bold;">{%error%}</label>