module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (a, button, div, h1, img, text)
import Html.Attributes exposing (href, src)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Json.Decode.Extra as Decode
import Time
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


type alias Activity =
    { id : Int
    , time : Time.Posix
    , name : String
    , activityType : String
    , trainer : Bool
    , commute : Bool
    , private : Bool
    , gearId : Maybe String
    }


type alias AccessToken =
    String


type alias PageNumber =
    Int


type Status
    = Idle
    | DownloadingActivities


type alias StravaAuth =
    { accessToken : AccessToken
    , firstName : String
    , lastName : String
    , image : String
    }


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , error : String
    , status : Status
    , stravaAuth : Maybe (Result Decode.Error StravaAuth)
    , activities : List Activity
    , activityPageNumber : PageNumber
    , number : Int
    }


type alias Flags =
    { x : Float
    , y : Float
    , stravaAuth : Maybe String
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotActivities (Result Http.Error (List Activity))
    | Increment
    | Decrement


activityDecoder : Decode.Decoder Activity
activityDecoder =
    Decode.map8 Activity
        (Decode.field "id" Decode.int)
        (Decode.field "start_date" Decode.datetime)
        (Decode.field "name" Decode.string)
        (Decode.field "type" Decode.string)
        (Decode.field "trainer" Decode.bool)
        (Decode.field "commute" Decode.bool)
        (Decode.field "private" Decode.bool)
        (Decode.maybe (Decode.field "gear_id" Decode.string))


decodeStravaAuth : String -> Result Decode.Error StravaAuth
decodeStravaAuth json =
    Result.map4 StravaAuth
        (Decode.decodeString (Decode.field "access_token" Decode.string) json)
        (Decode.decodeString (Decode.at [ "athlete", "firstname" ] Decode.string) json)
        (Decode.decodeString (Decode.at [ "athlete", "lastname" ] Decode.string) json)
        (Decode.decodeString (Decode.at [ "athlete", "profile" ] Decode.string) json)


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        stravaAuth =
            Maybe.map decodeStravaAuth flags.stravaAuth

        currentPageNumber =
            0
    in
    case stravaAuth of
        Just (Ok auth) ->
            ( Model key url "" DownloadingActivities stravaAuth [] currentPageNumber 0, getNextActivityPage auth.accessToken currentPageNumber )

        _ ->
            ( Model key url "" Idle stravaAuth [] currentPageNumber 0, Cmd.none )


getNextActivityPage : AccessToken -> PageNumber -> Cmd Msg
getNextActivityPage accessToken currentPageNumber =
    Http.request
        { method = "GET"
        , url = "https://www.strava.com/api/v3/athlete/activities?per_page=100&page=" ++ String.fromInt (currentPageNumber + 1)
        , headers = [ Http.header "Authorization" ("Bearer " ++ accessToken) ]
        , body = Http.emptyBody
        , expect = Http.expectJson GotActivities (Decode.list activityDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


errorToString : Http.Error -> String
errorToString err =
    case err of
        Http.Timeout ->
            "Timeout exceeded"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status from api: " ++ String.fromInt status

        Http.BadBody text ->
            "Unexpected response from api: " ++ text

        Http.BadUrl url ->
            "Malformed url: " ++ url


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
            ( { model | url = url }, Cmd.none )

        GotActivities result ->
            case result of
                Ok activities ->
                    case model.stravaAuth of
                        Just (Ok auth) ->
                            if List.length activities > 0 then
                                ( { model | activities = model.activities ++ activities, activityPageNumber = model.activityPageNumber + 1 }, getNextActivityPage auth.accessToken model.activityPageNumber )

                            else
                                ( { model | activityPageNumber = 0, status = Idle }, Cmd.none )

                        _ ->
                            ( { model | activityPageNumber = 0, status = Idle }, Cmd.none )

                Err err ->
                    ( { model | activityPageNumber = 0, status = Idle, error = errorToString err }, Cmd.none )

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


loginBanner : Model -> Html.Html msg
loginBanner model =
    div [] [ a [ href ("https://www.strava.com/oauth/authorize?client_id=38457&response_type=code&redirect_uri=" ++ rootUrl model.url ++ "/exchange_token&approval_prompt=force&scope=read,activity:read&state=123") ] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ] ]


userBanner : StravaAuth -> Html.Html msg
userBanner stravaAuth =
    div []
        [ div [] [ text stravaAuth.accessToken ]
        , div [] [ text (stravaAuth.firstName ++ " " ++ stravaAuth.lastName) ]
        , div [] [ img [ src stravaAuth.image ] [] ]
        ]


authBanner : Model -> Html.Html msg
authBanner model =
    case model.stravaAuth of
        Just (Ok data) ->
            userBanner data

        Just (Err err) ->
            div [] [ text ("Error decoding Strava auth response: " ++ Decode.errorToString err) ]

        Nothing ->
            loginBanner model


statusBanner : Model -> Html.Html msg
statusBanner model =
    case model.status of
        Idle ->
            div [] []

        DownloadingActivities ->
            div [] [ text ("Downloading activity page " ++ String.fromInt (model.activityPageNumber + 1)) ]


activityList : List Activity -> List (Html.Html msg)
activityList list =
    List.map (\a -> div [] [ text a.name ]) list


view : Model -> Browser.Document Msg
view model =
    { title = "KOM.one"
    , body =
        [ h1 [] [ text "KOM.one" ]
        , authBanner model
        , div [] [ text model.error ]
        , statusBanner model
        , div [] (activityList model.activities)
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model.number) ]
        , button [ onClick Increment ] [ text "+" ]
        , div [] [ img [ src "images/api_logo_pwrdBy_strava_horiz_light.svg" ] [] ]
        ]
    }


subscriptions model =
    Sub.none
