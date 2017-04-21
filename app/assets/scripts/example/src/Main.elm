module Main exposing (..)

{-| Elm-Canvas: Your first program

# Models
@docs Model Msg

# Methods
@docs main init update view
-}

import Html exposing (Html)
import Color
import Canvas
import Canvas.Point


{-| Basic program with no subscriptions
-}
main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


{-| We don't have to track any state in this program
-}
type alias Model =
    {}


{-| We don't have to produce any updates or messages, so we'll just fill this with a single action, NoOp
-}
type Msg
    = NoOp


{-| Get the initial state of this elm app. Since our model is an empty record, just keep this blank
-}
init : ( Model, Cmd Msg )
init =
    ( {}
    , Cmd.none
    )


{-| Update our model. Our NoOp update just returns the previous model (an empty record).
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Cmd.none
            )


{-| Every time there is no data (in the case of this app, never):
  1. Create a new 800x600 canvas
  2. Draw the text "This text is coming from elm-canvas!" at (5, 5)
  3. Draw a big triangle using canvas draw operations
  4. Convert our canvas into something Elm's Html.program/view understands.
-}
view : Model -> Html Msg
view model =
    let
        {- Here we're calling the draw ops on demand.
           There may be some cases where you want to pre-calculate or create methods for groups of draw ops (ie shapes/groups that are drawn often).
           In this case, since we only do an initial render, it's not a problem to inline this with the view.
        -}
        drawOps : List Canvas.DrawOp
        drawOps =
            [ Canvas.FillStyle Color.black
            , Canvas.FillText "This text is coming from elm-canvas!" (Canvas.Point.fromInts (5, 5))
            , Canvas.FillStyle Color.blue
            , Canvas.BeginPath
            , Canvas.MoveTo (Canvas.Point.fromInts (400, 100))
            , Canvas.LineTo (Canvas.Point.fromInts (700, 500))
            , Canvas.LineTo (Canvas.Point.fromInts (100, 500))
            , Canvas.ClosePath
            , Canvas.Fill
            ]
    in
        Canvas.Size 800 600
            |> Canvas.initialize
            |> Canvas.batch drawOps
            |> Canvas.toHtml
