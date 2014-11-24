<div class="archs">
	<h1>{%title%}</h1>
	<hr />
	Папки:<br /><br />
	<ul><li>{%dirs%}</li></ul>
	<form action="/import?action=add" method="post">
		<input type=text name="dir" />
		<input type=submit value="Добавить" />
	</form>
	<hr />
	<br />
	<div>
{%archs%}
	</div>
	<div class="ulist" id="archs"></div>
</div>
<script>
	var files = [null,
	{%fileslist%}
	];
	var mangas = [null{%mangas%}];
	var origins = [{%origins%}];
	var mangaid = [{%mangaids%}];
	var matches = [{%matches%}];

	var PAT_1 = '<span><a href="javascript:manga_folder({$id$})">Папка</a> | <a href="javascript:manga_import({$id$});">Импорт</a> | <a href="/reader/continue/{$id$}">Читать</a></span> {$origin$} {$import$}';
	var PAT_2 = '<span style="color:gray">&lt;Нет совпадений&gt;</span>';
	var PAT_3 = '<a href="javascript:void(0);" onclick="arch_import(files[{$files$}], \'{$origin$}\', this);">&rarr;</a>';
	var PAT_4 = 'build_ulist(this, {$u1$}, {$u2$}, [{$u3$}])';
	var PAT_5 = 'arch_import([files[{$u1$}][{$u2$}]], "{$origin$}", this)';

	var archs = $('#archs');
	var ul = document.createElement('UL');
	for (var i in origins) {
		var idx = parseInt(i);
		var origin = origins[i];
		var flist = files[idx + 1];
		var li = document.createElement('li');
		var text = document.createElement('h6');

		var params = {origin: origin, id: mangaid[i], 'import': origin ? format(PAT_3, {files: idx + 1, origin: origin}) : ''};
		text.innerHTML = origin ? format(PAT_1, params) : PAT_2;

		li.appendChild(text);
		var ul2 = document.createElement('UL');
		for (var j in flist) {
			var file = flist[j];
			var fid = parseInt(j);
			var l = document.createElement('LI');
			var a1 = document.createElement('A');
			var a2 = document.createElement('A');
			var t = document.createElement('SPAN');
			t.innerHTML = file.replace(/\%([\da-f][\da-f])/ig, function(a, b) {return '&#' + parseInt('0x' + b) + ';';});
			a1.innerText = '[=]';
			a1.className = 'listtip';
			a1.href = 'javascript:void(0);';
			a1.onclick = format(PAT_4, {
				u1: idx + 1
			, u2: fid
			, u3: (mangaid[idx] < 0) ? '' : matches[idx].join(',')
			});
			a2.innerHTML = '&uarr;';
			a2.className = 'listtip';
			a2.href = 'javascript:void(0);';
			a2.onclick = format(PAT_5, {origin: origin, u1: idx + 1, u2: fid});
			l.appendChild(a2);
			l.appendChild(a1);
			l.appendChild(t);
			ul2.appendChild(l);
		}
		li.appendChild(ul2);
		ul.appendChild(li);
	}
	archs.append(ul);
</script>