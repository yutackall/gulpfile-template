gulp         = require 'gulp'

async        = require 'async'
AWS          = require 'aws-sdk'
del          = require 'del'
glob         = require 'glob'
fs           = require 'fs'
_            = require 'lodash'
mime         = require 'mime'
sequence     = require 'run-sequence'

coffee       = require 'gulp-coffee'
imagemin     = require 'gulp-imagemin'
jade         = require 'gulp-jade'
livereload   = require 'gulp-livereload'
minifyHTML   = require 'gulp-minify-html'
pleeease     = require 'gulp-pleeease'
plumber      = require 'gulp-plumber'
rev          = require 'gulp-rev'
revReplace   = require 'gulp-rev-replace'
sass         = require 'gulp-sass'
uglify       = require 'gulp-uglify'
watch        = require 'gulp-watch'
wait         = require 'gulp-wait'

AWS.config.region = 'ap-northeast-1'
basePath = 'src/'
baseDestPath = 'public/'
paths =
  html:
    src:  basePath     + 'views/*.jade'
    dest: baseDestPath
  js:
    src:  basePath     + 'javascripts/**/*.coffee'
    dest: baseDestPath + 'assets/'
  css:
    src:  basePath     + 'stylesheets/**/*.sass'
    dest: baseDestPath + 'assets/'
  img:
    src:  basePath     + 'images/**/*'
    dest: baseDestPath + 'assets/'
  rev:
    src:  baseDestPath + 'assets/**/*.+(js|css|png|gif|jpg|jpeg|svg|woff|ico)'
    dest: baseDestPath + 'assets/'
  rev_replace:
    manifest: baseDestPath + 'assets/rev-manifest.json'
    src:  baseDestPath + '**/*.+(html|css|js)'
    dest: baseDestPath


gulp.task 'default', ['build']

gulp.task 'build', (cb) ->
  sequence 'clean', 'coffee', 'sass', 'optimizeImage', 'jade', 'rev', 'rev:replace', cb

gulp.task 'clean', (cb) ->
  del(["#{baseDestPath}/*"], cb)

gulp.task 'coffee', (f) =>
  gulp.src paths.js.src
    .pipe plumber()
    .pipe coffee()
    .pipe uglify()
    .pipe gulp.dest paths.js.dest

gulp.task 'jade', (f) ->
  gulp.src paths.html.src
    .pipe plumber()
    .pipe jade()
    .pipe minifyHTML()
    .pipe gulp.dest paths.html.dest

gulp.task 'optimizeImage', (f) ->
  gulp.src paths.img.src
    .pipe imagemin()
    .pipe gulp.dest paths.img.dest

gulp.task 'sass', (f) ->
  gulp.src paths.css.src
    .pipe plumber()
    .pipe sass()
    .pipe pleeease()
    .pipe gulp.dest paths.css.dest

gulp.task 'rev', (f) ->
  gulp.src paths.rev.src
    .pipe rev()
    .pipe gulp.dest paths.rev.dest
    .pipe rev.manifest()
    .pipe gulp.dest paths.rev.dest

gulp.task 'rev:replace', (f) ->
  manifest = gulp.src paths.rev_replace.manifest
  gulp.src paths.rev_replace.src
    .pipe revReplace manifest: manifest
    .pipe gulp.dest paths.rev_replace.dest

gulp.task 'livereload', ->
  gulp.src 'src', read: false
    .pipe wait(150)
    .pipe livereload()

gulp.task 'watch', ->
  livereload.listen()
  run = (tasks) ->
    tasks = _.toArray(arguments).concat(['livereload'])
    sequence.apply(@, tasks)
  watch "#{basePath}**/*", -> run 'build'

gulp.task 's3deploy', (cb) ->
  s3bucket = new AWS.S3(params: {Bucket: 'example.com'})
  s3bucket.createBucket ->
    glob "#{baseDestPath}/**/*", nodir: true, (err, files) ->
      tasks = _.map files, (file) ->
        (cb) ->
          fs.readFile file, (err, body) ->
            cb err if err
            params =
              ACL: 'public-read'
              Key: file.replace("#{baseDestPath}/",'')
              ContentType: mime.lookup file
              Body: body

            s3bucket.putObject params, (err, data) ->
              cb err, data

      async.series tasks, (err) ->
        cb err
