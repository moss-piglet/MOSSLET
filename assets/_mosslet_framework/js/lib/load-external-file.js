/*
load(["file1", "file2", "file3"]).then(function () {
  // Callback that let you wait for loading completion !
});
*/

"use strict";

window.loadExternalFileCache ||= {
  cache: {},
  promises: [],
};

function getCache(key) {
  return window.loadExternalFileCache.cache[key];
}

function setCache(key, val) {
  return (window.loadExternalFileCache.cache[key] = val);
}

function getPromises() {
  return window.loadExternalFileCache.promises;
}

function pushPromise(promise) {
  window.loadExternalFileCache.promises.push(promise);
}

function parse(data) {
  if (typeof data == "string") {
    pushPromise(fetch(data));
  } else if (Array.isArray(data)) {
    for (let child of data) {
      parse(child);
    }
  }
}

function fetch(src) {
  if (getCache(src)) {
    return getCache(src);
  }
  let promise;
  let srcSplit = src.split(".");
  let fileType = srcSplit[srcSplit.length - 1];
  if (fileType == "css") {
    promise = loadCSS(src);
  } else {
    promise = append(newScript(src));
  }
  setCache(src, promise);
  return promise;
}

function append(script) {
  return new Promise(function (resolve, reject) {
    let loading = true;
    script.onerror = reject;
    script.onload = script.onreadystatechange = function () {
      if (
        loading &&
        (!script.readyState ||
          script.readyState == "loaded" ||
          script.readyState == "complete")
      ) {
        loading = false;
        script.onload = script.onreadystatechange = null;
        resolve(script);
      }
    };
    document.head.appendChild(script);
  });
}

function newScript(url) {
  let s = url.split(".");
  if (s[s.length - 1] != "js") {
    url += ".js";
  }
  let script = document.createElement("script");
  script.src = url;
  script.type = "text/javascript";
  script.async = false;
  return script;
}

function load(data) {
  parse(data);
  return Promise.all(getPromises());
}

function loadCSS(href) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`link[href='${href}']`)) {
      resolve();
    } else {
      const link = document.createElement("link");
      link.setAttribute("rel", "stylesheet");
      link.setAttribute("type", "text/css");
      link.setAttribute("href", href);
      document.head.appendChild(link);

      link.onload = resolve;
      link.onerror = reject;
    }
  });
}

export default load;