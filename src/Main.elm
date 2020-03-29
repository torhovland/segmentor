module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text, h1, img)
import Html.Attributes exposing (src)
import Html.Events exposing (onClick)

main =
  Browser.sandbox { init = 0, update = update, view = view }

type Msg = Increment | Decrement

update msg model =
  case msg of
    Increment ->
      model + 1

    Decrement ->
      model - 1

view model =
  div []
    [ h1 [] [ text "KOM.one" ] 
    , div [] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ]
    , button [ onClick Decrement ] [ text "-" ]
    , div [] [ text (String.fromInt model) ]
    , button [ onClick Increment ] [ text "+" ]
    , div [] [ img [ src "images/api_logo_pwrdBy_strava_horiz_light.svg" ] [] ]
    ]
