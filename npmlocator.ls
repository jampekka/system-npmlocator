``
  var isWorker = typeof window == 'undefined' && typeof self != 'undefined' && typeof importScripts != 'undefined';
  var isBrowser = typeof window != 'undefined' && typeof document != 'undefined';
  var isWindows = typeof process != 'undefined' && !!process.platform.match(/^win/);
  var fetchTextFromURL;
  if (typeof XMLHttpRequest != 'undefined') {
    fetchTextFromURL = function(url, fulfill, reject) {
      // percent encode just '#' in urls
      // according to https://github.com/jorendorff/js-loaders/blob/master/browser-loader.js#L238
      // we should encode everything, but it breaks for servers that don't expect it
      // like in (https://github.com/systemjs/systemjs/issues/168)
      if (isBrowser)
        url = url.replace(/#/g, '%23');

      var xhr = new XMLHttpRequest();
      var sameDomain = true;
      var doTimeout = false;
      if (!('withCredentials' in xhr)) {
        // check if same domain
        var domainCheck = /^(\w+:)?\/\/([^\/]+)/.exec(url);
        if (domainCheck) {
          sameDomain = domainCheck[2] === window.location.host;
          if (domainCheck[1])
            sameDomain &= domainCheck[1] === window.location.protocol;
        }
      }
      if (!sameDomain && typeof XDomainRequest != 'undefined') {
        xhr = new XDomainRequest();
        xhr.onload = load;
        xhr.onerror = error;
        xhr.ontimeout = error;
        xhr.onprogress = function() {};
        xhr.timeout = 0;
        doTimeout = true;
      }
      function load() {
        fulfill(xhr.responseText);
      }
      function error() {
        reject(xhr.statusText + ': ' + url || 'XHR error');
      }

      xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
          if (xhr.status === 200 || (xhr.status == 0 && xhr.responseText)) {
            load();
          } else {
            error();
          }
        }
      };
      xhr.open("GET", url, true);

      if (doTimeout)
        setTimeout(function() {
          xhr.send();
        }, 0);

      xhr.send(null);
    };
  }
  else if (typeof require != 'undefined') {
    var fs;
    fetchTextFromURL = function(url, fulfill, reject) {
      if (url.substr(0, 8) != 'file:///')
        throw 'Only file URLs of the form file:/// allowed running in Node.';
      fs = fs || require('fs');
      if (isWindows)
        url = url.replace(/\//g, '\\').substr(8);
      else
        url = url.substr(7);
      return fs.readFile(url, function(err, data) {
        if (err)
          return reject(err);
        else {
          // Strip Byte Order Mark out if it's the leading char
          var dataString = data + '';
          if (dataString[0] === '\ufeff')
            dataString = dataString.substr(1);

          fulfill(dataString);
        }
      });
    };
  }
  else {
    throw new TypeError('No environment fetch API available.');
  }
``

isFilePath = (name) ->
	return true if name[0] == '/'
	return true if name.substring(0, 2) == './'
	return true if name.substring(0, 3) == '../'
	return false

fetchUrl = (url, method='GET') -> new Promise (accept, reject) ->
	return fetchTextFromURL url.toString(), accept, reject
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
	base = new URL base
	parts = parts.filter (p) -> p not in ['', '.']
	if base.pathname[*-1] == '/'
		base.pathname = base.pathname.slice(0, -1)
	parts.unshift base.pathname
	base.pathname = parts.join '/'
	base.pathname = base.pathname.normalize()
	return base

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

# TODO: Should probably hook more nicely
oldNormalize = System.normalize
normalize = memoize (path, parent) ->
	oargs = arguments
	parts = path.split '!'
	[path, ...plugins] = parts
	# TODO: Should extend the existing normalization
	# instead of re-implementing here.
	if System.map and path of System.map
		path = System.map[path]
	parent = parent?split("!")[0]
	nodeResolve path, parent
	.then (normed) ->
		result = [normed].concat(plugins).join("!")
		return result
System.normalize = (path, parent) -> normalize path, parent
