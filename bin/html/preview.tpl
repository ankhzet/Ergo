<style>
	#preview .pcontainer {
		width: 50%;
		margin: 0 25%;
		border: 1px solid black;
		border-radius: 3px;
	}

	#preview .pimg {
		width: 100%;
	}

	.selector {
		position: absolute;
		margin: 0;
		opacity: 0.6;
		background-color: #000;
		overflow: hidden;
		width: 100%;
	}

	.selector .outer {
		width: 50%;
		height: 1%;
		background-color: #fff;
		padding: 5px;
		cursor: size;
	}
	.selector .inner {
		width: 100%;
		height: 100%;
		margin: 0;
		padding: 0;
		overflow: hidden;
		cursor: move;
		border: 1px solid black;
		margin: -1px -1px;
	}
	.selector .inner img {
		margin: -5px -5px;
	}

	#iscale {
		width: 100px;
		display: inline-block;
		height: 96px;
		width: 63px;
		padding: 0;
	}
</style>
<div style="width: 100%; text-align: center;">
	<img id="previewgen" style="width: 63px; height: 96px; margin: 15px 0 -5px; border: 1px solid black;" src="" />
	<select id="iscale" multiple onchange="prevGen.scale(this.options[this.selectedIndex].value);prevGen.genPreview();">
		<option value="0.1">10%</option>
		<option value="0.2">20%</option>
		<option value="0.3">30%</option>
		<option value="0.4">40%</option>
		<option value="0.5" selected>50%</option>
		<option value="0.6">60%</option>
		<option value="0.7">70%</option>
		<option value="0.8">80%</option>
		<option value="0.9">90%</option>
		<option value="1.0">100%</option>
	</select>
</div>
<form action="/manga/preview/{%id%}?action=save" method="post"><input type=submit value="Сохранить" /></form>
<div id="preview" onmousedown="return false;">
	<div class="pcontainer">
		<div class="selector">
			<div class="outer">
				<div class="inner">
					<img src="{%request[origin]%}" />
				</div>
			</div>
		</div>
		<img class="pimg" src="{%request[origin]%}" />
	</div>
</div>

<script src="/theme/js/jquery.js"></script>
<script>
	function patproc(str, oj) {
		return str.replace(/\{\$([\w\d\_]+)\}/gi, function (a, b) {return oj[b]});
	}

	var
		origin = "{%request[origin]%}",
		selectorAspect = 1.52,
		prevGen = new function() {
			var
				selector = $('#preview .selector')
			, outerDiv = $('#preview .outer')
			, innerDiv = $('#preview .inner')
			, innerImg = $('#preview .inner img')
			, preview  = $('#preview .pimg')
			, rw = preview.width()
			, rh = preview.height()
			, iw = 0, ih = 0, dx = 0, dy = 0
			, drag = false, mx = 0, my = 0
			;

			this.scale = function (ratio) {
				var
					scaledW = Math.round(rw * Math.min(ratio, 1))
				, scaledH = scaledW * selectorAspect;
				outerDiv.width(scaledW);
				outerDiv.height(scaledH);
				selector.width(rw);
				selector.height(rh);
				innerImg.width(rw);
				innerImg.height(rh);
			}
			this.offsetLens = function(dx, dy) {
				outerDiv.css({'margin-left': dx + 'px', 'margin-top': dy + 'px'});
				innerImg.css({'margin-left': (- dx - 5) + 'px', 'margin-top': (- dy - 5) + 'px'});
			}
			this.genPreview = function() {
				var link = patproc(
					'/manga/preview/{%id%}?action=generate&origin={$o}&rw={$rw}&rh={$rh}&dw={$dw}&dh={$dh}&dx={$dx}&dy={$dy}'
				, {
					o: origin
				, rw: rw
				, rh: rh
				, dw: outerDiv.width()
				, dh: outerDiv.height()
				, dx: dx + 5
				, dy: dy + 5
					}
				);
				$('#previewgen').attr('src', link);
			}
			this.init = function(initialScale) {
				this.scale(initialScale);
				var pw = selector.width();
				var ph = selector.height();

				iw = innerDiv.width();
				ih = innerDiv.height();

				dx = Math.round((pw - iw) / 2);
				dy = Math.round((ph - ih) / 2);
				this.offsetLens(dx, dy);

				drag = false;
				mx = my = 0;

				this.genPreview();
			}
			outerDiv.mousedown(function(event) {
				mx = event.pageX;
				my = event.pageY;
				drag = true;
			});
			selector.mouseup(function(event) {
				if (!drag) return false;
				drag = false;
				dx += event.pageX - mx;
				dy += event.pageY - my;
				prevGen.genPreview();
			});
			$(document).mousemove(function(event) {
				if (!drag) return false;
				var ox = dx + event.pageX - mx;
				var oy = dy + event.pageY - my;
				prevGen.offsetLens(ox, oy);
			});
		};

	$(function() {
		prevGen.init(0.5);
	});

</script>