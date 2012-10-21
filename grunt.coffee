module.exports = (grunt) ->
  grunt.initConfig
    coffee:
      compile:
        files:
          "public/js/modules/*.js": "src/coffee/**/*.coffee"

        options:
          flatten: false
          bare: false

    jade:
      compile:
        files:
          "public/index.html": "src/jade/index.jade"

    stylus:
      compile:
        files:
          "public/css/styles.css": "src/stylus/*.styl"

        options:
          compress: true

    server:
      port: 8000
      base: "public"

    watch:
      coffee:
        files: ["src/coffee/**/*.coffee"]
        tasks: ["coffee", "reload"]

      stylus:
        files: ["src/stylus/*.styl"]
        tasks: ["stylus", "reload"]

      jade:
        files: ["src/jade/*.jade"]
        tasks: ["jade", "reload"]

    reload:
      port: 6001
      proxy:
        host: 'localhost'
        port: 8000

  grunt.loadNpmTasks "grunt-reload"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-jade"
  grunt.loadNpmTasks "grunt-contrib-stylus"

  grunt.registerTask "default", "coffee jade stylus server reload watch"
