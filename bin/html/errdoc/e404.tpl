<html>
	<head>
		<meta http-equiv="content-type" content="text/html; charset=utf-8;" />
		<title>404 - Not Found</title>
		<link rel="stylesheet" href="/theme/css/style.css" type="text/css" media="screen" />
		<script src="/theme/js/toolkit.js"></script>
		<script src="/theme/js/utils.js"></script>
	</head>
	<body>
{%inc{sidebar}}
		<div class="platesholder">
			<div class="plates">
				<h1>404 - Not Found</h1>
				<p />Specified resource <i>{%server[uri]%}</i> can't be found on this server
				<p />Return to <a href="/">main</a> page.
				<p /><hr><img src="/favicon.ico" style="position: relative; top: 3px;"><small><i>Clone HTTP server v1.01</i></small>
			</div>
		</div>
		<div class="footer">
			<ul>
				<li><a href="/">Main</a></li>
				<li><a href="/static/about">About</a></li>
			</ul>
		</div>
	</body>
</html>