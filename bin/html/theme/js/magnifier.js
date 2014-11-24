var
	magnifier = new function() {
		var SUMMON_KEY = 16; // shift
		var GLASS_WIDTH = 200;
		var GLASS_HEIGHT = 200;
		var holder = null, inner = null, cache = null;
		var summoned = false;
		var viewWidth = 0, viewHeight = 0;
		var realWidth = 0, realHeight = 0;
		this.init = function () {
			holder = $('.magnifier');
			cache = holder.find('img');
			inner = holder.find('.m-inner');
			inner.css({
				'width': (GLASS_WIDTH + 2) + 'px'
			, 'height': (GLASS_HEIGHT + 2) + 'px'
			});
			$(window).keydown(function(event) {
				if (event.keyCode == SUMMON_KEY)
					magnifier.toggle(true);
			});
			$(window).keyup(function(event) {
				if (event.keyCode == SUMMON_KEY)
					magnifier.toggle(false);
			});
			holder.mousemove(function(event) {
				holder.hide();
			});
		}
		this.toggle = function (show) {
			summoned = show;
			if (!show)
				holder.hide();
		}
		this.handle = function (img) {
			$('#cacheholder img').mousemove(function(event) {
				if (!summoned)
					return;
				if (!holder.is(':visible'))
					holder.show();

				var x = event.offsetX;
				var y = event.offsetY;
				holder.css({
					'left': (event.pageX + 32 - 3) + 'px',
					'top': (event.pageY - GLASS_HEIGHT / 2 - 3) + 'px'
				});

				img = $(this);
				var src = img.attr('src');
				viewWidth = img.width();
				viewHeight = img.height();
				if (cache.attr('src') != src) {
					cache.attr('src', src);
					cache.load(function() {
						realWidth = cache.width();
						realHeight = cache.height();
						inner.css('background-image', 'url("' + src + '")');
						magnifier.offset(x, y);
					});
				} else
					magnifier.offset(x, y);
			});
		}
		this.offset = function(clientX, clientY) {

			var cToRX = - clientX * realWidth / viewWidth + GLASS_WIDTH / 2;
			var cToRY = - realHeight * clientY / viewHeight + GLASS_HEIGHT / 2;
			var pos = format('{$x$}px {$y$}px', {x: Math.round(cToRX), y: Math.round(cToRY)});
			inner.css({
				'background-position': pos
			});
		}

		$(function() {
			magnifier.init();
		});
	};