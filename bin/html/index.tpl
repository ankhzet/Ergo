<html>
	<head>
		<meta http-equiv="content-type" content="text/html; charset=utf-8;" />
		<title>{%title%}</title>
		<link rel="stylesheet" href="/theme/css/style.css" type="text/css" media="screen" />
		<script src="/theme/js/jquery.js"></script>
		<script src="/theme/js/utils.js"></script>
	</head>
	<body>
		<div class="tooltip"></div>
{%inc{sidebar}}
		<div class="platesholder">
			<div class="plates">
{%content%}
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