module Main exposing (main)

import Browser
import Browser.Navigation
import Html exposing (Html, a, button, div, h1, img, text)
import Html.Attributes exposing (href, src)
import Html.Events exposing (onClick)
import Url


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = onUrlChange
        , onUrlRequest = onUrlRequest
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type alias OAuthParameters =
    { clientId : String
    , clientSecret : String
    }


type alias Model =
    { oauth : OAuthParameters, number : Int }


type alias Flags =
    { x : Float, y : Float }


type Msg
    = Increment
    | Decrement


init : Flags -> Url.Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { oauth = { clientId = "foo", clientSecret = "bar" }, number = 0 }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increment ->
            ( { model | number = model.number + 1 }, Cmd.none )

        Decrement ->
            ( { model | number = model.number - 1 }, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "KOM.one"
    , body =
        [ h1 [] [ text "KOM.one" ]
        , div [] [ a [ href "https://www.strava.com/oauth/authorize?client_id=" ] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ] ]
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model.number) ]
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
