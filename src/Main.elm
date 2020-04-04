module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, button, div, h1, img, text)
import Html.Attributes exposing (href, src)
import Html.Events exposing (onClick)
import Url


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , stravaData : Maybe String
    , number : Int
    }


type alias Flags =
    { x : Float, y : Float, stravaData : Maybe String }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | Increment
    | Decrement


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( Model key url flags.stravaData 0, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        Increment ->
            ( { model | number = model.number + 1 }, Cmd.none )

        Decrement ->
            ( { model | number = model.number - 1 }, Cmd.none )


rootUrl : Url.Url -> String
rootUrl url =
    let
        protocol =
            case url.protocol of
                Url.Https ->
                    "https"

                Url.Http ->
                    "http"

        schemeHost =
            protocol ++ "://" ++ url.host
    in
    case url.port_ of
        Just portNumber ->
            schemeHost ++ ":" ++ String.fromInt portNumber

        Nothing ->
            schemeHost


view : Model -> Browser.Document Msg
view model =
    { title = "KOM.one"
    , body =
        [ h1 [] [ text "KOM.one" ]
        , h1 [] [ text (Maybe.withDefault "no data" model.stravaData) ]
        , div [] [ a [ href ("https://www.strava.com/oauth/authorize?client_id=38457&response_type=code&redirect_uri=" ++ rootUrl model.url ++ "/exchange_token&approval_prompt=force&scope=read,activity:read&state=123") ] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ] ]
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model.number) ]
        , button [ onClick Increment ] [ text "+" ]
        , div [] [ img [ src "images/api_logo_pwrdBy_strava_horiz_light.svg" ] [] ]
        ]
    }


subscriptions model =
    Sub.none
