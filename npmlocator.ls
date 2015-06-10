isFilePath = (name) ->
	return true if name[0] == '/'
	return true if name.substring(0, 2) == './'
	return true if name.substring(0, 2) == '../'
	return false

fetchUrl = (url) -> new Promise (accept, reject) ->
	req = new XMLHttpRequest
	req.onload = -> accept req.responseText
	req.onerror = -> reject(req.statusText); return false
	req.open 'GET', url, true
	req.send null

checkUrl = (url) -> new Promise (accept, reject) ->
	req = new XMLHttpRequest
	req.onload = -> accept(req.responseText)
	req.onerror = (e) ->
		window.debugstuff =
			e: e
			req: req
		reject(req.statusText)
	req.open 'HEAD', url, true
	req.send null

resolvePackage = (pkg) ->
	fetchUrl pkg + "/package.json"
	.then (data) ->
		main = JSON.parse(data).main ? 'index'
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
		parts = path.split('/')
		parts.pop()
		while parts[*-1] == 'node_modules'
			parts.pop()
		if parts.length == 0
			throw "Node module not found"
		resolveNodeModule name, joinPath ...parts

dirname = (path) ->
	if not path
		return ''
	parts = path.split('/')
	return parts.slice(0, -1).join('/')

normalizePath = (path) ->
	# TODO: Handle ..
	parts = path.split '/'
	root = parts[0]
	parts = parts.filter (p) -> p not in ['', '.']
	parts.unshift root
	return parts.join '/'

joinPath = (...parts) ->
	parts = parts.filter (p) -> p not in ['', '.']
	return parts.join '/'

# See http://nodejs.org/docs/v0.4.8/api/all.html#all_Together...
nodeResolve = (name, parent='') ->
	dir = dirname normalizePath parent
	if isFilePath name
		return resolvePath joinPath(dir, name)
	resolveNodeModule name, dir

oldNormalize = System.normalize
System.normalize = (...args) ->
	return nodeResolve ...args


