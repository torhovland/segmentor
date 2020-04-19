module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Cmd.Extra exposing (withCmd, withCmds, withNoCmd)
import Html exposing (Html, a, button, div, h1, img, text)
import Html.Attributes exposing (href, src)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Json.Decode.Extra as Decode
import Json.Encode as Encode exposing (Value)
import Json.Encode.Extra as Encode
import PortFunnel.LocalStorage as LocalStorage
    exposing
        ( Message
        , Response(..)
        )
import PortFunnels exposing (FunnelDict, Handler(..))
import Time
import Url


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , subscriptions = PortFunnels.subscriptions Process
        , update = update
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type alias ActivityId =
    Int


type alias Activity =
    { id : ActivityId
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
    , storageKey : LocalStorage.Key
    , value : String
    , label : String
    , returnLabel : String
    , keysString : String
    , useSimulator : Bool
    , url : Url.Url
    , wasLoaded : Bool
    , funnelState : PortFunnels.State
    , error : Maybe String
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
    | Process Value
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

        model =
            { key = key
            , storageKey = "key"
            , value = ""
            , label = ""
            , returnLabel = ""
            , keysString = ""
            , useSimulator = True
            , url = url
            , wasLoaded = False
            , funnelState = PortFunnels.initialState "example"
            , error = Nothing
            , status = Idle
            , stravaAuth = stravaAuth
            , activities = []
            , activityPageNumber = currentPageNumber
            , number = 0
            }
    in
    case stravaAuth of
        Just (Ok auth) ->
            { model | status = DownloadingActivities } |> withCmd (getNextActivityPage auth.accessToken currentPageNumber)

        _ ->
            model |> withNoCmd


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


getCmdPort : String -> Model -> (Value -> Cmd Msg)
getCmdPort moduleName model =
    PortFunnels.getCmdPort Process moduleName model.useSimulator


send : Message -> Model -> Cmd Msg
send message model =
    LocalStorage.send (getCmdPort LocalStorage.moduleName model)
        message
        model.funnelState.storage


decodeString : Value -> String
decodeString value =
    case Decode.decodeValue Decode.string value of
        Ok res ->
            res

        Err err ->
            Decode.errorToString err


storageKey : Activity -> String
storageKey activity =
    "a" ++ String.fromInt activity.id


saveActivity : Model -> Activity -> Cmd Msg
saveActivity model activity =
    send
        (LocalStorage.put (storageKey activity)
            (Just <|
                Encode.object
                    [ ( "id", Encode.int activity.id )
                    , ( "name", Encode.string activity.name )
                    , ( "time", Encode.int (Time.posixToMillis activity.time) )
                    ]
            )
        )
        model


saveActivities : Model -> List Activity -> Cmd Msg
saveActivities model activities =
    List.map (saveActivity model) activities |> Cmd.batch


doIsLoaded : Model -> Model
doIsLoaded model =
    if not model.wasLoaded && LocalStorage.isLoaded model.funnelState.storage then
        { model
            | useSimulator = False
            , wasLoaded = True
        }

    else
        model


storageHandler : LocalStorage.Response -> PortFunnels.State -> Model -> ( Model, Cmd Msg )
storageHandler response state mdl =
    let
        model =
            doIsLoaded
                { mdl | funnelState = state }
    in
    case response of
        LocalStorage.GetResponse { label, key, value } ->
            let
                string =
                    case value of
                        Nothing ->
                            "<null>"

                        Just v ->
                            decodeString v
            in
            { model
                | storageKey = key
                , value = string
                , returnLabel =
                    case label of
                        Nothing ->
                            "Nothing"

                        Just lab ->
                            "Just \"" ++ lab ++ "\""
            }
                |> withNoCmd

        LocalStorage.ListKeysResponse { label, keys } ->
            let
                keysString =
                    stringListToString keys
            in
            { model
                | keysString = keysString
                , returnLabel =
                    case label of
                        Nothing ->
                            "Nothing"

                        Just lab ->
                            "Just \"" ++ lab ++ "\""
            }
                |> withNoCmd

        _ ->
            model
                |> withNoCmd


stringListToString : List String -> String
stringListToString list =
    let
        quoted =
            List.map (\s -> "\"" ++ s ++ "\"") list

        commas =
            List.intersperse ", " quoted
                |> String.concat
    in
    "[" ++ commas ++ "]"


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
            { model | url = url }
                |> withNoCmd

        GotActivities result ->
            case result of
                Ok activities ->
                    case model.stravaAuth of
                        Just (Ok auth) ->
                            if List.length activities > 0 then
                                { model | activities = model.activities ++ activities, activityPageNumber = model.activityPageNumber + 1 }
                                    |> withCmds [ getNextActivityPage auth.accessToken model.activityPageNumber, saveActivities model activities ]

                            else
                                { model | activityPageNumber = 0, status = Idle }
                                    |> withNoCmd

                        _ ->
                            { model | activityPageNumber = 0, status = Idle }
                                |> withNoCmd

                Err err ->
                    { model | activityPageNumber = 0, status = Idle, error = Just (errorToString err) }
                        |> withNoCmd

        Process value ->
            case
                PortFunnels.processValue funnelDict
                    value
                    model.funnelState
                    model
            of
                Err error ->
                    { model | error = Just error } |> withNoCmd

                Ok res ->
                    res

        Increment ->
            ( { model | number = model.number + 1 }, Cmd.none )

        Decrement ->
            ( { model | number = model.number - 1 }, Cmd.none )


funnelDict : FunnelDict Model Msg
funnelDict =
    PortFunnels.makeFunnelDict [ LocalStorageHandler storageHandler ] getCmdPort


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


loginBanner : Model -> Html msg
loginBanner model =
    div [] [ a [ href ("https://www.strava.com/oauth/authorize?client_id=38457&response_type=code&redirect_uri=" ++ rootUrl model.url ++ "/exchange_token&approval_prompt=force&scope=read,activity:read&state=123") ] [ img [ src "images/btn_strava_connectwith_orange.svg" ] [] ] ]


userBanner : StravaAuth -> Html msg
userBanner stravaAuth =
    div []
        [ div [] [ text stravaAuth.accessToken ]
        , div [] [ text (stravaAuth.firstName ++ " " ++ stravaAuth.lastName) ]
        , div [] [ img [ src stravaAuth.image ] [] ]
        ]


authBanner : Model -> Html msg
authBanner model =
    case model.stravaAuth of
        Just (Ok data) ->
            userBanner data

        Just (Err err) ->
            div [] [ text ("Error decoding Strava auth response: " ++ Decode.errorToString err) ]

        Nothing ->
            loginBanner model


statusBanner : Model -> Html msg
statusBanner model =
    case model.status of
        Idle ->
            div [] []

        DownloadingActivities ->
            div [] [ text ("Downloading activity page " ++ String.fromInt (model.activityPageNumber + 1)) ]


errorBanner : Maybe String -> Html msg
errorBanner error =
    case error of
        Just err ->
            div [] [ text err ]

        Nothing ->
            div [] []


activityList : List Activity -> List (Html msg)
activityList list =
    List.map (\a -> div [] [ text a.name ]) list


view : Model -> Browser.Document Msg
view model =
    { title = "KOM.one"
    , body =
        [ h1 [] [ text "KOM.one" ]
        , authBanner model
        , errorBanner model.error
        , statusBanner model
        , div [] (activityList model.activities)
        , button [ onClick Decrement ] [ text "-" ]
        , div [] [ text (String.fromInt model.number) ]
        , button [ onClick Increment ] [ text "+" ]
        , div [] [ img [ src "images/api_logo_pwrdBy_strava_horiz_light.svg" ] [] ]
        ]
    }
