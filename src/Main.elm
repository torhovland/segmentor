module Main exposing (main)

import Browser
import Html exposing (Html, a, button, div, h1, img, text)
import Html.Attributes exposing (href, src)
import Html.Events exposing (onClick)


main : Program () Int Msg
main =
    Browser.application
        { init = init
        , onUrlChange = onUrlChange
        , onUrlRequest = onUrlRequest
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type Msg
    = Increment
    | Decrement


init flags url key =
    ( 0, Cmd.none )


update : Msg -> Int -> ( Int, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( model + 1, Cmd.none )

        Decrement ->
            ( model - 1, Cmd.none )


view : Int -> Browser.Document Msg
view model =
    { title = "foo"
    , body =
        [ h1 [] [ text "KOM.one" ]
        , div [] [ a [ href "https://www.strava.com/oauth/authorize?client_id=" ] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ] ]
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model) ]
        , button [ onClick Increment ] [ text "+" ]
        , div [] [ img [ src "images/api_logo_pwrdBy_strava_horiz_light.svg" ] [] ]
        ]
    }


subscriptions model =
    Sub.none


onUrlChange url =
    Increment


onUrlRequest request =
    Increment
