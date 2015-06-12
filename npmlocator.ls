isFilePath = (name) ->
	return true if name[0] == '/'
	return true if name.substring(0, 2) == './'
	return true if name.substring(0, 2) == '../'
	return false

fetchUrl = (url) -> new Promise (accept, reject) ->
	req = new XMLHttpRequest
	req.onload = -> accept req.responseText
	req.onerror = (...a) -> reject(req.statusText)
	req.open 'GET', url, true
	req.send null

checkUrl = (url) -> new Promise (accept, reject) ->
	req = new XMLHttpRequest
	req.onload = -> accept(req.responseText)
	req.onerror = (e) -> reject(req.statusText)
	req.open 'HEAD', url, true
	req.send null

resolvePackage = (pkg) ->
	fetchUrl pkg + "/package.json"
	.then (data) ->
		# TODO: Figure out how to handle the
		# browser-field nicely
		main = JSON.parse(data).main ? 'index'
		if main[*-1] == '/'
			main += "index"
		return resolveFile pkg + "/" + main

resolveFileUrl = (url) ->
	checkUrl url .then -> url

resolveFile = (path) ->
	resolveFileUrl path
	.catch -> resolveFileUrl path + ".js"

resolvePath = (path) ->
	# We can't check for directories over HTTP, so
	# check first for <path>/package.json and after that
	# try to open it as a file. According to the spec
	# this should be done another way around, but this
	# probably won't be a problem in practice.
	resolvePackage path
	.catch -> resolveFile path

resolveNodeModule = (name, path='') ->
	resolvePackage joinPath path, 'node_modules', name
	.catch ->
		# TODO: Probably breaks with URLs
		parts = path.split('/')
		parts.pop()
		while parts[*-1] == 'node_modules'
			parts.pop()
		if parts.length == 0
			throw "Node module '#{name}' at '#{path}' not found"
		resolveNodeModule name, joinPath ...parts
parseUrl = (url) ->
	parser = document.createElement 'a'
	parser.href = url
	return parser

parentPath = (path) ->
	if not path
		return '.'
	parsed = parseUrl path
	pathname = parsed.pathname

	parts = pathname.split('/')
	parts.pop()
	parsed.pathname = parts.join '/'
	return parsed.href

normalizePath = (path) ->
	# TODO: Handle ..
	parsed = parseUrl path
	pathname = parsed.pathname ? ''
	parts = parsed.pathname.split '/'
	root = parts.shift()
	parts = parts.filter (p) -> p not in ['', '.']
	parts.unshift root
	parsed.pathname = parts.join '/'
	return parsed.href

joinPath = (...parts) ->
	parts = parts.filter (p) -> p not in ['', '.']
	return parts.join '/'

builtins = void
myPath = parentPath document.getElementsByTagName('script')[*-1].src
builtinsPath = joinPath myPath, 'node_modules/browser-builtins'
builtinsPromise = fetchUrl(joinPath(builtinsPath, 'package.json'))
	.then (data) ->
		conf = JSON.parse data
		builtins := conf.browser
	.then -> System.import("buffer")
	.then (buffer) ->
		window.Buffer = buffer.Buffer


# See http://nodejs.org/docs/v0.4.8/api/all.html#all_Together...
nodeResolve = (...args) ->
	orig = Promise.resolve(promiseNodeResolve ...args)
	orig.then (path) ->
		path = normalizePath path
		return path
promiseNodeResolve = (...args) ->
	# A wrapper where we make sure that we have our async loaded config
	if not builtins?
		return builtinsPromise.then ->
			doNodeResolve ...args
	return doNodeResolve ...args
doNodeResolve = (name, parent) ->
	if name of builtins
		return rawNodeResolve builtins[name], joinPath(builtinsPath, 'dummy')
	return rawNodeResolve name, parent
rawNodeResolve = (name, parent='') ->
	dir = parentPath normalizePath parent
	if isFilePath name
		return resolvePath joinPath(dir, name)
	resolveNodeModule name, dir

# TODO: Should probably hook more nicely
oldNormalize = System.normalize
System.normalize = (path, parent) ->
	parent = parent?split("!")[0]
	parts = path.split '!'
	nodeResolve parts[0], parent
	.then (normed) ->
		[normed].concat(parts.slice(1)).join("!")


