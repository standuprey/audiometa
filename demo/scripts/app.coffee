"use strict"
angular.module("audiometaDemo", ["audiometaWorker", "audiometa", "ngRoute"]).config ($routeProvider) ->
  $routeProvider.when("/",
    templateUrl: "views/main.html"
    controller: "MainCtrl"
  ).otherwise redirectTo: "/"
