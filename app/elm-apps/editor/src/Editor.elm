port module Editor exposing (..)

import Html exposing (Html, div, text, textarea, button, iframe)
import Html.Attributes exposing (style, class, value, src, width, height)
import Html.Events exposing (onInput, onClick)
import Json.Encode
import Json.Decode
import WebSocket


-- Entry point


main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Flags =
    { id : String
    , ws : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { initialModel
        | liveCodeId = flags.id
        , websocketHost = flags.ws
      }
    , setLiveCodeId flags.ws flags.id
    )



-- Port methods


port refreshFrames : () -> Cmd msg



-- Helpers


setLiveCodeId : String -> String -> Cmd Msg
setLiveCodeId websocketHost liveCodeId =
    let
        payload : String
        payload =
            Json.Encode.encode 0 <|
                Json.Encode.object
                    [ ( "action", Json.Encode.string "set" )
                    , ( "id", Json.Encode.string liveCodeId )
                    ]
    in
        WebSocket.send websocketHost (Debug.log "setLiveCodeId" payload)


compileLiveCode : String -> String -> Cmd Msg
compileLiveCode websocketHost source =
    let
        payload : String
        payload =
            Json.Encode.encode 0 <|
                Json.Encode.object
                    [ ( "action", Json.Encode.string "compile" )
                    , ( "source", Json.Encode.string source )
                    ]
    in
        WebSocket.send websocketHost (Debug.log "setLiveCodeId" payload)

-- Models


type alias Model =
    { liveCodeId : String
    , websocketHost : String
    , source : String
    , compiled : String
    , canCompile : Bool
    }


initialModel : Model
initialModel =
    { liveCodeId = ""
    , websocketHost = ""
    , source = ""
    , compiled = ""
    , canCompile = False
    }



-- Update


type Msg
    = BeginCompile
    | Incoming String
    | SourceChanged String


type IncomingMsg
    = Source String
    | Compiled
    | Error String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BeginCompile ->
            ( { model | canCompile = False }
            , compileLiveCode model.websocketHost model.source
            )

        Incoming json ->
            let
                action : String
                action =
                    Json.Decode.decodeString (Json.Decode.field "action" Json.Decode.string) json
                        |> Result.withDefault ""
                        |> Debug.log "Incoming"

                incomingMsg : IncomingMsg
                incomingMsg =
                    if action == "source" then
                        let
                            source : String
                            source =
                                Json.Decode.decodeString (Json.Decode.field "source" Json.Decode.string) json
                                    |> Result.withDefault ""
                        in
                            Source source
                    else if action == "compiled" then
                        Compiled
                    else
                        Error "unknown message action"
            in
                case incomingMsg of
                    Source code ->
                        ( { model | source = code }
                        , Cmd.none
                        )

                    Compiled ->
                        ( model
                        , refreshFrames ()
                        )

                    Error output ->
                        ( model
                        , Cmd.none
                        )

        SourceChanged newSource ->
            ( { model | source = newSource, canCompile = True }
            , Cmd.none
            )



-- View


view : Model -> Html Msg
view model =
    div
        []
        [ div
            []
            [ textarea
                [ value model.source
                , onInput SourceChanged
                , class "editor"
                ]
                []
            ]
        , button [ onClick BeginCompile ] [ text "Compile" ]
        , div [] [ text "Compiled Output" ]
        , iframe
            [ src ("/live/" ++ model.liveCodeId ++ "/compiled")
            , width "100%"
            , height "600px"
            ]
            []
        ]



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen (Debug.log "websocketHost" model.websocketHost) Incoming
        ]
