port module Editor exposing (..)

import Html exposing (Html, div, text, textarea, button, iframe, span)
import Html.Attributes exposing (style, class, value, src)
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
    , currentView : View
    , status : String
    , hasLocked : Bool
    }


type View
    = Code
    | Output


initialModel : Model
initialModel =
    { liveCodeId = ""
    , websocketHost = ""
    , source = ""
    , compiled = ""
    , canCompile = False
    , currentView = Code
    , status = "OK"
    }



-- Update


type Msg
    = BeginCompile
    | Refresh
    | Incoming String
    | SourceChanged String
    | SetCurrentView View


type IncomingMsg
    = Source String Bool
    | Compiled
    | Error String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BeginCompile ->
            ( { model | status = "Compiling" }
            , compileLiveCode model.websocketHost model.source
            )

        Refresh ->
            ( model
            , refreshFrames ()
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

                            hasLock : Bool
                            hasLock =
                                Json.Decode.decodeString (Json.Decode.field "lock" Json.Decode.bool) json
                                    |> Result.withDefault ""
                        in
                            Source source hasLock
                    else if action == "compiled" then
                        Compiled
                    else if action == "error" then
                        Error "Compilation failed"
                    else
                        Error "Unknown message action"
            in
                case incomingMsg of
                    Source source locked ->
                        ( { model | source = source, hasLock = locked, status = "OK" }
                        , Cmd.none
                        )

                    Compiled ->
                        ( { model | status = "OK" }
                        , refreshFrames ()
                        )

                    Error output ->
                        ( { model | status = "Error" }
                        , Cmd.none
                        )

        SourceChanged newSource ->
            ( { model | source = newSource, status = "OK" }
            , Cmd.none
            )

        SetCurrentView currentView ->
            ( { model | currentView = currentView }
            , Cmd.none
            )



-- View


view : Model -> Html Msg
view model =
    div
        []
        [ div
            [ class "editor" ]
            [ viewControls model
            , viewTextArea model
            ]
        , viewOutput model
        ]


viewControls : Model -> Html Msg
viewControls model =
    let
        currentViewButton : Html Msg
        currentViewButton =
            if model.currentView == Code then
                button [ onClick (SetCurrentView Output) ] [ text "Show Output" ]
            else
                button [ onClick (SetCurrentView Code) ] [ text "Show Code" ]

        mainActionButton : Html Msg
        mainActionButton =
            if model.hasLock then
                button [ onClick BeginCompile ] [ text "Compile" ]
            else
                button [ onClick Refresh ] [ text "Refresh Output" ]
    in
        div
            [ class "editor__controls" ]
            [ div
                [ class "flex--row" ]
                [ mainActionButton
                , div [ class "flex-spacer" ] []
                , currentViewButton
                ]
            ]


viewTextArea : Model -> Html Msg
viewTextArea model =
    div
        [ style
            [ ( "display"
              , (if model.currentView == Code then
                    "block"
                 else
                    "none"
                )
              )
            ]
        ]
        [ textarea
            [ value model.source
            , onInput SourceChanged
            , class "editor__code"
            ]
            []
        , div
            [ class "editor__status" ]
            [ span [] [ text "Status: " ]
            , span [ class ("status--" ++ model.status) ] [ text model.status ]
            ]
        ]


viewOutput : Model -> Html Msg
viewOutput model =
    iframe
        [ src ("/live/" ++ model.liveCodeId ++ "/compiled")
        , style
            [ ( "width", "100%" )
            , ( "height", "600px" )
            , ( "display"
              , (if model.currentView == Code then
                    "none"
                 else
                    "block"
                )
              )
            ]
        ]
        []



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen (Debug.log "websocketHost" model.websocketHost) Incoming
        ]
