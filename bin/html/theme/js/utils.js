var
	notifier = new function() {
		var
			TICK_INTERVAL = 20
		, TIP_INTERVAL = 4000
		, TIP_FADEOUT = 1000
		;
		var holder = null, tips = [];

		this.timestamp = function() {
			return (new Date()).getTime();
		}
		this.tick = function() {
			this.serveQueue();
			setTimeout(function(){notifier.tick()}, TICK_INTERVAL);
		}
		this.showNotification = function(msg) {
			var block = $('<div class="tool-block last">' + msg + '</div>');

			var tip = {"block": block, "time": this.timestamp()};
			tips.push(tip);

			holder.prepend(block);
		}
		this.serveQueue = function () {
			if (!tips.length)
				return;

			var time = (new Date()).getTime();
			var unqueue = [];
			$(tips).each(function (idx, tip) {
				if (time > tip.time + TIP_INTERVAL) {
					tip.block.fadeOut(TIP_FADEOUT);
					unqueue.push(tip);
				}
			});

			for (var i in unqueue) {
				var idx = $.inArray(unqueue[i], tips);
				tips.splice(idx, 1);
			}

			if (!tips.length) {
				holder.fadeOut(TIP_FADEOUT);
				return;
			}

			var last = tips[0];
			$(tips).each(function(idx, tip){
				tip.block.removeClass('last');
			});
			last.block.addClass('last');

			holder.is(':animated')
				holder.stop(true, true);

			holder.show();
		}

		$(function() {
			holder = $('.tooltip');
			notifier.tick();
		});
	};

function ualert(msg) {
	$(function() {
		notifier.showNotification(msg);
	});
}

(function($){
	$.fn.disableSelection = function() {
		return
			this
			.attr('unselectable', 'on')
			.css({'-moz-user-select':'-moz-none',
			 '-moz-user-select':'none',
			 '-o-user-select':'none',
			 '-khtml-user-select':'none', /* you could also put this in a class */
			 '-webkit-user-select':'none',/* and add the CSS class here instead */
			 '-ms-user-select':'none',
			 'user-select':'none'
			})
			.on('selectstart', false);
		};
})(jQuery);

