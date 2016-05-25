isFilePath = (name) ->
	return true if name[0] == '/'
	return true if name.substring(0, 2) == './'
	return true if name.substring(0, 3) == '../'
	return false

#fetchUrl = (url, method='GET') -> new Promise (accept, reject) ->
#	return fetchTextFromURL url.toString(), accept, reject

fetchUrl = (url) ->
	System.fetch do
		address: url.toString()
		metadata: {}
checkUrl = (url) -> fetchUrl url, 'HEAD'

resolvePackage = (pkg) ->
	fetchUrl joinPath pkg, "package.json"
	.then (data) ->
		# TODO: Figure out how to handle the
		# browser-field nicely
		main = JSON.parse(data).main ? 'index'
		if main[*-1] == '/'
			main += "index"
		return resolveFile joinPath(pkg, main)

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
		ppath = parentPath path
		while ppath.pathname.split('/')[*-1] == 'node_modules'
			ppath = parentPath ppath
		resolveNodeModule name, ppath

parentPath = (path) ->
	path = new URL path
	parts = path.pathname.split('/')
	parts = parts.filter (p) -> p not in ['', '.']
	if parts.length == 0
		throw new Error "No parent path for '#{path}'"
	parts.pop()
	path.pathname = parts.join '/'
	path.search = ''
	path.hash = ''
	return path

joinPath = (base, ...parts) ->
	base = new URL(base.toString!)
	parts = parts.filter (p) -> p not in ['', '.']
	if base.pathname[*-1] == '/'
		base.pathname = base.pathname.slice(0, -1)
	parts.unshift base.pathname
	base.pathname = parts.join '/'
	base.pathname = base.pathname.normalize()
	return base

builtins = void
if document?
	myPath = parentPath document.getElementsByTagName('script')[*-1].src
else
	myPath = parentPath "file://" + __filename

builtinsPath = joinPath myPath, 'node_modules/browser-builtins'
builtinsPromise = fetchUrl(joinPath(builtinsPath, 'package.json'))
	.then (data) ->
		conf = JSON.parse data
		builtins := conf.browser
	.then -> System.import("buffer")
	.then (buffer) ->
		if window?
			window.Buffer = buffer.Buffer


# See http://nodejs.org/docs/v0.4.8/api/all.html#all_Together...
nodeResolve = (...args) ->
	orig = Promise.resolve(promiseNodeResolve ...args)
	orig.then (path) ->
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
rawNodeResolve = (name, parent) ->
	if not parent?
		dir = new URL System.baseURL
	else
		dir = parentPath new URL parent
	if isFilePath name
		return resolvePath joinPath(dir, name)
	resolveNodeModule name, dir

memoize = (f) ->
	cache = {}
	(...args) ->
		key = JSON.stringify args
		if key of cache
			return cache[key]
		return cache[key] = f ...args

absURLRegEx = /^[^\/]+:\/\//

monkeypatch = (System) ->
	oldNormalize = System.normalize
	resolver = memoize nodeResolve
	normalize = (path, parent, isPlugin) ->
		if path.match absURLRegEx or path[0] == '@'
			return Promise.resolve(path)
		parts = path.split '!'
		[path, ...plugins] = parts
		# TODO: Should extend the existing normalization
		# instead of re-implementing here.
		if @map and path of @map
			path = @map[path]
		parent = parent?split("!")[0]
		resolver path, parent
		.then (normed) ->
			[normed].concat(plugins).join('!')
	# TODO: Should probably hook more nicely
	System.normalize = normalize

	System.normalizeSync = (name) ->
		# Seems to fix stuff, no idea why
		return name

if typeof module == 'object'
	module.exports = monkeypatch
else
	monkeypatch(System)
