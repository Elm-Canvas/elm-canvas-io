const sassMiddleware = require("node-sass-middleware")
const path = require("path")

const appRoot = path.resolve(__dirname, "..", "..")

module.exports = function (app) {
  app.use(
    sassMiddleware({
      src: path.resolve(appRoot, "app", "assets", "styles"),
      dest: path.resolve(appRoot, "public"),
      prefix: "/assets",
      debug: true,
      indentedSyntax: true,
      force: true
    })
  )
}
