const express = require("express")
const http = require("http")
const WebSocket = require("ws")
const url = require("url")
const path = require("path")
const fs = require("fs")
const Moniker = require("moniker")
const rimraf = require("rimraf")
const ncp = require("ncp").ncp
const elm = require("node-elm-compiler")


// Constants


const liveCodesFolder = path.resolve(__dirname, "temp")
const idGenerator = Moniker.generator([Moniker.adjective, Moniker.adjective, Moniker.noun])
const port = process.env.NODE_ENV == "development" ? 8080 : (process.env.PORT || 5000)
const wsHost = process.env.NODE_ENV == "development" ? "localhost" : "elm-canvas.io"
const cleanupTimeout = 1000 * 60 * 5
const maxLiveCodeLife = 1000 * 60 * 60 * 24 * 7


// Express


const app = express()

app.set("port", port)
app.set("view engine", "pug")
app.set("views", path.resolve(__dirname, "app/views"))
app.use(express.static("public"))

app.get("/live/new", function (req, res) {
  const origin = path.resolve(__dirname, "app", "liveCodeTemplate")

  newLiveCodeFrom(origin, function (id, path) {
    res.redirect("/live/" + id)
  })

})

app.get("/live/:liveId/clone", function (req, res) {
  const oldId = req.params.liveId

  if (validateLiveCodeId(oldId)) {
    const origin = path.resolve(liveCodesFolder, oldId)

    newLiveCodeFrom(origin, function (id, liveCode) {
      res.redirect("/live/" + id)
    })

  } else {
    res.send({ error: "Cannot clone a live code that doesn't exist." })
  }
})

app.get("/live/:liveId/compiled", function (req, res) {
  const id = req.params.liveId

  if (validateLiveCodeId(id)) {
    const origin = path.resolve(liveCodesFolder, id)

    res.sendFile(path.resolve(liveCodesFolder, id, "entry.html"))
  } else {
    res.send({ error: "Cannot load a live code that doesn't exist." })
  }
})

app.get("/live/:liveId", function (req, res) {
  const id = req.params.liveId
  if (validateLiveCodeId(id)) {
    res.render("liveCode/show.html.pug", { id: id, ws: "ws://" + wsHost + ":" + port })
  } else {
    res.send({ error: "Live code does not exist" })
  }
})


// Websockets


const server = http.createServer(app)
const wss = new WebSocket.Server({ server })

wss.on("connection", function (client) {
  const location = url.parse(client.upgradeReq.url, true)

  client.on("message", function (payloadStr) {
    console.log("Client message", payloadStr)
    let payload = JSON.parse(payloadStr)

    switch (payload.action) {
      case "set":
        client.__liveCodeId = payload.id

        if (!isLiveCodeLocked(payload.id)) {
          client.__hasLock = lockLiveCode(payload.id)
        } else {
          client.__hasLock = false
        }

        sendLiveCodeSource(client)
        break;

      case "compile":
        if (client.__hasLock && validateLiveCodeId(client.__liveCodeId)) {
          fs.writeFile(path.resolve(liveCodesFolder, client.__liveCodeId, "src", "Entry.elm"), payload.source, function () {
            compileLiveCode (client.__liveCodeId, function (error, exitCode) {
              console.log("compile.exitCode", exitCode)
              if (error) {
                client.send(JSON.stringify({ action: "error" }))
              } else {
                client.send(JSON.stringify({ action: "compiled" }))
              }
            })
          })
        }
        break;
    }
  })

  client.on("close", function () {
    console.log("connection.close")
    if (client.__hasLock) {
      unlockLiveCode(client.__liveCodeId)
    }
  })
})

// Setup


onInit()


// Util


function onInit () {
  fs.mkdir(liveCodesFolder, 0o777, function () {
    unlockAll()
    server.listen(8080, function () {
      console.log("Server listening on port %d", server.address().port)
      onCleanup()
    })
  })
}

function onCleanup () {
  fs.readdir(liveCodesFolder, function (err, contents) {
    if (err) {
      console.error("onCleanup.fail:", err)
    } else {
      contents.forEach(function (contentPath) {
        if (contentPath.substr(0, 1) != ".") {
          try {
            let stat = fs.statSync(path.resolve(liveCodesFolder, contentPath, "src", "Entry.elm"))
            let lastModified = stat.mtime.getTime()
            if (Date.now() > (lastModified + maxLiveCodeLife)) {
              rimraf(path.resolve(liveCodesFolder, contentPath), function () {
                console.log("onCleanup.success (id=%s)", contentPath)
              })
            }
          } catch (e) {
            // ...
          }
        }
      })
    }
  })
  setTimeout(onCleanup, cleanupTimeout)
}

function unlockAll () {
  fs.readdir(liveCodesFolder, function (err, contents) {
    if (err) {
      console.error("onCleanup.fail:", err)
    } else {
      contents.forEach(function (contentPath) {
        let lockFile = path.resolve(liveCodesFolder, contentPath, ".locked")
        let stat = fs.statSync(lockFile)
        if (stat.isFile()) {
          fs.unlink(lockFile)
        }
      })
    }
  })
}

function validateLiveCodeId (id) {
  if (/[^\/\.\s]/.test(id)) {
    let stat = fs.statSync(path.resolve(liveCodesFolder, id))
    return stat.isDirectory()
  } else {
    return false
  }
}

function newLiveCodeFrom (origin, done) {
  var id = idGenerator.choose()
  let dest = path.resolve(liveCodesFolder, id)
  ncp(origin, dest, { clobber: false }, function (err) {
    if (err) {
      console.error("newLiveCodeFrom.fail (origin=%s, newId=%s): %s", origin, id, err)
    } else {
      done(id, dest)
    }
  })
}

function isLiveCodeLocked (id) {
  try {
    let stat = fs.statSync(path.resolve(liveCodesFolder, id, ".locked"))
    return stat.isFile()
  } catch (e) {
    return false
  }
}

function lockLiveCode (id) {
  if (isLiveCodeLocked(id)) {
    return false
  } else {
    fs.writeFileSync(path.resolve(liveCodesFolder, id, ".locked"), "", { encoding: "utf8" })
    return isLiveCodeLocked(id)
  }
}

function unlockLiveCode (id) {
  if (isLiveCodeLocked(id)) {
    fs.unlinkSync(path.resolve(liveCodesFolder, id, ".locked"))
  }
}

function compileLiveCode (id, done) {
  elm.compile(
    ["src/Entry.elm"],
    {
      cwd: path.resolve(liveCodesFolder, id),
      yes: true,
      output: "entry.html"
    }
  ).on("close", function (exitCode) {
    done(null, exitCode)
  }).on("error", function (output) {
    done(output, -1)
  })
}

function sendLiveCodeSource (client) {
  let id = client.__liveCodeId
  console.log("sendLiveCodeSource (id=%s)", id)

  if (validateLiveCodeId(id)) {
    fs.readFile(path.resolve(liveCodesFolder, id, "src", "Entry.elm"), { encoding: "utf8" }, function (err, raw) {
      if (err) {
        console.error("sendLiveCodeSource.fail (id=%s): %s", id, err)
      } else {
        console.log("sendLiveCodeSource.success (id=%s)", id)
        client.send(JSON.stringify({ action: "source", source: raw, lock: client.__hasLock }))
      }
    })
  } else {
    console.error("sendLiveCodeSource.fail (id=%s): %s", id, "Unable to find live code id")
  }
}
