// Generated by LiveScript 1.3.1
(function(){
  var isFilePath, fetchUrl, checkUrl, resolvePackage, resolveFileUrl, resolveFile, resolvePath, resolveNodeModule, parseUrl, parentPath, normalizePath, joinPath, builtins, myPath, ref$, builtinsPath, builtinsPromise, nodeResolve, promiseNodeResolve, doNodeResolve, rawNodeResolve, oldNormalize, slice$ = [].slice;
  isFilePath = function(name){
    if (name[0] === '/') {
      return true;
    }
    if (name.substring(0, 2) === './') {
      return true;
    }
    if (name.substring(0, 2) === '../') {
      return true;
    }
    return false;
  };
  fetchUrl = function(url){
    return new Promise(function(accept, reject){
      var req;
      req = new XMLHttpRequest;
      req.onload = function(){
        return accept(req.responseText);
      };
      req.onerror = function(){
        reject(req.statusText);
        return false;
      };
      req.open('GET', url, true);
      return req.send(null);
    });
  };
  checkUrl = function(url){
    return new Promise(function(accept, reject){
      var req;
      req = new XMLHttpRequest;
      req.onload = function(){
        return accept(req.responseText);
      };
      req.onerror = function(e){
        window.debugstuff = {
          e: e,
          req: req
        };
        return reject(req.statusText);
      };
      req.open('HEAD', url, true);
      return req.send(null);
    });
  };
  resolvePackage = function(pkg){
    return fetchUrl(pkg + "/package.json").then(function(data){
      var main, ref$;
      main = (ref$ = JSON.parse(data).main) != null ? ref$ : 'index';
      if (main[main.length - 1] === '/') {
        main += "index";
      }
      return resolveFile(pkg + "/" + main);
    });
  };
  resolveFileUrl = function(url){
    return checkUrl(url).then(function(){
      return url;
    });
  };
  resolveFile = function(path){
    return resolveFileUrl(path)['catch'](function(){
      return resolveFileUrl(path + ".js");
    });
  };
  resolvePath = function(path){
    return resolvePackage(path)['catch'](function(){
      return resolveFile(path);
    });
  };
  resolveNodeModule = function(name, path){
    path == null && (path = '');
    return resolvePackage(joinPath(path, 'node_modules', name))['catch'](function(){
      var parts;
      parts = path.split('/');
      parts.pop();
      while (parts[parts.length - 1] === 'node_modules') {
        parts.pop();
      }
      if (parts.length === 0) {
        throw "Node module '" + name + "' at '" + path + "' not found";
      }
      return resolveNodeModule(name, joinPath.apply(null, parts));
    });
  };
  parseUrl = function(url){
    var parser;
    parser = document.createElement('a');
    parser.href = url;
    return parser;
  };
  parentPath = function(path){
    var parsed, pathname, parts;
    if (!path) {
      return '.';
    }
    parsed = parseUrl(path);
    pathname = parsed.pathname;
    parts = pathname.split('/');
    parts.pop();
    parsed.pathname = parts.join('/');
    return parsed.href;
  };
  normalizePath = function(path){
    var parsed, pathname, ref$, parts, root;
    parsed = parseUrl(path);
    pathname = (ref$ = parsed.pathname) != null ? ref$ : '';
    parts = parsed.pathname.split('/');
    root = parts.shift();
    parts = parts.filter(function(p){
      return p !== '' && p !== '.';
    });
    parts.unshift(root);
    parsed.pathname = parts.join('/');
    return parsed.href;
  };
  joinPath = function(){
    var parts;
    parts = slice$.call(arguments);
    parts = parts.filter(function(p){
      return p !== '' && p !== '.';
    });
    return parts.join('/');
  };
  builtins = void 8;
  myPath = parentPath((ref$ = document.getElementsByTagName('script'))[ref$.length - 1].src);
  builtinsPath = joinPath(myPath, 'node_modules/browser-builtins');
  builtinsPromise = fetchUrl(joinPath(builtinsPath, 'package.json')).then(function(data){
    var conf;
    conf = JSON.parse(data);
    return builtins = conf.browser;
  }).then(function(){
    return System['import']("buffer");
  }).then(function(buffer){
    return window.Buffer = buffer.Buffer;
  });
  nodeResolve = function(){
    var args, orig;
    args = slice$.call(arguments);
    orig = Promise.resolve(promiseNodeResolve.apply(null, args));
    return orig.then(function(path){
      path = normalizePath(path);
      return path;
    });
  };
  promiseNodeResolve = function(){
    var args;
    args = slice$.call(arguments);
    if (builtins == null) {
      return builtinsPromise.then(function(){
        return doNodeResolve.apply(null, args);
      });
    }
    return doNodeResolve.apply(null, args);
  };
  doNodeResolve = function(name, parent){
    if (name in builtins) {
      return rawNodeResolve(builtins[name], joinPath(builtinsPath, 'dummy'));
    }
    return rawNodeResolve(name, parent);
  };
  rawNodeResolve = function(name, parent){
    var dir;
    parent == null && (parent = '');
    dir = parentPath(normalizePath(parent));
    if (isFilePath(name)) {
      return resolvePath(joinPath(dir, name));
    }
    return resolveNodeModule(name, dir);
  };
  oldNormalize = System.normalize;
  System.normalize = function(path, parent){
    var parts;
    parent = parent != null ? parent.split("!")[0] : void 8;
    parts = path.split('!');
    return nodeResolve(parts[0], parent).then(function(normed){
      return [normed].concat(parts.slice(1)).join("!");
    });
  };
}).call(this);