function toJSON(obj, r) {
	if (obj === null) return 'null';
	r = r || [];

	var type = typeof obj;
	switch (type) {
		case 'undefined':
		case 'unknown'  : return type;
		case 'function' : return /*obj.toString();//*/ '[' + type + ']';
		case 'string'   : return '"' + obj.toString() + '"';
		case 'number'   :
		case 'boolean'  : return obj.toString();
		default:
			if (obj instanceof jQuery) return '[object jQuery]';
//      if (!(/^\[object object\]$/i.test(obj.toString()))) return obj.toString();

			if (r.length && ($.inArray(obj, r) >= 0)) return '(* ' + obj.toString() + ')';
			r.push(obj);

			if (/^\[object HTML/i.test(obj.toString())) return obj.toString();

			if (typeof obj.length !== 'undefined') {
				var vals = [];
				for (var prop in obj) {
					var val = toJSON(obj[prop], r);
					if ((typeof val !== 'undefined'))
						 vals.push(val);
				};
				return '[' + vals.join(', ') + ']';
			} else {
				var vals = [];
				for (var prop in obj) {
					var val = toJSON(obj[prop], r);
					if ((typeof val !== 'undefined'))
						vals.push(prop + " = " + val);
				};
				return '{\n' + vals.join(';\n ') + '\n}';
			}
	}
}

function format(str, args) {
	return str.replace(/\{\$([^\$]+)\$\}/ig, function (a, b) {return (typeof args[b] != 'undefined') ? args[b] : ''});
}

/*
 * --------------------- AJaX --------------------- *
 */

 function getXMLHTTPRequestObject() {
	var xmlhttp = null;
	if (XMLHttpRequest)
		try { xmlhttp = new XMLHttpRequest(); } catch (e) { };
	if (!xmlhttp)
		try { xmlhttp = new ActiveXObject("Microsoft.XMLHTTP"); } catch (e) {
		 try { xmlhttp = new ActiveXObject("Msxml2.XMLHTTP"); } catch (e) { };
		};
	return xmlhttp;
};



var
	AJaX = (function () {
	var pending  = [];
	var GUID     = 0;

	this.onReady = function (ajax) {
		delete pending[ajax.id];
		var callback = null;
		switch (ajax.stat()) {
		case 200:
			callback = ajax.onsuccess || this.onsuccess;
			break;
		default :
			callback = ajax.onfail || this.onfail;
		}
		if (callback) callback(ajax);
		ajax = null;
	}
	this.onsuccess = function (ajax) {
	}
	this.onfail = function (ajax) {
	}
	this.query   = function (query, props) {
		var ajax = new newAJAX(++GUID), xmlhttp = ajax.xmlhttp;
		pending[GUID] = ajax;
		if (props)
			for (var prop in props)
				ajax[prop] = props[prop];
		xmlhttp.open('GET', query, true);
		xmlhttp.setRequestHeader('Content-Language', 'ru');
		xmlhttp.setRequestHeader('Content-Type', 'text; charset: utf-8');
		xmlhttp.send(null);
		return ajax;
	}

	return this;
})();

function newAJAX(uid) {
	var instance = this;
	this.id = uid;
	this.xmlhttp = getXMLHTTPRequestObject();
	if (this.xmlhttp) {
		this.xmlhttp.onreadystatechange = function () {
			if (instance.ready() == 4) {
				AJaX.onReady(instance);
			}
		}
	}
	this.ready = function () { return this.xmlhttp.readyState; }
	this.stat = function () { return this.xmlhttp.status; }
	this.response = function () { return this.xmlhttp.responseText; }
	return instance;
}

function $AJAX(query, props) {
	AJaX.query(query, props);
}

/*
	-------------------- URI -------------------- */

function getParams() {
	var res = [], args = document.location.search.split('?')[1];
	args = args ? args.split('&') : [];
	for (var i in args)
		if (m = args[i].match(/([\w\d]+)\=([^\&]*)/i))
			res[m[1]] = m[2];

	return res;
}

/*
	-------------------- DOM -------------------- */

function addOption (oListbox, text, value, isDefaultSelected, isSelected)
{
	var oOption = document.createElement("option");
	oOption.appendChild(document.createTextNode(text));
	oOption.setAttribute("value", value);

	if (isDefaultSelected) oOption.defaultSelected = true;
	else if (isSelected) oOption.selected = true;

	oListbox.appendChild(oOption);
	return oOption;
}

/* -------------------------- */

function manga_folder(id) {
	$.getJSON('/folder/' + id);
}

function chapter_folder(id, chapter) {
	$.getJSON('/folder/' + id + '/' + chapter)
		.success(function (json) {
			if (json.result != 'ok')
				ualert(e.msg);
		});
}

function manga_import(id) {
	$.getJSON('/import/new/' + id)
		.success(function( data ){
			ualert(parseInt(data.imported) ? 'Imported ' + data.imported + ' chapters' : 'No chapters to import =\\');
		})
		.error(function() {
			ualert('Request failed!');
		});
}

function manga_archfix(id) {
	$.getJSON('/import/archfix/' + id)
		.error(function() {
			ualert('Request failed!');
		})
		.success(function(json) {
			var plate = $qs();
			$('#plate' + id).find('.arch.total').html(json.archs);
			$('#plate' + id).find('.arch.new').html('');
		});
}

function $qs(selector, from) {
	return (from ? from : document).querySelectorAll(selector)[0];
}

function aquire_prog(id) {
	$.getJSON('/manga/progress?manga=' + id)
		.error(function() {
//			ualert('Request failed!');
		})
		.success(function(json) {
			var plate = $qs('#plate' + id);
			$(plate).find('.progress').html(json.progress.chap);
			$(plate).find('.chapters').html(json.progress.total);
			$(plate).find('.arch.total').html(json.arch.total);
			$(plate).find('.arch.new').html(json.arch.added);
			$(plate).find('.state').html(json.state);
			$(plate).find('.loading').hide();
		});
}

function arch_import(files, origin, listnode) {
	var total = 0;
	for (var i = 0; i < files.length; i++ ) {
		var file = files[i];
		$AJAX('/import/archive?target=' + origin.replace(/\&/g, '%26') + '&source=' + file.replace(/\&/g, '%26'), {
			listnode: listnode,
			onfail: function() {
				total++;
//				ualert('Request failed!');
			},
			onsuccess: function(ajax) {
				var r = ajax.response(), e = {result: 'err', msg: 'Parse fail:\n' + r};
				try {
					try {
						e = eval(r);
					} catch (x) {e = eval('a = ' + r)}
				} catch (x) {}
//				alert(toJSON(e));

				if (e.result == 'err') {
					ualert(e.msg);
					return;
				}
				total++;
				if (total >= files.length) {
					ualert('Done.');
					var listnode = ajax.listnode;
					while (listnode && (listnode.tagName != 'LI')) listnode = listnode.parentNode;
					if (listnode) {
						ln.className += " imported";
						var p = listnode.parentNode;
//						listnode.innerText = '';
//						p.removeChild(listnode);
					} else
						alert('ln not found');
				}
			}
		});
	}
}

var
	ML_OVER = [];

function build_ulist(file, u1, u2, matches) {
	nodes = file.parentNode;
	var opened = ML_OVER;
	ML_OVER = [];
	for (var i in opened) {
		var arr = opened[i], f = arr[0], div = arr[1];
		try {
			f.removeChild(div);
		} catch (e) {};
		if (f == nodes) return;
	}

	var div1 = document.createElement('DIV'), uls = [];// = document.createElement('ul');

	for (var i = 0; i < mangas.length; i++) {
		var m = mangas[i];
		if (!m) continue;
		var char = m.charAt(0).toUpperCase(), li = document.createElement('LI');
		if (char == '%')
			char = '&#' + parseInt('0x' + m.substr(1, 2));

		var title = m.replace(/([^a-zA-Z]?)([a-zA-Z])([a-zA-Z]*)/g, function(match, a, char, b){
			return a + char.toUpperCase() + b
		});
		title = title.replace(/(I[i]+)$/g, function(m, is){return is.toUpperCase()});
		title = title.replace(/\%([\da-f][\da-f])/ig, function(a, b) {return '&#' + parseInt('0x' + b) + ';';});

		var target = m.replace(/\&/g, '%26').replace(/\'/g, "\\'");
		li.setAttribute('_tgt', target);
		li.onclick = function (e) {
			e = e.srcElement || window.event.srcElement;
			if ((e.tagName != 'A') && (e.tagName != 'B')) return false;
			var target = e.getAttribute('ttarget') || e.parentNode.getAttribute('ttarget');
			build_ulist(file, u1, u2, matches);
			arch_import([files[u1][u2]], target, e);
		};

		if (matches.indexOf(parseInt(i)) >= 0)
			title = '<b>' + title + '</b>';

		li.innerHTML = '<a ttarget="' + target + '" href="javascript:void(0)">' + title + '</a>';

		if (!uls[char]) uls[char] = [];
		uls[char].push(li);
	}
	for (var j in uls) {
		var div2 = document.createElement('div'), ul = document.createElement('ul')
			, char = document.createElement('li');
		char.innerHTML = j;
		char.className = 'alpha';
		ul.appendChild(char);
		for (var i in uls[j])
			ul.appendChild(uls[j][i]);
		div2.appendChild(ul);
		div1.appendChild(div2);
	}
	div1.className = 'possibles';
	nodes.appendChild(div1);
	ML_OVER.push([nodes, div1]);
}