const express = require("express")
const path = require("path")

// Constants

const port = process.env.PORT || 8000

// Express

const app = express()

app.set("port", port)
app.set("view engine", "pug")
app.set("views", path.resolve(__dirname, "app", "views"))
app.locals.basedir = path.resolve(__dirname, "app")

// Middleware

if (process.env.NODE_ENV != "production") {
  const applyDevMiddleware = require("./lib/server/development.js")

  applyDevMiddleware(app)
}

app.use(express.static("./public"))

// Controllers

const mainController = require("./app/controllers/mainController.js")

app.get("/", mainController.index)
app.use("/main", mainController.router)

// Entry Point

app.listen(app.get("port"), function () {
  console.log("ExpressJS started on port %d", app.get("port"))
})
