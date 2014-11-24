	<div id="plate{%id%}" class="plate {%canread%}">
			<a name="id{%id%}"></a>
			<div class="outline">
				<img class="preview" alt="" src="/data/previews/{%id:wide%}.bmp" />
				<div class="hotpins">
					<a href="javascript:manga_archfix({%id%})"><img src="/theme/img/0026.bmp" /></a>
					<a href="javascript:manga_folder({%id%})"><img src="/theme/img/0020.bmp" /></a>
					<a href="javascript:manga_import({%id%})"><img src="/theme/img/0018.bmp" /></a>
					<a href="/reader/continue/{%id%}"><img src="/theme/img/0010.bmp" /></a>
				</div>
				<div class="title"><a href="/reader/{%id%}">{%m.title%}</a></div><div class="title sub">{%m.title2%}</div>
				Прогресс: <span class="progress">{%progress%}</span><span style="font-size: 50%; padding-left: 2px;" class="ch apters">{%chapters%}</span><br />
				<span class="arch new">{%arch:new%}</span><span class="arch total">{%arch:total%}</span><br />
				<div class="detail">
					<span class="sub">[ID#{%id:wide%}] {%folder%}</span>
					<span class="state">{%state%}</span>
				</div>
			</div>
		</div>