module Main exposing (..)

import Html exposing (Html, text)
import Canvas exposing (Canvas, Size)
import AnimationFrame


-- Entry


main =
    Html.program
        { init = ( initialModel, Cmd.none )
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- Model


type alias Model =
    { canvas : Canvas
    }


initialModel : Model
initialModel =
    let
        canvas : Canvas
        canvas =
            Canvas.initialize (Size 800 600)
    in
        { canvas = canvas
        }



-- Update


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Cmd.none
            )



-- View


view : Model -> Html Msg
view model =
    text "view code"



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
