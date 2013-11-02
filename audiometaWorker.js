(function() {
  "use strict";
  angular.module("audiometaWorker", []).factory("AudioParserWorker", [
    "$timeout", "$q", function($timeout, $q) {
      return {
        getInfo: function(file, strategies) {
          var deferred, timer, worker;
          if (strategies == null) {
            strategies = ["MP3", "WAV", "AIFF"];
          }
          deferred = $q.defer();
          timer = $timeout(function() {
            return deferred.reject();
          }, 5000);
          worker = new Worker("/scripts/worker.js");
          worker.addEventListener("message", function(e) {
            deferred.resolve(e.data);
            return $timeout.cancel(timer);
          });
          worker.postMessage({
            file: file,
            strategies: strategies
          });
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);
