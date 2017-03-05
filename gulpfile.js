const gulp = require("gulp")
const elm = require("gulp-elm")
const plumber = require("gulp-plumber")
const path = require("path")

gulp.task("elm-init", elm.init)

const editor = buildProject("build-editor", "app/elm-apps/editor", "editor.js")
editor.task()

gulp.task("default", ["build-editor"], function () {
  editor.watch()
})


function buildProject(name, sourcePath, target) {
  process.chdir(sourcePath)
  return {
    task: function () {
      gulp.task(name, ["elm-init"], function () {
        return gulp.src("src/**/*.elm")
          .pipe(plumber())
          .pipe(elm.bundle(target))
          .pipe(gulp.dest(path.resolve(__dirname, "public", "scripts")))
      })
    },
    watch: function () {
      gulp.watch([path.resolve(__dirname, sourcePath, "**/*.elm")], [name])
    }
  }
}
