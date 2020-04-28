module Activity exposing (Activity, ActivityId(..), decoder, encode, toString)

import Json.Decode as Decode
import Json.Decode.Extra as Decode
import Json.Encode as Encode exposing (Value)
import Json.Encode.Extra as Encode
import Time


type ActivityId
    = ActivityId Int


toString : ActivityId -> String
toString (ActivityId id) =
    String.fromInt id


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


decoder : Decode.Decoder Activity
decoder =
    Decode.map8 Activity
        (Decode.field "id" Decode.int |> Decode.map ActivityId)
        (Decode.field "start_date" Decode.datetime)
        (Decode.field "name" Decode.string)
        (Decode.field "type" Decode.string)
        (Decode.field "trainer" Decode.bool)
        (Decode.field "commute" Decode.bool)
        (Decode.field "private" Decode.bool)
        (Decode.maybe (Decode.field "gear_id" Decode.string))


encodeActivityId : ActivityId -> Value
encodeActivityId (ActivityId activityId) =
    Encode.int activityId


encode : Activity -> Value
encode activity =
    Encode.object
        [ ( "id", encodeActivityId activity.id )
        , ( "name", Encode.string activity.name )
        , ( "time", Encode.int (Time.posixToMillis activity.time) )
        ]
