module.exports = (grunt) ->
  require("load-grunt-tasks") grunt
  require('time-grunt') grunt
  collapse = require('bundle-collapser/plugin')

  grunt.initConfig

    config:
      dev:
        options:
          variables:
            sourceDir: "src"
            destinationDir: "dev"
            env: "dev"

      prod:
        options:
          variables:
            sourceDir: "src"
            destinationDir: "prod"
            env: "prod"

    connect:
      options:
        port: 9000,
        hostname: "*"
        livereload: 35729
      livereload:
        options:
          base: ["<%= grunt.config.get('destinationDir') %>"]

    copy:
      assets:
        files: [
          expand: true
          flatten: true
          src: "<%= grunt.config.get('sourceDir') %>/assets/*"
          dest: "<%= grunt.config.get('destinationDir') %>/assets"
          filter: 'isFile'
        ]

    bowercopy:
      fonts:
        files:
          "<%= grunt.config.get('destinationDir') %>/fonts": "bootstrap/fonts/glyphicons-halflings-regular.*"

    bower_concat:
      docs:
        dest: "<%= grunt.config.get('destinationDir') %>/js/bower.js"
        mainFiles:
          "history.js": ["scripts/uncompressed/history.js", "scripts/uncompressed/history.adapter.jquery.js"]

    browserify:
      options:
        transform: ['coffee-reactify']
        plugin: [collapse]
      docs:
        files: [
          src: "<%= grunt.config.get('sourceDir') %>/cjsx/Main.cjsx"
          dest: "<%= grunt.config.get('destinationDir') %>/js/docs.js"
        ]

    uglify:
      options:
        mangle: true
        compress: {}
      bower:
        files:
          "<%= grunt.config.get('destinationDir') %>/js/bower.min.js": "<%= grunt.config.get('destinationDir') %>/js/bower.js"
      docs:
        files:
          "<%= grunt.config.get('destinationDir') %>/js/docs.min.js": "<%= grunt.config.get('destinationDir') %>/js/docs.js"

    less:
      docs:
        options:
          paths: ["<%= grunt.config.get('sourceDir') %>/less", "bower_components"]
        files:
          "<%= grunt.config.get('destinationDir') %>/css/docs.css": "<%= grunt.config.get('sourceDir') %>/less/docs.less"

    cssmin:
      docs:
        files: [
          expand: true
          cwd: "<%= grunt.config.get('destinationDir') %>/css"
          src: ["*.css", "!*.min.css"]
          dest: "<%= grunt.config.get('destinationDir') %>/css"
          ext: ".min.css"
        ]

    mustache_render:
      html:
        files: [
          data: "<%= grunt.config.get('sourceDir') %>/config/<%= grunt.config.get('env') %>.json"
          template: "<%= grunt.config.get('sourceDir') %>/mustache/index.mustache"
          dest: "<%= grunt.config.get('destinationDir') %>/index.html"
        ]
      markdown:
        files: [
          data: "<%= grunt.config.get('sourceDir') %>/config/<%= grunt.config.get('env') %>.json"
          template: "<%= grunt.config.get('sourceDir') %>/markdown/index.mustache"
          dest: "<%= grunt.config.get('destinationDir') %>/index.md"
        ]

    watch:
      coffee:
        files: [
          "<%= grunt.config.get('sourceDir') %>/**/*.cjsx"
          "<%= grunt.config.get('sourceDir') %>/**/*.js"
        ]
        tasks: ["config:<%= grunt.config.get('env') %>", 'browserify', 'uglify:docs']
        livereload: true
      mustache:
        files: [
          "<%= grunt.config.get('sourceDir') %>/**/*.mustache"
        ]
        tasks: ["config:<%= grunt.config.get('env') %>", "mustache_render"]
        livereload: true
      less:
        files: "<%= grunt.config.get('sourceDir') %>/**/*.less"
        tasks: ["config:<%= grunt.config.get('env') %>", "less", "cssmin"]
        livereload: true
      copy:
        files: "<%= grunt.config.get('sourceDir') %>/assets/*"
        tasks: ["config:<%= grunt.config.get('env') %>", "copy"]
        livereload: true

  grunt.registerTask "default", [
    "bower_concat"
    "browserify"
    "uglify"
    "less"
    "cssmin"
    "mustache_render"
    "copy"
    "bowercopy"
  ]

  grunt.registerTask "serve", (target) ->
    grunt.task.run [
      "config:dev"
      "default"
      "connect:livereload"
      "watch"
    ]

  return
