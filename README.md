# Nodejs module resolution for SystemJS

Use SystemJS like browserify, but without the compile step.

## WARNING

Not very well tested, but seems to work in a real world project
with a lot of dependencies from npm.

Will spam the console with failed HTTP requests during module
resolution, as they can't be suppressed. For a workaround at least chromium
allows for hiding network errors. Ideas how to work around
this would be very welcome.

## Install

    npm install jampekka/system-npmlocator

## Quickstart

Install SystemJS and this package:

    npm install systemjs
    npm install jampekka/system-npmlocator

Install jquery using npm:

    npm install jquery

Create a following `index.html`:
```html
<script src="node_modules/systemjs/dist/system.js"></script>
<script src="node_modules/system-npmlocator/npmlocator.js"></script>
<script>
// Now any npm-installed packages can be used just like
// with node/browserify
System.import('jquery').then(function($) {
    $(function() {
        $("body").text("Hello from jQuery via npm!");
    });
});
</script>
```

And open it in a browser, eg:
    
    chromium --allow-file-access-from-files index.html

## Full example

See http://github.com/jampekka/system-npmlocator-example

