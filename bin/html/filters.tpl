<h1>Фильтрация по тегам</h1>
<form action="/manga/filters/?action=set" method="post" class="filters">
	Показать/исключить по тегам:<br /><br />
	{%jenres%}
	<br />
	<div class="filter">
		Показать только недочитанные:<br />
		<div><input class="jf yes" name="unfinished" type="checkbox" /> Yes&nbsp;&nbsp;</div>
	</div>
	<div style="clear: both;"></div>
	<div>
		<input type="submit" value="Фильтровать" />
	</div>
</form>