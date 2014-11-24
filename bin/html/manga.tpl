<div class="manga">
	<div style="overflow: hidden;"><div class="jenres">{%jenres%}</div>
	<img src="/data/previews/{%id:wide%}.bmp" alt="" title="{%manga.title%}"/>
	<div class="title"><span>{%manga.title%}</span><button class="tdel">-</button></div>
	<div class="title sub">{%subtitles%}</div>
	<input id="ttledit" type=text /><button id="tadd">+</button>
	<div class="title sub folder" style="clear: both;">Папка: <input type="text" value="{%folder%}" /><button>save</button></div>
	</div><hr />
	<div class="description">&nbsp; &nbsp; <span>{%description%}</span></div><button id="dedit">Edit</button>
	<span class="pull right">[
	<a href="/manga/delete/{%id%}">Удалить</a>
	 | <a href="javascript:manga_folder({%id%})">Архивы</a>
	 | <a href="javascript:manga_import({%id%})">Импорт</a>
	 | <a href="/reader/continue/{%id%}">Читать</a>
	]</span>
</div>
<script>
	$('.folder button').click(function(e) {
		var archive = $('.folder [type="text"]').val();
		if (archive != '')
			$AJAX('/manga/folder/?manga={%id%}&folder=' + archive.replace(/\&/g, '%26'), {
				onsuccess: function(ajax) {
					document.location.reload();
				}
			});
	});

	$('.jlink').disableSelection();
	$('.jlink').click(function () {
		var link = $(this).is('a') ? $(this) : $(this).parent('a:first');

		var m = this.className.match(/(true)/i), set = m && !!m[1];

		jid = parseInt(this.getAttribute('jid'));
		var url = '/reader/tag/{%id%}/' + jid;
		$.getJSON(url, {'set': set ? '1' : '0'})
		.success(function (data) {
			link.removeClass("true", "false").addClass(data.state ? 'true' : 'false');
		})
		.error(function(error) {
			alert('Request failed!');
		});
	});

	$('#tadd').click(function(e) {
		var title = $('#ttledit').val();
		if (title != '')
			$AJAX('/manga/title/?manga={%id%}&param=add&title=' + title.replace(/\&/g, '%26'), {
				onsuccess: function(ajax) {
					document.location.reload();
				}
			});
	});
	$('.tdel').click(function() {
		var p = $(this).parent().find('SPAN');
		var title = p.html().replace('©', '&copy;');
		if (title != '')
			$AJAX('/manga/title/?manga={%id%}&param=delete&title=' + title.replace(/\&/g, '%26'), {
				onsuccess: function(ajax) {
					document.location.reload();
				}
			});
	});
	$('#dedit').click(function() {
		var desc = $('.description'), s = desc.find('span').html().trim();
		var form = $('<FORM>'),
				area = $('<TEXTAREA>');
		form.attr('action', '/manga/descr/?manga={%id%}&param=delete')
				.attr('method', 'post');
		area.html(s)
			.attr('id', 'desc_editor')
			.attr('name', 'descr');
		form.append(area);
		desc.val('');
		desc.append(form);
		$(this).text('Save').click(function() {form.submit()});
	});

</script>