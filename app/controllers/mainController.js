const express = require("express")
const router = express.Router()

// Helpers for this controller/router

const render = function (response, view, locals) {
  response.render(["main", view].join("/") + ".html.pug", locals)
}

// Responses

const index = function (request, response) {
  render(response, "index", { currentVersion: "0.3.0" })
}

// Routes

router.get("/", index)

// Exports

module.exports = {
  index: index,
  router: router
}
